import Foundation
import BudgetCore

public struct PIIStripper: Sendable {

    public init() {}

    public func scrub(_ snapshot: TransactionSnapshot) -> ScrubbedTransaction {
        let rounded = roundAmount(snapshot.amount)
        return ScrubbedTransaction(
            opaqueId: UUID(),
            localId: snapshot.id,
            rawName: stripName(snapshot.rawName),
            plaidMerchant: snapshot.merchantName,
            amountRounded: rounded,
            currencyCode: snapshot.currencyCode.rawValue,
            dateISO: ISO8601DateFormatter.yyyyMMdd.string(from: snapshot.authorizedDate),
            priorCountSameMerchant: 0,
            accountTypeHint: nil
        )
    }

    private func stripName(_ name: String) -> String {
        var cleaned = name
        let accountNumberPatterns = [
            "\\b\\d{8,20}\\b",
            "#\\s*\\d+",
            "\\*{4,}\\d+",
            "\\b[A-Z0-9]{16,}\\b"
        ]
        for pattern in accountNumberPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let range = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        return cleaned
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func roundAmount(_ amount: Decimal) -> Decimal {
        var input = amount
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return output
    }
}

public struct ScrubbedTransaction: Sendable, Encodable {
    public let opaqueId: UUID
    public let localId: UUID
    public let rawName: String
    public let plaidMerchant: String?
    public let amountRounded: Decimal
    public let currencyCode: String
    public let dateISO: String
    public let priorCountSameMerchant: Int
    public let accountTypeHint: String?

    enum CodingKeys: String, CodingKey {
        case opaqueId = "tx_id"
        case rawName = "raw_name"
        case plaidMerchant = "plaid_merchant"
        case amountRounded = "amount"
        case currencyCode = "currency"
        case dateISO = "date"
        case priorCountSameMerchant = "prior_count_same_merchant"
        case accountTypeHint = "account_type"
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(opaqueId, forKey: .opaqueId)
        try c.encode(rawName, forKey: .rawName)
        try c.encodeIfPresent(plaidMerchant, forKey: .plaidMerchant)
        try c.encode(amountRounded.doubleValue, forKey: .amountRounded)
        try c.encode(currencyCode, forKey: .currencyCode)
        try c.encode(dateISO, forKey: .dateISO)
        try c.encode(priorCountSameMerchant, forKey: .priorCountSameMerchant)
        try c.encodeIfPresent(accountTypeHint, forKey: .accountTypeHint)
    }
}

extension ISO8601DateFormatter {
    static let yyyyMMdd: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}

private extension Decimal {
    var doubleValue: Double { (self as NSDecimalNumber).doubleValue }
}
