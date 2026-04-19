import XCTest
@testable import TransactionEngine
import BudgetCore

final class CategorizationPipelineTests: XCTestCase {
    func test_acceptsHighConfidencePlaidCategory() async throws {
        let llm = MockLLMClient(results: [])
        let pipeline = CategorizationPipeline(
            llmClient: llm,
            cache: MerchantCategoryCache(defaults: ephemeralDefaults()),
            plaidConfidenceFloor: 0.85
        )
        let snapshot = makeSnapshot(category: .groceries, confidence: 0.95)
        let results = try await pipeline.categorize([snapshot])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.source, .plaid)
        XCTAssertEqual(results.first?.category, .groceries)
        XCTAssertFalse(llm.wasCalled, "Should not call LLM when Plaid confidence is above floor")
    }

    func test_fallsBackToLLMWhenPlaidConfidenceLow() async throws {
        let expectedCategorization = LLMCategorization(
            txId: UUID(),
            canonicalName: "Whole Foods Market",
            category: TransactionCategory.groceries.rawValue,
            subcategory: "supermarket",
            confidence: 0.92,
            isRecurring: false,
            reasoning: "chain match"
        )
        let llm = MockLLMClient(mapResults: { scrubs in
            scrubs.map { s in
                LLMCategorization(
                    txId: s.opaqueId,
                    canonicalName: expectedCategorization.canonicalName,
                    category: expectedCategorization.category,
                    subcategory: expectedCategorization.subcategory,
                    confidence: expectedCategorization.confidence,
                    isRecurring: expectedCategorization.isRecurring,
                    reasoning: expectedCategorization.reasoning
                )
            }
        })
        let pipeline = CategorizationPipeline(
            llmClient: llm,
            cache: MerchantCategoryCache(defaults: ephemeralDefaults()),
            plaidConfidenceFloor: 0.85
        )
        let snapshot = makeSnapshot(category: .other, confidence: 0.30)
        let results = try await pipeline.categorize([snapshot])
        XCTAssertTrue(llm.wasCalled)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.source, .llm)
        XCTAssertEqual(results.first?.category, .groceries)
        XCTAssertEqual(results.first?.canonicalName, "Whole Foods Market")
    }

    private func ephemeralDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "engine.test.\(UUID().uuidString)")!
        suite.removePersistentDomain(forName: "engine.test")
        return suite
    }

    private func makeSnapshot(category: TransactionCategory?, confidence: Float?) -> TransactionSnapshot {
        TransactionSnapshot(
            id: UUID(), plaidTransactionId: "tx_1", accountId: UUID(),
            accountDisplayName: "Checking", amount: 47.23, currencyCode: .usd,
            amountInBaseCurrency: nil, authorizedDate: Date(), postedDate: nil,
            rawName: "WHOLEFDS MKT #10", merchantName: "Whole Foods Market",
            canonicalName: nil, logoURL: nil,
            category: category, subcategory: nil, categorySource: .plaid,
            categoryConfidence: confidence, isPending: false, isRecurring: false,
            recurringPatternId: nil, userNote: nil, isFlagged: false, isHidden: false
        )
    }
}

final class MockLLMClient: LLMCategorizationClient, @unchecked Sendable {
    private let results: [LLMCategorization]
    private let mapResults: (([ScrubbedTransaction]) -> [LLMCategorization])?
    private(set) var wasCalled = false

    init(results: [LLMCategorization]) {
        self.results = results
        self.mapResults = nil
    }

    init(mapResults: @escaping ([ScrubbedTransaction]) -> [LLMCategorization]) {
        self.results = []
        self.mapResults = mapResults
    }

    func categorize(_ batch: [ScrubbedTransaction]) async throws -> [LLMCategorization] {
        wasCalled = true
        if let mapResults { return mapResults(batch) }
        return results
    }
}
