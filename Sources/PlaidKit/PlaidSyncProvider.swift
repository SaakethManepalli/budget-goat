import Foundation
import BudgetCore
import SecureStorage

public final class PlaidSyncProvider: BankSyncProvider, @unchecked Sendable {

    private let proxy: BackendProxyClient
    private let tokenStore: SecureTokenStoring

    public init(proxy: BackendProxyClient, tokenStore: SecureTokenStoring) {
        self.proxy = proxy
        self.tokenStore = tokenStore
    }

    public func createLinkToken() async throws -> String {
        try await proxy.createLinkToken()
    }

    public func exchangePublicToken(_ publicToken: String, institutionId: String) async throws -> LinkedItem {
        let item = try await proxy.exchangePublicToken(publicToken, institutionId: institutionId)
        try await tokenStore.store(itemId: item.itemId, forKey: item.itemId)
        return item
    }

    public func syncTransactions(itemId: String, cursor: String?, count: Int) async throws -> SyncDelta {
        try await proxy.syncTransactions(itemId: itemId, cursor: cursor, count: count)
    }

    public func removeItem(itemId: String) async throws {
        try await proxy.removeItem(itemId: itemId)
        try await tokenStore.deleteItemId(forKey: itemId)
    }
}
