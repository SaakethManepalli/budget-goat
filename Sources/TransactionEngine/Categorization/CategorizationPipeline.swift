import Foundation
import BudgetCore

public actor CategorizationPipeline: CategorizationEngine {

    private let llmClient: LLMCategorizationClient
    private let cache: MerchantCategoryCache
    private let scrubber: PIIStripper
    private let plaidConfidenceFloor: Float
    private let llmConfidenceFloor: Float
    private let batchSize: Int

    public init(
        llmClient: LLMCategorizationClient,
        cache: MerchantCategoryCache = MerchantCategoryCache(),
        scrubber: PIIStripper = PIIStripper(),
        plaidConfidenceFloor: Float = 0.85,
        llmConfidenceFloor: Float = 0.60,
        batchSize: Int = 50
    ) {
        self.llmClient = llmClient
        self.cache = cache
        self.scrubber = scrubber
        self.plaidConfidenceFloor = plaidConfidenceFloor
        self.llmConfidenceFloor = llmConfidenceFloor
        self.batchSize = batchSize
    }

    public func categorize(_ transactions: [TransactionSnapshot]) async throws -> [CategorizationResult] {
        var results: [CategorizationResult] = []
        var pendingLLM: [TransactionSnapshot] = []

        for tx in transactions {
            let merchantKey = tx.canonicalName ?? tx.merchantName ?? tx.rawName
            if let cached = await cache.lookup(merchant: merchantKey) {
                results.append(CategorizationResult(
                    transactionId: tx.id,
                    category: cached.category,
                    subcategory: cached.subcategory,
                    canonicalName: cached.canonicalName,
                    confidence: cached.confidence,
                    isRecurring: tx.isRecurring,
                    source: .cache
                ))
                continue
            }
            if let plaidCategory = tx.category,
               let confidence = tx.categoryConfidence,
               confidence >= plaidConfidenceFloor {
                let canonical = tx.merchantName ?? tx.rawName
                let classification = CachedClassification(
                    canonicalName: canonical,
                    category: plaidCategory,
                    subcategory: tx.subcategory,
                    confidence: confidence
                )
                await cache.store(merchant: merchantKey, classification: classification)
                results.append(CategorizationResult(
                    transactionId: tx.id,
                    category: plaidCategory,
                    subcategory: tx.subcategory,
                    canonicalName: canonical,
                    confidence: confidence,
                    isRecurring: tx.isRecurring,
                    source: .plaid
                ))
                continue
            }
            pendingLLM.append(tx)
        }

        for chunk in pendingLLM.chunked(into: batchSize) {
            let scrubbed = chunk.map { scrubber.scrub($0) }
            var indexByOpaque: [UUID: TransactionSnapshot] = [:]
            for (scrub, original) in zip(scrubbed, chunk) {
                indexByOpaque[scrub.opaqueId] = original
            }

            let classifications: [LLMCategorization]
            do {
                classifications = try await llmClient.categorize(scrubbed)
            } catch {
                for tx in chunk {
                    results.append(Self.fallback(for: tx))
                }
                continue
            }

            for classification in classifications {
                guard let original = indexByOpaque[classification.txId] else { continue }
                guard let category = TransactionCategory(rawValue: classification.category) else {
                    results.append(Self.fallback(for: original))
                    continue
                }
                if classification.confidence < llmConfidenceFloor {
                    results.append(CategorizationResult(
                        transactionId: original.id,
                        category: category,
                        subcategory: classification.subcategory,
                        canonicalName: classification.canonicalName,
                        confidence: classification.confidence,
                        isRecurring: classification.isRecurring,
                        source: .llm
                    ))
                    continue
                }
                let cached = CachedClassification(
                    canonicalName: classification.canonicalName,
                    category: category,
                    subcategory: classification.subcategory,
                    confidence: classification.confidence
                )
                await cache.store(merchant: classification.canonicalName, classification: cached)
                results.append(CategorizationResult(
                    transactionId: original.id,
                    category: category,
                    subcategory: classification.subcategory,
                    canonicalName: classification.canonicalName,
                    confidence: classification.confidence,
                    isRecurring: classification.isRecurring,
                    source: .llm
                ))
            }
        }

        return results
    }

    private static func fallback(for tx: TransactionSnapshot) -> CategorizationResult {
        CategorizationResult(
            transactionId: tx.id,
            category: tx.category ?? .other,
            subcategory: tx.subcategory,
            canonicalName: tx.merchantName ?? tx.rawName,
            confidence: tx.categoryConfidence ?? 0.30,
            isRecurring: tx.isRecurring,
            source: .plaid
        )
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
