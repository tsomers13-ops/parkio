// RatingCredentialStore.swift — secure storage for the anonymous rating credential.
//
// The credential is an opaque, server-signed bearer token that stands for one
// anonymous rater. It is not an account, contains no personal data, and is
// worthless to forge without the server secret — which lives only in
// Cloudflare and is never shipped in this app.
//
// It goes in the Keychain, not UserDefaults: UserDefaults is a plist in the
// app container, readable from a backup and trivially inspected on a
// jailbroken device. The Keychain is also the only store here that survives
// the app being deleted and reinstalled, which is what keeps a guest's rating
// theirs across a reinstall.
//
// The protocol exists so tests never touch a real device Keychain — production
// uses `KeychainRatingCredentialStore`, tests use `InMemoryRatingCredentialStore`.

import Foundation
import Security

// MARK: - Protocol

protocol RatingCredentialStore: Sendable {
    /// The stored credential, or nil when this device has never been issued one.
    func load() throws -> String?

    /// Store a credential, replacing any existing one.
    func save(_ credential: String) throws

    /// Remove the credential. Used when the server rejects it as invalid.
    func delete() throws
}

// MARK: - Errors

enum RatingCredentialStoreError: Error, Equatable {
    /// A Keychain call failed. Carries the OSStatus for diagnosis — never the
    /// credential value itself.
    case keychain(OSStatus)
    /// Stored bytes were not valid UTF-8, i.e. the item is corrupt.
    case corruptItem
}

// MARK: - Keychain

/// Keychain-backed store used by the app.
///
/// `kSecClassGenericPassword` with a fixed service/account pair, so there is
/// exactly one credential per app installation.
///
/// `kSecAttrAccessibleAfterFirstUnlock` rather than `WhenUnlocked`: rating
/// submission can be driven from a background task, and this device is the
/// only place the credential needs to work. It is deliberately NOT synced to
/// iCloud Keychain — syncing would silently merge two devices into one rating
/// identity, which is a product decision, not a storage default.
struct KeychainRatingCredentialStore: RatingCredentialStore {

    private let service: String
    private let account: String

    init(
        service: String = "app.parkio.ratings",
        account: String = "anonymous-rating-credential"
    ) {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Explicitly device-only.
            kSecAttrSynchronizable as String: false,
        ]
    }

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw RatingCredentialStoreError.keychain(status) }
        guard let data = item as? Data else { throw RatingCredentialStoreError.corruptItem }
        guard let credential = String(data: data, encoding: .utf8), !credential.isEmpty else {
            throw RatingCredentialStoreError.corruptItem
        }
        return credential
    }

    func save(_ credential: String) throws {
        let data = Data(credential.utf8)

        // Update in place when an item already exists; add otherwise. Doing it
        // in this order avoids a delete/add window where the device has no
        // identity at all.
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw RatingCredentialStoreError.keychain(updateStatus)
        }

        var insert = baseQuery
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw RatingCredentialStoreError.keychain(addStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        // Deleting something that was never there is the desired end state.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw RatingCredentialStoreError.keychain(status)
        }
    }
}

// MARK: - Test double

/// In-memory store for tests. Never used by the app.
final class InMemoryRatingCredentialStore: RatingCredentialStore, @unchecked Sendable {

    private let lock = NSLock()
    private var credential: String?

    /// Set to make any operation fail, for exercising error paths.
    var failure: RatingCredentialStoreError?

    init(credential: String? = nil) {
        self.credential = credential
    }

    func load() throws -> String? {
        if let failure { throw failure }
        lock.lock(); defer { lock.unlock() }
        return credential
    }

    func save(_ credential: String) throws {
        if let failure { throw failure }
        lock.lock(); defer { lock.unlock() }
        self.credential = credential
    }

    func delete() throws {
        if let failure { throw failure }
        lock.lock(); defer { lock.unlock() }
        credential = nil
    }
}
