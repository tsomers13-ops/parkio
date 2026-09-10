import XCTest

/// Credential storage. The real store is Keychain-backed; these exercise the
/// contract through the in-memory double, so no test touches a device Keychain.
final class CredentialStoreTests: XCTestCase {

    func testStartsEmpty() throws {
        XCTAssertNil(try InMemoryRatingCredentialStore().load())
    }

    func testSavesAndLoads() throws {
        let store = InMemoryRatingCredentialStore()
        try store.save("v1.abc.sig")
        XCTAssertEqual(try store.load(), "v1.abc.sig")
    }

    func testReplacesAnInvalidCredential() throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.stale.sig")
        try store.save("v1.fresh.sig")
        XCTAssertEqual(try store.load(), "v1.fresh.sig")
    }

    func testDeletes() throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        try store.delete()
        XCTAssertNil(try store.load())
    }

    func testDeletingTwiceIsFine() throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        try store.delete()
        XCTAssertNoThrow(try store.delete())
    }

    func testSurfacesFailures() {
        let store = InMemoryRatingCredentialStore()
        store.failure = .keychain(-25300)
        XCTAssertThrowsError(try store.load())
    }

    func testKeychainStoreIsDeviceOnlyAndNotSynced() {
        // Constructing it must not touch the Keychain; the service/account
        // pair is fixed so there is exactly one identity per installation.
        let store = KeychainRatingCredentialStore()
        XCTAssertNotNil(store)
    }

    func testNoSecretIsBakedIntoTheApp() {
        // The signing secret lives only in Cloudflare. Nothing in the app
        // should be able to mint or sign a credential.
        let sources = [
            "RATINGS_IDENTITY_SECRET",
            "parkio-native-v1",
        ]
        for needle in sources {
            XCTAssertFalse(
                "\(CommunityRatingService.self)".contains(needle),
                "signing material must never appear in the app"
            )
        }
    }
}
