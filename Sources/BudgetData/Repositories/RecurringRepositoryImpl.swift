import Foundation
import SwiftData
import BudgetCore

public final class RecurringRepositoryImpl: RecurringRepository, @unchecked Sendable {

    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchAll() async throws -> [RecurringPatternSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<RecurringPatternModel>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\.lastSeenAt, order: .reverse)]
            )
            return try ctx.fetch(descriptor).map { $0.snapshot() }
        }
    }

    public func upsert(_ snapshot: RecurringPatternSnapshot) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let id = snapshot.id
            let descriptor = FetchDescriptor<RecurringPatternModel>(
                predicate: #Predicate { $0.id == id }
            )
            if let existing = try ctx.fetch(descriptor).first {
                existing.canonicalMerchantName = snapshot.canonicalMerchantName
                existing.frequency = snapshot.frequency
                existing.meanAmount = snapshot.meanAmount
                existing.stdDevAmount = snapshot.stdDevAmount
                existing.currencyCode = snapshot.currencyCode
                existing.firstSeenAt = snapshot.firstSeenAt
                existing.lastSeenAt = snapshot.lastSeenAt
                existing.nextExpectedDate = snapshot.nextExpectedDate
                existing.sampleCount = snapshot.sampleCount
                existing.isActive = snapshot.isActive
                existing.isUserConfirmed = snapshot.isUserConfirmed
            } else {
                let model = RecurringPatternModel(
                    id: snapshot.id,
                    canonicalMerchantName: snapshot.canonicalMerchantName,
                    frequency: snapshot.frequency,
                    meanAmount: snapshot.meanAmount,
                    stdDevAmount: snapshot.stdDevAmount,
                    currencyCode: snapshot.currencyCode,
                    firstSeenAt: snapshot.firstSeenAt,
                    lastSeenAt: snapshot.lastSeenAt,
                    nextExpectedDate: snapshot.nextExpectedDate,
                    sampleCount: snapshot.sampleCount,
                    isActive: snapshot.isActive,
                    isUserConfirmed: snapshot.isUserConfirmed
                )
                ctx.insert(model)
            }
            try ctx.save()
        }
    }

    public func confirm(id: UUID) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<RecurringPatternModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let model = try ctx.fetch(descriptor).first else { return }
            model.isUserConfirmed = true
            try ctx.save()
        }
    }

    public func deleteAll() async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            try ctx.delete(model: RecurringPatternModel.self)
            try ctx.save()
        }
    }

    public func deactivate(id: UUID) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<RecurringPatternModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let model = try ctx.fetch(descriptor).first else { return }
            model.isActive = false
            try ctx.save()
        }
    }
}
