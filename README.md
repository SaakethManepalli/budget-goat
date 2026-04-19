# Budget Goat

Privacy-first iOS budgeting app built with SwiftUI + SwiftData, following the Technical Design Document (`TDD`) in this repository's planning notes.

## Architecture

Clean Architecture + MVVM-C across six SPM modules:

| Module | Responsibility |
|---|---|
| `BudgetCore` | Domain entities, value types, use case protocols, errors |
| `SecureStorage` | Keychain store with biometric gate, Secure Enclave ECDSA signing, cursor store |
| `BudgetData` | SwiftData `@Model`s, `DatabaseActor` background writes, repository implementations, schema migrations |
| `PlaidKit` | Backend proxy client for Plaid, Link coordinator, transaction sync via `/transactions/sync`, webhook event bus |
| `TransactionEngine` | LLM categorization pipeline with merchant cache, PII scrubber, statistical recurring detection |
| `BudgetUI` | SwiftUI views, view models, coordinators, theme |

The **App** target (`App/BudgetGoat`) wires dependencies and hosts the SwiftUI scene.

## Security-critical invariants

1. **Access tokens never touch the device.** Only the opaque `item_id` is stored locally in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` + `.biometryCurrentSet`.
2. **No CloudKit sync.** `ModelConfiguration(cloudKitDatabase: .none)` is explicit in `ModelContainerFactory`.
3. **Store encrypted at rest** via `com.apple.developer.default-data-protection = NSFileProtectionComplete` (entitlement) and the Application Support directory location.
4. **LLM payloads PII-scrubbed** — account numbers stripped from `raw_name` via regex; amounts rounded; no user identifier.
5. **Biometric app-unlock gate** on foreground via `LockScreenView`.

## Build

Requires Xcode 15.3+, iOS 17.4+ target.

```bash
# One-time
brew install xcodegen

# Generate BudgetGoat.xcodeproj
xcodegen generate

# Open
open BudgetGoat.xcodeproj
```

The SPM modules build/test without the Xcode project:

```bash
swift build
swift test
```

## Configuration

The app expects a backend proxy URL. Set via scheme env or `Info.plist` override:

```
BUDGETGOAT_BACKEND_URL=https://api.your-backend.example
```

The backend is **out of scope** for this repository — it is responsible for:
- Holding the Plaid `client_secret` and `access_token`s
- Minting short-lived session JWTs for the iOS client
- Exchanging `public_token` → `access_token` server-side
- Proxying `/transactions/sync` calls
- Receiving Plaid webhooks and fanning out to APNs

## What's stubbed vs. real

| Component | Status |
|---|---|
| SwiftData schema, migrations, repositories | Real |
| Keychain + Secure Enclave + biometric gate | Real |
| Backend proxy client (URLSession) | Real, awaiting backend |
| Plaid Link presentation | `SFSafariViewController` fallback — swap for `LinkKit` SDK when added |
| LLM categorization pipeline, cache, scrubber | Real; `LLMCategorizationClient` accepts any backend |
| Recurring detection (coefficient-of-variation) | Real |
| Certificate pinning | Hook point present (`BackendProxyConfiguration.pinnedCertificateSHA256`) — implement via `URLSessionDelegate` when backend is live |

## Foot-guns avoided (per TDD §8)

- **All bulk writes** go through `DatabaseActor` on a detached `ModelContext`.
- **UI consumes snapshots**, not `@Model` instances — see `TransactionSnapshot`, `AccountSnapshot`, `BudgetSnapshot`.
- **Pagination** via `FetchDescriptor.fetchLimit/fetchOffset` in `TransactionRepositoryImpl.fetchPage`.
- **Indices** annotated on hot predicate paths (`authorizedDate`, `plaidTransactionId`, etc.).
- **Main-thread writes** only for user-originated edits (notes, category overrides, flags).

## Tests

```bash
swift test --filter BudgetCoreTests
swift test --filter BudgetDataTests
swift test --filter SecureStorageTests
swift test --filter TransactionEngineTests
```
