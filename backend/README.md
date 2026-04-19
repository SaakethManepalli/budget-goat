# Budget Goat Backend (Plaid Proxy)

Minimal Node/Express backend that holds the Plaid `client_secret` and `access_token`s on behalf of the iOS app. Keeps sensitive credentials off-device per the zero-knowledge architecture.

## One-time setup

1. **Get Plaid sandbox credentials** (free, instant):
   - Sign up at https://dashboard.plaid.com/signup
   - Dashboard → Developers → Keys → copy `client_id` and `Sandbox secret`

2. **Install deps & configure env:**
   ```bash
   cd backend
   npm install
   cp .env.example .env
   # edit .env → paste PLAID_CLIENT_ID and PLAID_SECRET
   ```

3. **Run:**
   ```bash
   npm run dev
   # → Budget Goat backend listening on http://0.0.0.0:8787 (sandbox)
   ```

## iOS scheme config

In Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, add:

| Name | Value |
|---|---|
| `BUDGETGOAT_BACKEND_URL` | `http://localhost:8787` (simulator) or `http://YOUR_MAC_IP:8787` (physical device) |

For a physical iPhone: find your Mac's LAN IP (`ipconfig getifaddr en0`), make sure the phone is on the same Wi-Fi, and because iOS blocks plaintext HTTP by default, add an ATS exception to Info.plist for local dev only:

```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsLocalNetworking</key>
  <true/>
</dict>
```

Remove this before shipping — production must be HTTPS.

## Testing with Plaid Sandbox credentials

When the Link flow opens:
- Pick any institution (e.g., "First Platypus Bank")
- Username: `user_good`
- Password: `pass_good`
- Skip MFA if prompted with `1234`

This populates the sandbox account with fake transactions you can sync.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET  | `/health` | liveness probe |
| POST | `/api/link/token/create` | create a `link_token` to initialize Plaid Link |
| POST | `/api/item/public_token/exchange` | exchange `public_token` → store `access_token` server-side, return `item_id` |
| POST | `/api/transactions/sync` | cursor-based transaction sync |
| POST | `/api/item/remove` | revoke access + delete stored token |

## Storage

Dev mode persists item → access_token mappings in `backend/.items.json` (gitignored). For production, replace with a real DB plus HSM-wrapped token encryption.

## Auth

The iOS client sends `Authorization: Bearer <session-token>`, but this dev backend does not validate it. Before shipping, add real session auth (e.g., Sign in with Apple → JWT).
