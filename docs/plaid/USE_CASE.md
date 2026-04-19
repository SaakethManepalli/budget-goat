# Plaid Use Case Summary

Shorter copy you can paste directly into free-text fields in the Plaid Dashboard when the full application at `docs/plaid/APPLICATION.md` is more than the form accepts.

---

## One-sentence pitch (150 chars)

A privacy-first iOS budgeting app that imports transactions via Plaid and analyzes them entirely on the user's device — nothing sensitive leaves the phone.

## Short description (500 chars)

Budget Goat is a native iOS personal budgeting app that uses Plaid's Transactions product to import and keep a user's linked bank and credit card transactions up to date. All categorization, budgeting math, and recurring-expense detection runs locally on the iOS device. Access tokens are held exclusively on our backend; the iOS client never sees them. No third-party analytics or advertising SDKs are embedded.

## Long description (1500 chars)

Budget Goat is a native iOS application built with SwiftUI and SwiftData. It imports a user's transactions through Plaid's `/transactions/sync` endpoint and stores them in an encrypted on-device database. From that local database, the app renders monthly category spending, lets users set per-category monthly budgets with threshold alerts, and automatically identifies recurring expenses (subscriptions, rent, utilities) using a statistical coefficient-of-variation algorithm running on-device.

Our defining architectural constraint is that identifiable financial data must not leave the user's device. Plaid access tokens are held server-side and never transmitted to the iOS client — the client holds only an opaque `item_id`. When a transaction's Plaid category confidence is below threshold, an on-device or PII-scrubbed cloud LLM categorizes the raw description into a canonical merchant name and category; we round amounts and strip user identifiers before any egress.

We require only the **Transactions** product. We do not move money, assess credit, verify identity, or enrich user profiles for third parties. Users can disconnect any bank or delete all data at any time from the in-app Settings screen.

## Why a user benefits from Plaid data in our app

Users already have their transaction history at their banks; what they lack is a fast, private, automatic way to see how they spend across categories, catch unwanted subscriptions, and stay under monthly budgets. Plaid gives Budget Goat accurate, deduplicated, cleaned transaction data without requiring users to upload CSV exports or grant credentials to a non-regulated aggregator.

## Data usage summary

- Imported: transactions, account names, balances, merchant names, Plaid category hints.
- Stored on our backend: encrypted access tokens and opaque item IDs only.
- Stored on the device: full transaction history, in an encrypted SwiftData store protected by `NSFileProtectionComplete`.
- Never collected: bank credentials, contacts, advertising identifiers, precise location beyond merchant-provided city.
- Never shared: with advertisers, data brokers, credit bureaus, or any third party beyond Plaid itself and our cloud hosting provider.
