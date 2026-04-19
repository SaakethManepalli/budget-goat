import Foundation
import SwiftData
import BudgetCore

public final class AccountRepositoryImpl: AccountRepository, @unchecked Sendable {

    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func fetchAll() async throws -> [AccountSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.displayName)]
            )
            return try ctx.fetch(descriptor).map { $0.snapshot() }
        }
    }

    public func fetch(id: UUID) async throws -> AccountSnapshot? {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.id == id }
            )
            return try ctx.fetch(descriptor).first?.snapshot()
        }
    }

    public func fetchByItemId(_ itemId: String) async throws -> [AccountSnapshot] {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.plaidItemId == itemId }
            )
            return try ctx.fetch(descriptor).map { $0.snapshot() }
        }
    }

    public func register(item: LinkedItem) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            ctx.autosaveEnabled = false
            let maxSort = try ctx.fetch(FetchDescriptor<BankAccountModel>()).map(\.sortOrder).max() ?? 0
            for (index, account) in item.accounts.enumerated() {
                let plaidAccountId = account.plaidAccountId
                let dupDescriptor = FetchDescriptor<BankAccountModel>(
                    predicate: #Predicate { $0.plaidAccountId == plaidAccountId }
                )
                if try ctx.fetch(dupDescriptor).first != nil { continue }
                let model = BankAccountModel(
                    plaidAccountId: account.plaidAccountId,
                    plaidItemId: item.itemId,
                    institutionId: item.institutionId,
                    institutionName: item.institutionName,
                    mask: account.mask,
                    displayName: account.name,
                    accountType: account.type,
                    accountSubtype: account.subtype,
                    currencyCode: account.currencyCode,
                    currentBalance: .zero,
                    availableBalance: nil,
                    creditLimit: nil,
                    lastSyncedAt: .init(timeIntervalSince1970: 0),
                    isActive: true,
                    sortOrder: maxSort + 1 + index
                )
                ctx.insert(model)
            }
            try ctx.save()
        }
    }

    public func updateBalance(id: UUID, current: Decimal, available: Decimal?) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let account = try ctx.fetch(descriptor).first else { return }
            account.currentBalance = current
            account.availableBalance = available
            account.lastSyncedAt = Date()
            try ctx.save()
        }
    }

    public func remove(itemId: String) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.plaidItemId == itemId }
            )
            for account in try ctx.fetch(descriptor) {
                ctx.delete(account)
            }
            try ctx.save()
        }
    }

    public func deleteAll() async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            try ctx.delete(model: BankAccountModel.self)
            try ctx.save()
        }
    }

    public func updateDisplayName(id: UUID, displayName: String) async throws {
        try await DatabaseActor.shared.run { [container] in
            let ctx = ModelContext(container)
            let descriptor = FetchDescriptor<BankAccountModel>(
                predicate: #Predicate { $0.id == id }
            )
            guard let account = try ctx.fetch(descriptor).first else { return }
            account.displayName = displayName
            try ctx.save()
        }
    }
}
