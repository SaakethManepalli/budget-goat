import Foundation
import BudgetCore
import SecureStorage

public protocol BackendProxyClient: Sendable {
    func createLinkToken() async throws -> String
    func exchangePublicToken(_ publicToken: String, institutionId: String) async throws -> LinkedItem
    func syncTransactions(itemId: String, cursor: String?, count: Int) async throws -> SyncDelta
    func removeItem(itemId: String) async throws
}

public struct BackendProxyConfiguration: Sendable {
    public let baseURL: URL
    public let sessionTokenProvider: @Sendable () async throws -> String
    public let deviceSigner: DeviceSigning?
    public let pinnedCertificateSHA256: [String]

    public init(
        baseURL: URL,
        sessionTokenProvider: @Sendable @escaping () async throws -> String,
        deviceSigner: DeviceSigning? = nil,
        pinnedCertificateSHA256: [String] = []
    ) {
        self.baseURL = baseURL
        self.sessionTokenProvider = sessionTokenProvider
        self.deviceSigner = deviceSigner
        self.pinnedCertificateSHA256 = pinnedCertificateSHA256
    }
}

public final class URLSessionBackendProxyClient: BackendProxyClient, @unchecked Sendable {

    private let configuration: BackendProxyConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(configuration: BackendProxyConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
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

    public func createLinkToken() async throws -> String {
        let response: LinkTokenResponse = try await perform(
            path: "/api/link/token/create",
            method: "POST",
            body: EmptyBody()
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
