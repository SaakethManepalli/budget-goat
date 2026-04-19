import XCTest
@testable import TransactionEngine
import BudgetCore

final class PIIStripperTests: XCTestCase {
    func test_stripsAccountNumberPatterns() {
        let stripper = PIIStripper()
        let snapshot = makeSnapshot(rawName: "WHOLEFDS MKT #10 00007482 CA")
        let scrubbed = stripper.scrub(snapshot)
        XCTAssertFalse(scrubbed.rawName.contains("00007482"))
        XCTAssertFalse(scrubbed.rawName.contains("#10"))
        XCTAssertTrue(scrubbed.rawName.contains("WHOLEFDS"))
    }

    func test_roundsAmountToNearestWhole() {
        let stripper = PIIStripper()
        let snapshot = makeSnapshot(rawName: "STORE", amount: 47.23)
        let scrubbed = stripper.scrub(snapshot)
        XCTAssertEqual(scrubbed.amountRounded, 47)
    }

    func test_usesOpaqueIdNotLocalId() {
        let stripper = PIIStripper()
        let snapshot = makeSnapshot(rawName: "STORE")
        let scrubbed = stripper.scrub(snapshot)
        XCTAssertNotEqual(scrubbed.opaqueId, snapshot.id)
        XCTAssertEqual(scrubbed.localId, snapshot.id)
    }

    private func makeSnapshot(rawName: String, amount: Decimal = 10) -> TransactionSnapshot {
        TransactionSnapshot(
            id: UUID(), plaidTransactionId: "tx_1", accountId: UUID(),
            accountDisplayName: "Checking", amount: amount, currencyCode: .usd,
            amountInBaseCurrency: nil, authorizedDate: Date(), postedDate: nil,
            rawName: rawName, merchantName: nil, canonicalName: nil, logoURL: nil,
            category: nil, subcategory: nil, categorySource: .plaid,
            categoryConfidence: nil, isPending: false, isRecurring: false,
            recurringPatternId: nil, userNote: nil, isFlagged: false, isHidden: false
        )
    }
}
