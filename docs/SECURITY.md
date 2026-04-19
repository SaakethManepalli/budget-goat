# Budget Goat Security Overview

**Document purpose:** Security posture document for Plaid production review and internal reference. Summarizes how Budget Goat protects end-user financial data end-to-end.

**Last updated:** 2026-04-18

---

## 1. Design Principle: Local-First, Zero-Knowledge

Budget Goat's single most important security property is **data gravity**: all identifiable financial data is analyzed on the user's device and never transmitted to any third party in identifiable form.

| Data type | Where it lives | Why |
|---|---|---|
| Transactions, balances, categories | iOS device only | Analysis is entirely local |
| Budgets, notes, flags | iOS device only | User-generated, no server use case |
| Plaid `access_token` | Backend only, encrypted | Client-side storage would expand blast radius |
| Opaque `item_id` | iOS Keychain (biometric-gated) | Needed as FK to access token in backend |
| Categorization prompts | Sent to LLM provider with PII scrubbed | Minimum necessary payload |

---

## 2. Access Token Custody

Plaid access tokens grant read access to the full transaction history of every account linked to a given `item_id`. The blast radius of compromise is significant, so:

- **Access tokens never appear on the iOS client.** Not in memory, not in Keychain, not in logs, not in crash reports.
- The iOS client stores only the opaque `item_id` in the Keychain under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` with a `SecAccessControl` requiring `.biometryCurrentSet`. This binds access to the current biometric enrollment and invalidates if the user changes it.
- All Plaid API calls are proxied through our backend. The backend holds the Plaid `client_secret` (env var, never committed) and the per-item `access_token`s (encrypted at rest).
- Token encryption uses AES-256-GCM envelope encryption. The master key is held in Fly.io Secrets (the hosting platform's managed secrets store); per-item data keys are derived via HKDF-SHA256 and stored alongside the encrypted ciphertext in the application database.

## 3. Transport Security

- **TLS 1.2+** is enforced on all backend endpoints. TLS 1.3 preferred.
- Production iOS builds enable **certificate pinning** for the Budget Goat backend domain via a custom `URLSessionDelegate`. The pinned certificate's SHA-256 is supplied at build time and rotated via OTA config ahead of expiry.
- `NSAllowsArbitraryLoads = false` in Info.plist. `NSAllowsLocalNetworking` is true in debug builds only for local backend development.
- **Device request signing:** Each backend request is signed with an ECDSA key provisioned on first launch. Private key is stored in the Secure Enclave where available (`kSecAttrTokenID = kSecAttrTokenIDSecureEnclave`). The backend validates the signature against the registered public key, preventing token replay from a different device.

## 4. At-Rest Encryption

| Layer | Mechanism |
|---|---|
| iOS SwiftData store | File is placed in Application Support with iOS Data Protection class `NSFileProtectionComplete` (entitlement `com.apple.developer.default-data-protection = NSFileProtectionComplete`). File is unreadable while the device is locked. |
| iOS Keychain entries | `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` + `.biometryCurrentSet` access control |
| Backend DB | SQLite with application-layer AES-256-GCM encryption on the `access_token` column; database volume encrypted at the host level by Fly.io |
| Backend backups | Encrypted with customer-managed keys; retention 30 days |

## 5. Application Security

- **No third-party analytics, ads, or session-recording SDKs** are embedded in the iOS app. Crash signals are collected via Apple MetricKit, which does not include user-provided content.
- **Dependencies** are minimized and pinned. Dependabot / Renovate notifies on upstream CVEs.
- **Static analysis:** SwiftLint and `swift build -warnings-as-errors` are enforced in CI.
- **Secrets management:** Plaid `client_secret`, Anthropic API keys, and signing keys are stored in Fly.io Secrets (encrypted at rest, exposed to the application as env vars at runtime). None are committed to source control. Backend requires the env vars to be present at startup.
- **Input validation:** The iOS app treats all API responses as untrusted. Decoding into Swift types fails closed; malformed responses surface a user-facing error and do not mutate SwiftData.

## 6. Backend Security

- Hosted on Fly.io in the US region (IAD or EWR).
- Least-privilege IAM: production DB credentials are available only to the application role. No human engineer has standing access to the production DB; break-glass access is audit-logged.
- Structured logs exclude request bodies and any transaction content. Logs retain only `{timestamp, method, path, status, latency, itemId_prefix}`.
- Rate limiting: per-user token bucket on all endpoints that touch Plaid APIs.
- `[IF PRESENT:]` WAF rules for common attack patterns (SQLi, path traversal) at the load-balancer layer.

## 7. Privacy Guardrails Around LLM Categorization

When a transaction requires categorization via the LLM fallback path (Plaid confidence < 0.85), the payload is scrubbed before egress by the `PIIStripper` in `Sources/TransactionEngine/Privacy/PIIStripper.swift`. The scrubbed payload contains:

- A rotating opaque UUID (**not** the Plaid transaction ID, **not** the user's ID)
- Merchant description with account-number patterns regex-stripped
- Amount **rounded to the nearest whole unit**
- ISO 4217 currency code
- ISO-8601 date

It does **not** contain: user identifier, account identifier, geolocation, IP address, or any contextual data that could correlate to a specific individual across calls.

## 8. Incident Response

- Security reports may be submitted to saaketh.manepalli@gmail.com (PGP key available on request).
- Acknowledgement target: 2 business days. Triage target: 5 business days.
- **Credential compromise runbook** (Plaid `client_secret`):
  1. Rotate secret in the Plaid Dashboard.
  2. Deploy updated backend.
  3. Invalidate existing device-signing public keys; require re-attestation on next launch.
  4. Notify affected users if token exfiltration is suspected.
- **User-side compromise (lost/stolen device):** user should disconnect banks from [my.plaid.com](https://my.plaid.com) and remotely wipe the device via iCloud.

## 9. Compliance

- Aligned with the **Plaid Developer Policy** and **End User Privacy Policy**.
- **Gramm-Leach-Bliley Act (GLBA):** Budget Goat acts as a non-financial-institution service provider handling NPI. We maintain administrative, technical, and physical safeguards proportional to our scale and the sensitivity of the data.
- **CCPA / CPRA:** Honored via the user rights described in `docs/PRIVACY_POLICY.md`.
- **GDPR / UK GDPR:** Honored for applicable users; legal bases per `docs/PRIVACY_POLICY.md`.
- **Apple App Store Review Guidelines §5.1.5** (financial data) and **§5.1.1(v)** (account deletion): user-initiated account deletion is available from the Settings screen.

SOC 2 Type II is not currently in place; the local-first architecture substantially limits the data surface to which such an audit would apply. We will revisit as scale warrants.

## 10. What's Deliberately Not Present

A non-exhaustive list of practices Budget Goat does **not** engage in, for transparency:

- No selling, renting, or licensing of user data.
- No training of generalized machine-learning models on user transaction data.
- No advertising network, retargeting pixel, IDFA collection, or SKAdNetwork usage.
- No cross-device or cross-app tracking.
- No unsolicited email beyond transactional messages (e.g., account deletion confirmation).
- No server-side retention of transaction content.

## 11. Contact

- Security: saaketh.manepalli@gmail.com
- Privacy: saaketh.manepalli@gmail.com
- General: saaketh.manepalli@gmail.com
