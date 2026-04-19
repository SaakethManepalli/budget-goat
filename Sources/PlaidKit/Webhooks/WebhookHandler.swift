import Foundation
import BudgetCore

public enum PlaidWebhookEvent: Sendable, Equatable {
    case syncUpdatesAvailable(itemId: String)
    case itemLoginRequired(itemId: String)
    case pendingExpiration(itemId: String, expiresAt: Date)
    case userPermissionRevoked(itemId: String)
    case transactionsRemoved(itemId: String, transactionIds: [String])
    case unknown(code: String)
}

public struct PlaidWebhookPayload: Sendable, Decodable {
    public let webhookType: String
    public let webhookCode: String
    public let itemId: String
    public let newTransactions: Int?
    public let removedTransactions: [String]?
    public let consentExpirationTime: String?

    public func toEvent() -> PlaidWebhookEvent {
        switch webhookCode.uppercased() {
        case "SYNC_UPDATES_AVAILABLE":
            return .syncUpdatesAvailable(itemId: itemId)
        case "ITEM_LOGIN_REQUIRED":
            return .itemLoginRequired(itemId: itemId)
        case "PENDING_EXPIRATION":
            let formatter = ISO8601DateFormatter()
            let date = consentExpirationTime.flatMap(formatter.date(from:)) ?? Date()
            return .pendingExpiration(itemId: itemId, expiresAt: date)
        case "USER_PERMISSION_REVOKED":
            return .userPermissionRevoked(itemId: itemId)
        case "TRANSACTIONS_REMOVED":
            return .transactionsRemoved(itemId: itemId, transactionIds: removedTransactions ?? [])
        default:
            return .unknown(code: webhookCode)
        }
    }
}

public final class WebhookEventBus: @unchecked Sendable {

    private let stream: AsyncStream<PlaidWebhookEvent>
    private let continuation: AsyncStream<PlaidWebhookEvent>.Continuation

    public init() {
        var cont: AsyncStream<PlaidWebhookEvent>.Continuation!
        self.stream = AsyncStream { continuation in cont = continuation }
        self.continuation = cont
    }

    public var events: AsyncStream<PlaidWebhookEvent> { stream }

    public func publish(_ event: PlaidWebhookEvent) {
        continuation.yield(event)
    }
}
