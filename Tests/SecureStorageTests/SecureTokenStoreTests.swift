import XCTest
@testable import SecureStorage
import BudgetCore

final class SecureTokenStoreTests: XCTestCase {
    private var store: SecureTokenStore!

    override func setUp() async throws {
        try XCTSkipIf(isUnsignedCLIBundle, "Keychain tests require a signed test bundle (simulator/device)")
        store = SecureTokenStore(configuration: .test)
        try? await store.deleteItemId(forKey: "test-item-A")
        try? await store.deleteItemId(forKey: "test-item-B")
    }

    override func tearDown() async throws {
        guard let store else { return }
        try? await store.deleteItemId(forKey: "test-item-A")
        try? await store.deleteItemId(forKey: "test-item-B")
    }

    private var isUnsignedCLIBundle: Bool {
        Bundle.main.bundleIdentifier?.contains("xctest") == true
    }

    func test_storeAndRetrieve() async throws {
        try await store.store(itemId: "secret_value", forKey: "test-item-A")
        let retrieved = try await store.retrieveItemId(forKey: "test-item-A")
        XCTAssertEqual(retrieved, "secret_value")
    }

    func test_storeTwice_updatesValue() async throws {
        try await store.store(itemId: "first", forKey: "test-item-A")
        try await store.store(itemId: "second", forKey: "test-item-A")
        let retrieved = try await store.retrieveItemId(forKey: "test-item-A")
        XCTAssertEqual(retrieved, "second")
    }

    func test_allItemKeys_includesStored() async throws {
        try await store.store(itemId: "v1", forKey: "test-item-A")
        try await store.store(itemId: "v2", forKey: "test-item-B")
        let keys = try await store.allItemKeys()
        XCTAssertTrue(keys.contains("test-item-A"))
        XCTAssertTrue(keys.contains("test-item-B"))
    }

    func test_delete_removesItem() async throws {
        try await store.store(itemId: "v", forKey: "test-item-A")
        try await store.deleteItemId(forKey: "test-item-A")
        do {
            _ = try await store.retrieveItemId(forKey: "test-item-A")
            XCTFail("Expected keychain read to fail after delete")
        } catch BudgetError.keychainFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
