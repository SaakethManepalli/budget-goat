# Plaid Production Access Application — Budget Goat

Answers to paste into the Plaid Dashboard production access questionnaire. Fill in `[BRACKETED]` placeholders with your info before submitting.

---

## 1. Company Information

| Field | Value |
|---|---|
| Company / legal entity | Saaketh Manepalli (sole proprietor / personal project) |
| Doing business as | Budget Goat |
| Website | https://budgetgoat.app |
| Country | United States |
| Founded | 2026-04 |
| Team size | 1 |
| Primary contact | Saaketh Manepalli, saaketh.manepalli@gmail.com |

---

## 2. Product Overview

**Product name:** Budget Goat

**One-line description:** A privacy-first personal budgeting iOS app that analyzes linked bank transactions entirely on-device.

**Full description (150-250 words):**

Budget Goat is a native iOS application built with SwiftUI and SwiftData that helps individuals understand their spending, set category-based monthly budgets, and identify recurring subscriptions. It is designed as a privacy-first, local-first product: all transaction analysis, categorization, and recurring-pattern detection happens on the user's device. No user-identifiable financial data is ever sent to third-party analytics or advertising platforms.

The only data that leaves the device is (a) Plaid API traffic proxied through a secure backend that holds the Plaid access token server-side, and (b) optional LLM-based transaction categorization requests which strip all user identifiers and round transaction amounts before egress. Users link a depository or credit account through Plaid Link, and the app syncs transactions via `/transactions/sync`. Categorization, budgeting math, and recurring-expense detection all run on the iOS device against the local SwiftData store.

**Target users:** Individual U.S. consumers looking for a budgeting tool that does not monetize their financial data.

**Business model:** Free during beta. Budget Goat does not sell, share, or monetize user financial data in any form.

---

## 3. Requested Plaid Products

| Product | Requested | Justification |
|---|---|---|
| **Transactions** | Yes | Core product feature. Used via `/transactions/sync` (cursor-based) to import and keep transactions fresh. Powers budgets, category spending charts, and recurring-pattern detection. |
| Auth, Balance, Identity | No | Budget Goat does not initiate ACH, verify ownership, or move money. |
| Investments, Liabilities, Assets | No | Not used in v1. |
| Identity Verification, Monitor | No | No KYC requirement; app does not onboard users for regulated financial services. |
| Recurring Transactions (add-on) | No | Recurring expense detection is implemented client-side using coefficient-of-variation analysis on `/transactions/sync` output. |
| Enrich (add-on) | No | On-device categorization pipeline uses Plaid's `personal_finance_category` with confidence thresholding + an LLM fallback (PII-scrubbed). |

---

## 4. User Flow

1. User downloads Budget Goat from the App Store and opens the app.
2. App requests biometric unlock (Face ID / Touch ID) — required on every foreground.
3. On first launch, user sees an onboarding screen and taps "Connect a Bank."
4. App requests a `link_token` from Budget Goat's backend (backend calls `/link/token/create` with `client_secret` server-side).
5. App opens Plaid Link using the `link_token`. User selects their institution and authenticates with their bank credentials inside Plaid Link — credentials never pass through Budget Goat.
6. Plaid Link returns a `public_token` to the iOS app.
7. App posts the `public_token` to the backend. Backend calls `/item/public_token/exchange` with the Plaid `client_secret`, receives the `access_token`, and persists the `access_token` server-side. Only an opaque `item_id` is returned to the iOS app.
8. App stores the `item_id` in the iOS Keychain (biometric-gated) and registers accounts in the local SwiftData store.
9. Backend runs `/transactions/sync` and returns cursor-paginated deltas. App applies inserts/updates/deletes to local SwiftData.
10. User views transactions, creates monthly category budgets, and reviews auto-detected recurring expenses — all rendered from the local SwiftData store.
11. At any time, user can unlink a bank, which calls `/item/remove` server-side and purges local data for that item.

---

## 5. Data Use per Endpoint

### `/link/token/create`
- **Purpose:** Initialize Plaid Link for a given user session.
- **Frequency:** Once per Link flow (token expires in 4 hours).
- **Data retained:** None (tokens are ephemeral).

### `/item/public_token/exchange`
- **Purpose:** Exchange the single-use `public_token` for a long-lived `access_token`.
- **Frequency:** Once per linked institution.
- **Data retained (server):** Encrypted `access_token` and `item_id` mapped to the account owner's user ID. Retained for as long as the account is linked. Deleted on `/item/remove`.
- **Data retained (iOS device):** `item_id` only, stored in iOS Keychain under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` + `.biometryCurrentSet` access control.

### `/transactions/sync`
- **Purpose:** Cursor-based ingestion of new, modified, and removed transactions.
- **Frequency:** Triggered on app foreground, user-initiated pull-to-refresh, and silent push notifications relayed from Plaid webhooks.
- **Data retained (server):** None — backend is a stateless proxy for sync calls. Cursors are stored on the iOS device in `UserDefaults`.
- **Data retained (iOS device):** Full transaction records are stored in encrypted SwiftData (iOS Data Protection `NSFileProtectionComplete`). Retained for the lifetime of the linked account.

### `/item/remove`
- **Purpose:** Revoke Plaid access when a user unlinks a bank or deletes their account.
- **Frequency:** On user action.
- **Data retained:** None. Access token is deleted from backend DB; iOS app cascades local deletion of associated accounts and transactions.

---

## 6. Data Retention & Deletion

| Data Type | Retention | Storage |
|---|---|---|
| Plaid `access_token` | Lifetime of linked account, deleted on unlink or account close | Server DB (encrypted at rest) |
| `item_id` | Same as above | iOS Keychain (biometric-gated) |
| Transaction records | Lifetime of the user's installation | iOS device only, SwiftData with `NSFileProtectionComplete` |
| Cursors | Lifetime of linked item | iOS device `UserDefaults` |
| Server logs | 14 days rolling | Backend hosting provider |
| Analytics | None — no third-party analytics SDK | N/A |

**User-initiated deletion:** The Settings screen offers "Unlink Bank" per item and "Delete all local data" for the app as a whole. Unlinking calls `/item/remove` on Plaid and purges the local SwiftData store for that institution. Uninstalling the app removes all device-local data (Keychain, SwiftData, UserDefaults) per iOS platform guarantees.

---

## 7. Security Overview

See `docs/SECURITY.md` for the full technical document. Summary:

- **Access tokens** never leave the backend. The iOS client only holds an opaque `item_id`.
- **At-rest encryption:** SwiftData store uses iOS Data Protection class `NSFileProtectionComplete`. Keychain entries use hardware-bound `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` with `.biometryCurrentSet`.
- **In-transit encryption:** TLS 1.2+ for all requests. Production builds include certificate pinning for the Budget Goat backend domain.
- **Zero third-party analytics:** No Firebase, Mixpanel, Datadog RUM, Sentry `userInfo`, or any SDK that could exfiltrate financial data. Crash reports use Apple MetricKit only.
- **LLM categorization privacy:** When a cloud LLM is used for transaction categorization, the payload contains no user identifiers, rounds amounts, and strips account-number patterns from transaction names before egress.
- **Backend hosting:** Fly.io (US region), with TLS-terminating load balancer and least-privilege IAM.
- **Incident response:** Documented in `docs/SECURITY.md` §6. saaketh.manepalli@gmail.com contact.

---

## 8. Required URLs

| URL Type | Value |
|---|---|
| App website / landing page | https://budgetgoat.app |
| Privacy policy | https://budgetgoat.app/privacy (source: `docs/PRIVACY_POLICY.md`) |
| Terms of service | https://budgetgoat.app/terms (source: `docs/TERMS_OF_SERVICE.md`) |
| App Store listing | https://apps.apple.com/app/idXXXXXXXXX (populate post-release) |
| Support contact | saaketh.manepalli@gmail.com |
| Security disclosure | saaketh.manepalli@gmail.com |
| Webhook endpoint | https://budget-goat-api.fly.dev/api/plaid/webhooks |

---

## 9. Webhook Configuration

Backend exposes a signed webhook handler at https://budget-goat-api.fly.dev/api/plaid/webhooks.

Events consumed:
- `SYNC_UPDATES_AVAILABLE` → enqueue background transaction sync + APNs silent push to the iOS client
- `ITEM_LOGIN_REQUIRED` → surface re-authentication banner in the iOS app
- `PENDING_EXPIRATION` → prompt user to re-auth before 7-day cutoff
- `USER_PERMISSION_REVOKED` → purge local data and delete server-side token
- `TRANSACTIONS_REMOVED` → sync to remove canceled transactions from local store

Signature verification uses the `Plaid-Verification` JWT header per Plaid's webhook signing docs.

---

## 10. Compliance Attestations

- [ ] Budget Goat does not sell, rent, or share user financial data with advertising networks, data brokers, or any third party beyond what is strictly necessary to provide the service.
- [ ] Budget Goat does not use Plaid data for credit decisions, marketing, or profile enrichment sold to third parties.
- [ ] Budget Goat complies with the Plaid Developer Policy, End User Privacy Policy display requirements, and Gramm-Leach-Bliley Act data handling obligations for U.S. consumers.
- [ ] Budget Goat complies with Apple App Store Review Guidelines §5.1.5 (financial data handling) and §5.1.1 (privacy disclosures).

---

## 11. Notes for the Reviewer

- This is a solo / personal project; SOC 2 Type II is not currently in place. Budget Goat's privacy posture is achieved via a **local-first architecture**: 99% of sensitive data never leaves the user's device. Only Plaid API traffic traverses our servers, and only the access token is stored (encrypted) on our backend.
- The iOS app source is available to reviewers on request.
- The backend proxy code is in the `backend/` directory of the same repository.
