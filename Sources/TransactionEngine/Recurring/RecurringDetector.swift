import Foundation
import BudgetCore

public struct RecurringDetector: Sendable {

    public let coefficientOfVariationCeiling: Double
    public let minimumSampleCount: Int

    public init(coefficientOfVariationCeiling: Double = 0.25, minimumSampleCount: Int = 3) {
        self.coefficientOfVariationCeiling = coefficientOfVariationCeiling
        self.minimumSampleCount = minimumSampleCount
    }

    public func detect(_ transactions: [TransactionSnapshot]) -> [RecurringPatternSnapshot] {
        let grouped = Dictionary(grouping: transactions) { tx in
            (tx.canonicalName ?? tx.merchantName ?? tx.rawName).lowercased()
        }

        return grouped.compactMap { key, txs in
            buildPattern(key: key, transactions: txs)
        }
    }

    private func buildPattern(key: String, transactions: [TransactionSnapshot]) -> RecurringPatternSnapshot? {
        guard transactions.count >= minimumSampleCount else { return nil }

        let sorted = transactions.sorted { $0.authorizedDate < $1.authorizedDate }
        let dates = sorted.map(\.authorizedDate)
        var gaps: [Double] = []
        for index in 1..<dates.count {
            gaps.append(dates[index].timeIntervalSince(dates[index - 1]) / 86_400)
        }
        guard !gaps.isEmpty else { return nil }

        let meanGap = gaps.reduce(0, +) / Double(gaps.count)
        let variance = gaps.map { pow($0 - meanGap, 2) }.reduce(0, +) / Double(gaps.count)
        let stdDevGap = sqrt(variance)
        guard meanGap > 0 else { return nil }
        let coefficientOfVariation = stdDevGap / meanGap

        guard coefficientOfVariation < coefficientOfVariationCeiling else { return nil }

        let frequency: RecurringFrequency
        switch meanGap {
        case 6...8:    frequency = .weekly
        case 13...15:  frequency = .biweekly
        case 27...33:  frequency = .monthly
        case 86...96:  frequency = .quarterly
        case 355...375: frequency = .annual
        default:       return nil
        }

        let amounts = sorted.map { (($0.amount as NSDecimalNumber).doubleValue) }
        let meanAmountD = amounts.reduce(0, +) / Double(amounts.count)
        let amountVar = amounts.map { pow($0 - meanAmountD, 2) }.reduce(0, +) / Double(amounts.count)
        let stdDevAmount = sqrt(amountVar)

        let firstSeen = sorted.first!.authorizedDate
        let lastSeen = sorted.last!.authorizedDate
        let nextExpected = Calendar(identifier: .iso8601).date(
            byAdding: .day, value: Int(frequency.approximateDays), to: lastSeen
        )

        let canonicalName = sorted.compactMap { $0.canonicalName ?? $0.merchantName }.first ?? key
        let currency = sorted.first!.currencyCode

        return RecurringPatternSnapshot(
            id: UUID(),
            canonicalMerchantName: canonicalName,
            frequency: frequency,
            meanAmount: Decimal(meanAmountD),
            stdDevAmount: Decimal(stdDevAmount),
            currencyCode: currency,
            firstSeenAt: firstSeen,
            lastSeenAt: lastSeen,
            nextExpectedDate: nextExpected,
            sampleCount: sorted.count,
            isActive: true,
            isUserConfirmed: false
        )
    }
}
