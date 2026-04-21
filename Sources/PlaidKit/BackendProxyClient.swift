import Foundation
import CryptoKit
import BudgetCore
import SecureStorage

private extension Data {
    var sha256HexString: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public protocol BackendProxyClient: Sendable {
    func createLinkToken() async throws -> String
    func createUpdateLinkToken(forItemId: String) async throws -> String
    func exchangePublicToken(_ publicToken: String, institutionId: String) async throws -> LinkedItem
    func syncTransactions(itemId: String, cursor: String?, count: Int) async throws -> SyncDelta
    func removeItem(itemId: String) async throws
}

public struct BackendProxyConfiguration: Sendable {
    public let baseURL: URL
    public let sessionTokenProvider: @Sendable () async throws -> String
    public let sessionTokenInvalidator: @Sendable () async -> Void
    public let deviceSigner: DeviceSigning?
    public let pinnedCertificateSHA256: [String]

    public init(
        baseURL: URL,
        sessionTokenProvider: @Sendable @escaping () async throws -> String,
        sessionTokenInvalidator: @Sendable @escaping () async -> Void = {},
        deviceSigner: DeviceSigning? = nil,
        pinnedCertificateSHA256: [String] = []
    ) {
        self.baseURL = baseURL
        self.sessionTokenProvider = sessionTokenProvider
        self.sessionTokenInvalidator = sessionTokenInvalidator
        self.deviceSigner = deviceSigner
        self.pinnedCertificateSHA256 = pinnedCertificateSHA256
    }
}

public final class URLSessionBackendProxyClient: NSObject, BackendProxyClient, URLSessionDelegate, @unchecked Sendable {

    private let configuration: BackendProxyConfiguration
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(configuration: BackendProxyConfiguration) {
        self.configuration = configuration
        self.encoder = {
            let e = JSONEncoder()
            e.keyEncodingStrategy = .convertToSnakeCase
            e.dateEncodingStrategy = .iso8601
            return e
        }()
        self.decoder = {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            return d
        }()
    }

    // MARK: - Certificate Pinning

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard configuration.pinnedCertificateSHA256.isEmpty == false,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let certData = SecCertificateCopyData(leaf) as Data
        let sha256 = certData.sha256HexString

        if configuration.pinnedCertificateSHA256.contains(sha256) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    public func createLinkToken() async throws -> String {
        let response: LinkTokenResponse = try await perform(
            path: "/api/link/token/create",
            method: "POST",
            body: EmptyBody()
        )
        return response.linkToken
    }

    public func createUpdateLinkToken(forItemId itemId: String) async throws -> String {
        struct UpdateRequest: Encodable { let itemId: String }
        let response: LinkTokenResponse = try await perform(
            path: "/api/link/token/update",
            method: "POST",
            body: UpdateRequest(itemId: itemId)
        )
        return response.linkToken
    }

    public func exchangePublicToken(_ publicToken: String, institutionId: String) async throws -> LinkedItem {
        let body = ExchangeRequest(publicToken: publicToken, institutionId: institutionId)
        let response: ExchangeResponse = try await perform(
            path: "/api/item/public_token/exchange",
            method: "POST",
            body: body
        )
        return LinkedItem(
            itemId: response.itemId,
            institutionId: response.institutionId,
            institutionName: response.institutionName,
            accounts: response.accounts.map { $0.toDomain() }
        )
    }

    public func syncTransactions(itemId: String, cursor: String?, count: Int) async throws -> SyncDelta {
        let body = SyncRequest(itemId: itemId, cursor: cursor, count: count)
        let response: SyncResponse = try await perform(
            path: "/api/transactions/sync",
            method: "POST",
            body: body
        )
        return response.toDomain()
    }

    public func removeItem(itemId: String) async throws {
        struct RemoveRequest: Encodable { let itemId: String }
        struct EmptyResponse: Decodable {}
        let _: EmptyResponse = try await perform(
            path: "/api/item/remove",
            method: "POST",
            body: RemoveRequest(itemId: itemId)
        )
    }

    private struct EmptyBody: Encodable {}

    private func perform<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        var attempt = 0
        let maxAttempts = 3
        var lastError: Error = BudgetError.networkUnavailable

        while attempt < maxAttempts {
            do {
                return try await performOnce(path: path, method: method, body: body)
            } catch BudgetError.unauthorized where attempt == 0 {
                // Cached session token was rejected — clear it and re-auth.
                // Only retry auth once; never loop.
                await configuration.sessionTokenInvalidator()
                attempt += 1
                continue
            } catch let err as BudgetError {
                // Retry transient failures (networkUnavailable, 5xx bubbled as syncFailed)
                // with exponential backoff. Don't retry user-cancelled, reauth, unauthorized.
                if shouldRetry(err) && attempt < maxAttempts - 1 {
                    let delayNs = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delayNs)
                    lastError = err
                    attempt += 1
                    continue
                }
                throw err
            }
        }
        throw lastError
    }

    private func shouldRetry(_ error: BudgetError) -> Bool {
        switch error {
        case .networkUnavailable, .syncFailed:
            return true
        default:
            return false
        }
    }

    private func performOnce<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let sessionToken = try await configuration.sessionTokenProvider()
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        let payload = try encoder.encode(body)
        request.httpBody = payload

        if let signer = configuration.deviceSigner {
            let timestamp = String(Int(Date().timeIntervalSince1970))
            let signable = "\(timestamp).\(method).\(path).".data(using: .utf8)! + payload
            let signature = try signer.sign(payload: signable)
            request.setValue(timestamp, forHTTPHeaderField: "X-Device-Timestamp")
            request.setValue(signature.base64EncodedString(), forHTTPHeaderField: "X-Device-Signature")
        }

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            throw BudgetError.networkUnavailable
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw BudgetError.invalidResponse("non-HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            return try decoder.decode(Response.self, from: data)
        case 401:
            throw BudgetError.unauthorized
        case 409:
            throw BudgetError.itemRequiresReauth(itemId: (try? extractItemId(data)) ?? "")
        default:
            let message = String(data: data, encoding: .utf8) ?? "\(http.statusCode)"
            throw BudgetError.syncFailed(message)
        }
    }

    private func extractItemId(_ data: Data) throws -> String? {
        struct ErrorBody: Decodable { let itemId: String? }
        return try? decoder.decode(ErrorBody.self, from: data).itemId
    }
}
