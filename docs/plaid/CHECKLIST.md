# Plaid Production Access — Submission Checklist

Work through this in order. Each item maps to something the Plaid review form requires or implicitly checks.

## Before you apply

- [ ] **Legal entity decision.** Decide whether to apply as (a) yourself as a sole proprietor or (b) a registered LLC/Inc. For an App Store paid app handling financial data, most reviewers recommend an LLC — shields personal liability.
- [ ] **Register a domain.** e.g., `budgetgoat.app`. Required for public-facing privacy policy + terms URLs.
- [ ] **Stand up a landing page.** A simple one-page site with: product description, privacy policy link, terms link, support email, App Store badge (post-release).
- [ ] **Host the Privacy Policy and Terms** at publicly-accessible URLs (e.g., `budgetgoat.app/privacy`, `budgetgoat.app/terms`). Fill in bracketed placeholders in `docs/PRIVACY_POLICY.md` and `docs/TERMS_OF_SERVICE.md`.
- [x] **Support email inbox.** saaketh.manepalli@gmail.com
- [x] **Security disclosure email.** saaketh.manepalli@gmail.com (same inbox for now)

## Backend readiness

- [ ] **Deploy the backend proxy** to a persistent host (Fly.io / Render / Railway / AWS / GCP are all fine). Sandbox-only is insufficient for production review.
- [ ] **TLS on the backend.** Managed hosts issue certs for you; verify.
- [ ] **Encrypt access tokens at rest.** The dev `.items.json` store is NOT acceptable for production. Migrate to a real DB with envelope encryption. Document the mechanism in `docs/SECURITY.md` §2.
- [ ] **Rotate the Plaid sandbox secret out of any committed config.** Only env vars.
- [ ] **Implement webhook endpoint** at `/api/plaid/webhooks` with JWT signature verification per Plaid's docs.
- [ ] **Certificate pinning** for the backend domain in production iOS builds. (Update `BackendProxyConfiguration.pinnedCertificateSHA256` and implement the `URLSessionDelegate`.)

## iOS app readiness

- [ ] **App Store Connect** listing created (can be draft).
- [ ] **Privacy Nutrition Label** filled in per the actual data flows (Contact Info: none; Financial Info: Other Financial Info → Linked to User → Used for App Functionality only).
- [ ] **App Store screenshots** — 6.7" and 6.1" at minimum.
- [ ] **Account deletion flow** reachable from Settings (App Store Guideline §5.1.1(v)).
- [ ] **Info.plist** contains `NSFaceIDUsageDescription`, `UILaunchScreen`, and has `NSAllowsArbitraryLoads` removed for production builds.

## Paperwork for the Plaid application form

Fill in placeholders in these documents first, then use them as source material:

- [ ] `docs/plaid/APPLICATION.md` — long-form answers
- [ ] `docs/plaid/USE_CASE.md` — short-form copy for tight form fields
- [ ] `docs/PRIVACY_POLICY.md` → publish to `[/privacy]`
- [ ] `docs/TERMS_OF_SERVICE.md` → publish to `[/terms]`
- [ ] `docs/SECURITY.md` — keep internal or publish at `[/security]` if you want to advertise posture

## Apply in the Plaid Dashboard

1. **Dashboard → Team Settings → Company Information** — complete company profile, upload logo.
2. **Dashboard → Request Production Access** — select **Transactions** only. Paste from `USE_CASE.md` into free-text fields.
3. **Attach / link:**
   - Privacy policy URL
   - Terms URL
   - App website URL
   - App Store URL (if live) or a video demo
4. **Describe the user flow** — copy §4 from `APPLICATION.md`.
5. **Describe data retention & deletion** — copy §6 from `APPLICATION.md`.
6. **Security section** — summarize from `docs/SECURITY.md` (or link to a public copy).
7. **Submit.**

Review typically takes **2–10 business days**. Plaid may follow up with clarifying questions, most commonly around:
- Where access tokens are stored and how they're encrypted
- Your data retention and deletion commitments
- Whether your privacy policy mentions Plaid's End User Privacy Policy (it should — it's linked from ours in §4)
- How a user revokes access

Respond quickly and precisely. Citing specific code paths (e.g., `backend/server.js` line ranges) in responses speeds review.

## After approval

- [ ] Plaid issues a **production secret**. Treat it like a nuclear code — secrets manager only.
- [ ] Switch `PLAID_ENV=production` in the backend.
- [ ] Update iOS app pointing at production backend URL.
- [ ] Remove `NSAllowsLocalNetworking` from Info.plist in Release config.
- [ ] Run through a real-bank smoke test with your own account before submitting the App Store build.
- [ ] Enable production webhooks in Plaid Dashboard pointing at your deployed `/api/plaid/webhooks`.

## Rejection causes to avoid

1. **Vague privacy policy.** If Plaid can't see concrete retention periods, third-party sharing disclosures, and user deletion rights, they reject. Ours addresses all three.
2. **Storing access tokens client-side.** Plaid actively checks this. Our architecture keeps tokens server-side.
3. **No publicly-accessible privacy/terms.** URLs must resolve without auth.
4. **Requesting more products than you use.** We only ask for Transactions.
5. **Consumer credit use-cases without the right licensure.** We are not a credit product — state this clearly.
