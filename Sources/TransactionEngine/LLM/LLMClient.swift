import Foundation
import BudgetCore

public struct LLMCategorization: Sendable, Decodable, Hashable {
    public let txId: UUID
    public let canonicalName: String
    public let category: String
    public let subcategory: String?
    public let confidence: Float
    public let isRecurring: Bool
    public let reasoning: String?

    enum CodingKeys: String, CodingKey {
        case txId = "tx_id"
        case canonicalName = "canonical_name"
        case category
        case subcategory
        case confidence
        case isRecurring = "is_recurring"
        case reasoning
    }
}

public protocol LLMCategorizationClient: Sendable {
    func categorize(_ batch: [ScrubbedTransaction]) async throws -> [LLMCategorization]
}

public struct RemoteLLMClient: LLMCategorizationClient, Sendable {

    public struct Configuration: Sendable {
        public let endpoint: URL
        public let apiKeyProvider: @Sendable () async throws -> String
        public let modelIdentifier: String

        public init(endpoint: URL, apiKeyProvider: @Sendable @escaping () async throws -> String, modelIdentifier: String = "claude-sonnet-4-6") {
            self.endpoint = endpoint
            self.apiKeyProvider = apiKeyProvider
            self.modelIdentifier = modelIdentifier
        }
    }

    private let configuration: Configuration
    private let session: URLSession

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func categorize(_ batch: [ScrubbedTransaction]) async throws -> [LLMCategorization] {
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = try await configuration.apiKeyProvider()
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let payload = RequestPayload(model: configuration.modelIdentifier, transactions: batch, taxonomy: TransactionCategory.allCases.map(\.rawValue))
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BudgetError.categorizationFailed("Categorization endpoint returned non-2xx")
        }

        let decoded = try JSONDecoder().decode(ResponsePayload.self, from: data)
        return decoded.results
    }

    private struct RequestPayload: Encodable {
        let model: String
        let transactions: [ScrubbedTransaction]
        let taxonomy: [String]
        let systemPrompt: String = """
        You are a deterministic financial transaction categorizer for a personal \
        budgeting application. Return only valid JSON matching the schema. Use ONLY \
        categories from the supplied taxonomy. `canonical_name` must be a human-readable \
        merchant name, stripped of store numbers, location codes, and processor prefixes \
        (e.g., "SQ *", "TST*", "PAYPAL *"). Report genuine uncertainty in `confidence`. \
        `is_recurring` signals pattern-based billing likelihood.
        """
    }

    private struct ResponsePayload: Decodable {
        let results: [LLMCategorization]
    }
}
