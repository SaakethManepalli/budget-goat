import Foundation
import SwiftData
import BudgetCore

public final class BudgetRepositoryImpl: BudgetRepository, @unchecked Sendable {

    private let container: ModelContainer
    private let transactionRepo: TransactionRepository

    public init(container: ModelContainer, transactionRepo: TransactionRepository) {
        self.container = container
        self.transactionRepo = transactionRepo
    }

    public func fetchAll(forMonth month: Date) async throws -> [BudgetSnapshot] {
        let normalizedMonth = MonthBoundary.start(of: month)
        let zeroSnapshots: [BudgetSnapshot] = try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BudgetModel>(
                predicate: #Predicate { $0.monthStart == normalizedMonth },
                sortBy: [SortDescriptor(\.categoryRaw)]
            )
            return try ctx.fetch(descriptor).map { model in
                BudgetSnapshot(
                    id: model.id,
                    category: model.category,
                    monthlyLimit: model.monthlyLimit,
                    currencyCode: model.currencyCode,
                    monthStart: model.monthStart,
                    notifyAtPercent: model.notifyAtPercent,
                    rollover: model.rollover,
                    spent: .zero
                )
            }
        }

        var snapshots: [BudgetSnapshot] = []
        snapshots.reserveCapacity(zeroSnapshots.count)
        for base in zeroSnapshots {
            let spent = try await transactionRepo.totalSpent(
                category: base.category,
                monthStart: normalizedMonth,
                in: base.currencyCode
            )
            snapshots.append(BudgetSnapshot(
                id: base.id,
                category: base.category,
                monthlyLimit: base.monthlyLimit,
                currencyCode: base.currencyCode,
                monthStart: base.monthStart,
                notifyAtPercent: base.notifyAtPercent,
                rollover: base.rollover,
                spent: spent
            ))
        }
        return snapshots
    }

    public func upsert(
        category: TransactionCategory,
        limit: Decimal,
        currency: CurrencyCode,
        monthStart: Date,
        notifyAtPercent: Int,
        rollover: Bool
    ) async throws {
        let normalized = MonthBoundary.start(of: monthStart)
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let categoryRaw = category.rawValue
            let descriptor = FetchDescriptor<BudgetModel>(
                predicate: #Predicate { $0.categoryRaw == categoryRaw && $0.monthStart == normalized }
            )
            if let existing = try ctx.fetch(descriptor).first {
                existing.monthlyLimit = limit
                existing.currencyCode = currency
                existing.notifyAtPercent = notifyAtPercent
                existing.rollover = rollover
            } else {
                let budget = BudgetModel(
                    category: category,
                    monthlyLimit: limit,
                    currencyCode: currency,
                    monthStart: normalized,
                    notifyAtPercent: notifyAtPercent,
                    rollover: rollover
                )
                ctx.insert(budget)
            }
            try ctx.save()
        }
    }

    public func fetchAllForExport() async throws -> [BudgetSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BudgetModel>(
                sortBy: [SortDescriptor(\.monthStart, order: .reverse)]
            )
            return try ctx.fetch(descriptor).map { model in
                BudgetSnapshot(
                    id: model.id,
                    category: model.category,
                    monthlyLimit: model.monthlyLimit,
                    currencyCode: model.currencyCode,
                    monthStart: model.monthStart,
                    notifyAtPercent: model.notifyAtPercent,
                    rollover: model.rollover,
                    spent: .zero
                )
            }
        }
    }

    public func deleteAll() async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            try ctx.delete(model: BudgetModel.self)
            try ctx.save()
        }
    }

    public func delete(id: UUID) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BudgetModel>(
                predicate: #Predicate { $0.id == id }
            )
            for budget in try ctx.fetch(descriptor) {
                ctx.delete(budget)
            }
            try ctx.save()
        }
    }
}
