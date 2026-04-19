import Foundation
import SwiftData
import BudgetCore

public final class TransactionRepositoryImpl: TransactionRepository, @unchecked Sendable {

    private let container: ModelContainer
    private let baseCurrency: CurrencyCode

    public init(container: ModelContainer, baseCurrency: CurrencyCode = .usd) {
        self.container = container
        self.baseCurrency = baseCurrency
    }

    @DatabaseActor
    private func makeContext() -> ModelContext {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return ctx
    }

    public func fetchPage(query: TransactionQuery, offset: Int, limit: Int) async throws -> [TransactionSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: Self.buildPredicate(query),
                sortBy: Self.sortDescriptors(for: query.sortOrder)
            )
            let rawResults = try ctx.fetch(descriptor)
            let filtered = Self.applyInMemoryFilters(rawResults, query: query)
            let sliced = filtered.dropFirst(offset).prefix(limit)
            return sliced.map { $0.snapshot() }
        }
    }

    public func fetch(id: UUID) async throws -> TransactionSnapshot? {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate { $0.id == id }
            )
            return try ctx.fetch(descriptor).first?.snapshot()
        }
    }

    public func apply(delta: SyncDelta, forItemId itemId: String) async throws {
        try await DatabaseActor.shared.run { [container, baseCurrency] in
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false

            let accountDescriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.plaidItemId == itemId }
            )
            let accounts = try ctx.fetch(accountDescriptor)
            let accountIndex = Dictionary(uniqueKeysWithValues: accounts.map { ($0.plaidAccountId, $0) })

            let addedIds = delta.added.map(\.plaidTransactionId)
            let existingAdded = try ctx.fetch(
                FetchDescriptor<TransactionModel>(
                    predicate: #Predicate { addedIds.contains($0.plaidTransactionId) }
                )
            )
            let existingIds = Set(existingAdded.map(\.plaidTransactionId))

            for dto in delta.added where !existingIds.contains(dto.plaidTransactionId) {
                guard let account = accountIndex[dto.plaidAccountId] else { continue }
                let tx = TransactionModel(
                    plaidTransactionId: dto.plaidTransactionId,
                    amount: dto.amount,
                    currencyCode: dto.currencyCode,
                    amountInBaseCurrency: Self.convert(
                        amount: dto.amount,
                        from: dto.currencyCode,
                        to: baseCurrency,
                        context: ctx
                    ),
                    authorizedDate: dto.authorizedDate,
                    postedDate: dto.postedDate,
                    rawName: dto.rawName,
                    merchantName: dto.merchantName,
                    canonicalName: nil,
                    logoURL: dto.logoURL,
                    category: dto.category,
                    subcategory: dto.subcategory,
                    categorySource: .plaid,
                    categoryConfidence: dto.categoryConfidence,
                    isPending: dto.isPending,
                    isRecurring: false,
                    recurringPatternId: nil,
                    merchantLatitude: dto.merchantLatitude,
                    merchantLongitude: dto.merchantLongitude,
                    account: account
                )
                ctx.insert(tx)
            }

            for dto in delta.modified {
                let predicateId = dto.plaidTransactionId
                let descriptor = FetchDescriptor<TransactionModel>(
                    predicate: #Predicate { $0.plaidTransactionId == predicateId }
                )
                if let existing = try ctx.fetch(descriptor).first {
                    existing.apply(ingested: dto) { amount, currency in
                        Self.convert(amount: amount, from: currency, to: baseCurrency, context: ctx)
                    }
                }
            }

            for removedId in delta.removed {
                let descriptor = FetchDescriptor<TransactionModel>(
                    predicate: #Predicate { $0.plaidTransactionId == removedId }
                )
                if let tx = try ctx.fetch(descriptor).first {
                    ctx.delete(tx)
                }
            }

            try ctx.save()
        }
    }

    public func updateUserCategory(id: UUID, category: TransactionCategory) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let tx = try ctx.fetch(descriptor).first else { return }
            tx.userCategoryOverrideRaw = category.rawValue
            tx.categorySourceRaw = CategorySource.manual.rawValue
            try ctx.save()
        }
    }

    public func updateNote(id: UUID, note: String?) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let tx = try ctx.fetch(descriptor).first else { return }
            tx.userNote = note
            try ctx.save()
        }
    }

    public func setFlagged(id: UUID, flagged: Bool) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let tx = try ctx.fetch(descriptor).first else { return }
            tx.isFlagged = flagged
            try ctx.save()
        }
    }

    public func setHidden(id: UUID, hidden: Bool) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let tx = try ctx.fetch(descriptor).first else { return }
            tx.isHidden = hidden
            try ctx.save()
        }
    }

    public func fetchAllForExport() async throws -> [TransactionSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<TransactionModel>(
                sortBy: [SortDescriptor(\.authorizedDate, order: .reverse)]
            )
            return try ctx.fetch(descriptor).map { $0.snapshot() }
        }
    }

    public func deleteAll() async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            try ctx.delete(model: TransactionModel.self)
            try ctx.save()
        }
    }

    public func totalSpent(category: TransactionCategory, monthStart: Date, in currency: CurrencyCode) async throws -> Decimal {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let monthEnd = MonthBoundary.end(of: monthStart)
            let descriptor = FetchDescriptor<TransactionModel>(
                predicate: #Predicate<TransactionModel> { tx in
                    tx.authorizedDate >= monthStart && tx.authorizedDate < monthEnd
                }
            )
            let rangeFetched = try ctx.fetch(descriptor)
            let categoryRaw = category.rawValue
            let matching = rangeFetched.filter { tx in
                if tx.isHidden { return false }
                return tx.categoryRaw == categoryRaw || tx.userCategoryOverrideRaw == categoryRaw
            }
            let total = matching.reduce(Decimal.zero) { partial, tx in
                let amount = tx.amountInBaseCurrency ?? tx.amount
                return partial + max(amount, .zero)
            }
            return total
        }
    }

    private static func buildPredicate(_ query: TransactionQuery) -> Predicate<TransactionModel>? {
        if let accountId = query.accountId, let rangeStart = query.dateRange?.lowerBound, let rangeEnd = query.dateRange?.upperBound {
            return #Predicate { tx in
                tx.account?.id == accountId &&
                tx.authorizedDate >= rangeStart &&
                tx.authorizedDate <= rangeEnd
            }
        }
        if let accountId = query.accountId {
            return #Predicate { tx in tx.account?.id == accountId }
        }
        if let rangeStart = query.dateRange?.lowerBound, let rangeEnd = query.dateRange?.upperBound {
            return #Predicate { tx in
                tx.authorizedDate >= rangeStart && tx.authorizedDate <= rangeEnd
            }
        }
        return nil
    }

    private static func applyInMemoryFilters(_ transactions: [TransactionModel], query: TransactionQuery) -> [TransactionModel] {
        transactions.filter { tx in
            if !query.includeHidden && tx.isHidden { return false }
            if query.isRecurringOnly && !tx.isRecurring { return false }
            if let category = query.category {
                let matchesPlaid = tx.categoryRaw == category.rawValue
                let matchesOverride = tx.userCategoryOverrideRaw == category.rawValue
                if !(matchesPlaid || matchesOverride) { return false }
            }
            if let text = query.searchText?.lowercased(), !text.isEmpty {
                let haystacks = [tx.rawName, tx.merchantName ?? "", tx.canonicalName ?? ""].map { $0.lowercased() }
                if !haystacks.contains(where: { $0.contains(text) }) { return false }
            }
            return true
        }
    }

    private static func sortDescriptors(for order: TransactionSortOrder) -> [SortDescriptor<TransactionModel>] {
        switch order {
        case .dateDescending:   [SortDescriptor(\.authorizedDate, order: .reverse)]
        case .dateAscending:    [SortDescriptor(\.authorizedDate, order: .forward)]
        case .amountDescending: [SortDescriptor(\.amount, order: .reverse)]
        case .amountAscending:  [SortDescriptor(\.amount, order: .forward)]
        }
    }

    private static func convert(amount: Decimal, from: CurrencyCode, to: CurrencyCode, context: ModelContext) -> Decimal? {
        if from == to { return amount }
        let fromRaw = from.rawValue
        let toRaw = to.rawValue
        let descriptor = FetchDescriptor<ExchangeRateModel>(
            predicate: #Predicate { rate in
                rate.baseCurrencyCodeRaw == fromRaw && rate.targetCurrencyCodeRaw == toRaw
            }
        )
        guard let rate = try? context.fetch(descriptor).first else { return nil }
        let rateDecimal = Decimal(rate.rate)
        return amount * rateDecimal
    }
}

extension DatabaseActor {
    func run<T: Sendable>(_ operation: @Sendable () throws -> T) async rethrows -> T {
        try operation()
    }
}
