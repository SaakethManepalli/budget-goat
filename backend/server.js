import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } from 'plaid';
import { storeItem, getAccessToken, deleteItem, itemExists } from './db.js';
import { requireAuth } from './auth.js';

const NODE_ENV           = process.env.NODE_ENV || 'development';
const IS_PRODUCTION      = NODE_ENV === 'production';
const PLAID_CLIENT_ID    = process.env.PLAID_CLIENT_ID;
const PLAID_SECRET       = process.env.PLAID_SECRET;
const PLAID_ENV          = process.env.PLAID_ENV || 'sandbox';
const PLAID_REDIRECT_URI = process.env.PLAID_REDIRECT_URI || null;
const PLAID_WEBHOOK_URL  = process.env.PLAID_WEBHOOK_URL  || null;
const PLAID_PRODUCTS     = (process.env.PLAID_PRODUCTS || 'transactions')
                             .split(',').map(s => s.trim());
const PORT               = Number(process.env.PORT || 8787);

if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
  console.error('Missing PLAID_CLIENT_ID or PLAID_SECRET');
  process.exit(1);
}

// Startup contract. Two tiers:
// 1. NODE_ENV=production  → no DEV bypass tokens allowed
// 2. PLAID_ENV=production → strict: https redirect, real Plaid credentials
// Running on Fly.io in NODE_ENV=production with PLAID_ENV=sandbox is a valid
// staging mode and is not rejected here.
{
  const violations = [];

  // Tier 1 — Node-production security hardening
  if (IS_PRODUCTION && process.env.DEV_SESSION_TOKEN) {
    violations.push('DEV_SESSION_TOKEN must not be set when NODE_ENV=production');
  }

  // Tier 2 — Plaid-production enforcement (only when actually hitting Plaid prod)
  if (PLAID_ENV === 'production') {
    if (!PLAID_REDIRECT_URI) {
      violations.push('PLAID_REDIRECT_URI must be set when PLAID_ENV=production');
    }
    if (PLAID_REDIRECT_URI && !PLAID_REDIRECT_URI.startsWith('https://')) {
      violations.push('PLAID_REDIRECT_URI must be an https:// Universal Link when PLAID_ENV=production');
    }
  }

  if (violations.length) {
    console.error('Refusing to start:\n  - ' + violations.join('\n  - '));
    process.exit(1);
  }
}

const plaid = new PlaidApi(new Configuration({
  basePath: PlaidEnvironments[PLAID_ENV],
  baseOptions: { headers: {
    'PLAID-CLIENT-ID': PLAID_CLIENT_ID,
    'PLAID-SECRET':    PLAID_SECRET,
  }}
}));

const app = express();

// Trust proxy headers on Fly.io
app.set('trust proxy', 1);

// Security headers
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Strict-Transport-Security', 'max-age=63072000; includeSubDomains');
  next();
});

app.use(cors({ origin: false }));
app.use(express.json({ limit: '64kb' }));

// Global rate limit
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests' },
});
app.use(globalLimiter);

// Tight limit on Plaid-touching endpoints
const plaidLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Too many requests to bank endpoints' },
});

// Minimal, privacy-safe access log. Never logs bodies, query strings, or headers.
app.use((req, res, next) => {
  const started = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - started;
    console.log(`${new Date().toISOString()} ${req.method} ${req.path} ${res.statusCode} ${ms}ms`);
  });
  next();
});

app.get('/health', (_req, res) => res.json({ ok: true, env: PLAID_ENV }));

// Device auth — issues a 30-day JWT for a device UUID
// No requireAuth — this IS the auth endpoint
app.post('/auth/device', rateLimit({ windowMs: 60_000, max: 5 }), async (req, res) => {
  try {
    const { device_id } = req.body;
    if (!device_id || typeof device_id !== 'string' || device_id.length < 10) {
      return res.status(400).json({ error: 'device_id required' });
    }

    const { SignJWT } = await import('jose');
    const secret = new TextEncoder().encode(process.env.JWT_SECRET);
    const token = await new SignJWT({ sub: device_id, type: 'device' })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime('30d')
      .sign(secret);

    res.json({ session_token: token, expires_in: 30 * 24 * 3600 });
  } catch (e) {
    console.error('device auth error:', e.message);
    res.status(500).json({ error: 'Unable to issue token' });
  }
});

// All API routes require authentication
app.use('/api', requireAuth);

app.post('/api/link/token/create', plaidLimiter, async (req, res) => {
  try {
    const isSandbox = PLAID_ENV === 'sandbox';
    const payload = {
      user: {
        client_user_id: req.userId,
        // In sandbox, supplying a pre-verified phone bypasses Plaid's Layer
        // phone-entry prompt entirely. Omitted in production so real users
        // go through proper verification.
        ...(isSandbox ? {
          phone_number: '+14155550015',
          phone_number_verified_time: new Date().toISOString(),
        } : {}),
      },
      client_name: 'Budget Goat',
      products: PLAID_PRODUCTS,
      country_codes: [CountryCode.Us],
      language: 'en',
    };
    if (PLAID_REDIRECT_URI) payload.redirect_uri = PLAID_REDIRECT_URI;
    if (PLAID_WEBHOOK_URL)  payload.webhook      = PLAID_WEBHOOK_URL;

    const response = await plaid.linkTokenCreate(payload);
    res.json({ link_token: response.data.link_token, expiration: response.data.expiration });
  } catch (e) {
    const err = e.response?.data;
    console.error('link/token/create error:', err?.error_code, err?.error_message);
    res.status(502).json({
      error: err?.error_message || 'Unable to create link token',
      error_code: err?.error_code,
    });
  }
});

app.post('/api/item/public_token/exchange', plaidLimiter, async (req, res) => {
  try {
    const { public_token, institution_id } = req.body;
    if (!public_token) return res.status(400).json({ error: 'public_token required' });

    const ex = await plaid.itemPublicTokenExchange({ public_token });
    const access_token = ex.data.access_token;
    const item_id      = ex.data.item_id;

    const accts = await plaid.accountsGet({ access_token });
    const institutionId = institution_id || accts.data.item.institution_id || 'unknown';

    let institutionName = 'Unknown Institution';
    try {
      const inst = await plaid.institutionsGetById({
        institution_id: institutionId,
        country_codes: [CountryCode.Us],
      });
      institutionName = inst.data.institution.name;
    } catch { /* non-fatal */ }

    storeItem(item_id, access_token, institutionId, institutionName);

    res.json({
      item_id,
      institution_id: institutionId,
      institution_name: institutionName,
      accounts: accts.data.accounts.map(a => ({
        account_id: a.account_id,
        name: a.name,
        mask: a.mask,
        type: a.type,
        subtype: a.subtype,
        iso_currency_code: a.balances.iso_currency_code || 'USD',
      })),
    });
  } catch (e) {
    console.error('exchange error:', e.response?.data?.error_code);
    res.status(500).json({ error: 'Unable to exchange token' });
  }
});

app.post('/api/transactions/sync', plaidLimiter, async (req, res) => {
  try {
    const { item_id, cursor, count } = req.body;
    if (!item_id) return res.status(400).json({ error: 'item_id required' });

    const access_token = getAccessToken(item_id);
    if (!access_token) return res.status(404).json({ error: 'item not found' });

    const response = await plaid.transactionsSync({
      access_token,
      cursor: cursor || undefined,
      count: Math.min(count || 500, 500),
    });

    const d = response.data;
    res.json({
      added:    d.added.map(mapTx),
      modified: d.modified.map(mapTx),
      removed:  d.removed.map(r => ({ transaction_id: r.transaction_id })),
      next_cursor: d.next_cursor,
      has_more:    d.has_more,
    });
  } catch (e) {
    const code = e.response?.data?.error_code;
    if (code === 'ITEM_LOGIN_REQUIRED') {
      return res.status(409).json({ error: 'ITEM_LOGIN_REQUIRED', item_id: req.body.item_id });
    }
    console.error('sync error:', code);
    res.status(500).json({ error: 'Unable to sync transactions' });
  }
});

// Update-mode link token — used by the iOS app to re-authenticate an
// existing item whose bank session has expired (ITEM_LOGIN_REQUIRED).
// The link token must be minted with the item's access_token; the iOS
// client never sees the access_token.
app.post('/api/link/token/update', plaidLimiter, async (req, res) => {
  try {
    const { item_id } = req.body;
    if (!item_id) return res.status(400).json({ error: 'item_id required' });

    const access_token = getAccessToken(item_id);
    if (!access_token) return res.status(404).json({ error: 'item not found' });

    const payload = {
      user: { client_user_id: req.userId },
      client_name: 'Budget Goat',
      country_codes: [CountryCode.Us],
      language: 'en',
      access_token,   // update mode is triggered by this field
    };
    if (PLAID_REDIRECT_URI) payload.redirect_uri = PLAID_REDIRECT_URI;
    if (PLAID_WEBHOOK_URL)  payload.webhook      = PLAID_WEBHOOK_URL;

    const response = await plaid.linkTokenCreate(payload);
    res.json({ link_token: response.data.link_token, expiration: response.data.expiration });
  } catch (e) {
    const err = e.response?.data;
    console.error('link/token/update error:', err?.error_code);
    res.status(502).json({ error: err?.error_message || 'Unable to create update link token' });
  }
});

// One-shot: attach the webhook URL to an already-linked item whose link_token
// was minted before PLAID_WEBHOOK_URL was set. Idempotent.
app.post('/api/item/webhook/attach', plaidLimiter, async (req, res) => {
  try {
    if (!PLAID_WEBHOOK_URL) return res.status(400).json({ error: 'PLAID_WEBHOOK_URL not configured' });
    const { item_id } = req.body;
    if (!item_id) return res.status(400).json({ error: 'item_id required' });
    const access_token = getAccessToken(item_id);
    if (!access_token) return res.status(404).json({ error: 'item not found' });

    await plaid.itemWebhookUpdate({ access_token, webhook: PLAID_WEBHOOK_URL });
    res.json({ ok: true });
  } catch (e) {
    const err = e.response?.data;
    console.error('item/webhook/attach error:', err?.error_code);
    res.status(502).json({ error: err?.error_message || 'Unable to attach webhook' });
  }
});

// Plaid webhook receiver. Not protected by requireAuth — Plaid signs
// webhook calls with a JWT in the `plaid-verification` header. In production
// you MUST verify this signature before acting on the payload.
// For now we log and store the event so a subsequent sync can react to it.
app.post('/plaid/webhooks', express.json(), async (req, res) => {
  const { webhook_type, webhook_code, item_id } = req.body || {};
  console.log(`[webhook] ${webhook_type}/${webhook_code} item=${item_id}`);

  // For ITEM_LOGIN_REQUIRED and PENDING_EXPIRATION, the next /transactions/sync
  // call will naturally return 409 from Plaid. The iOS client's reauth banner
  // fires from that 409. No server-side state needed beyond the access token
  // still being present — we simply don't delete it.
  //
  // For TRANSACTIONS_REMOVED, the next /transactions/sync will include the
  // removed IDs in the response automatically.
  //
  // For USER_PERMISSION_REVOKED, we purge the access token immediately.
  if (webhook_code === 'USER_PERMISSION_REVOKED' && item_id) {
    try { deleteItem(item_id); } catch {}
  }

  // Always 200 — Plaid will retry on non-2xx and spam the endpoint.
  res.sendStatus(200);
});

app.post('/api/item/remove', plaidLimiter, async (req, res) => {
  try {
    const { item_id } = req.body;
    if (!item_id) return res.status(400).json({ error: 'item_id required' });

    const access_token = getAccessToken(item_id);
    if (access_token) {
      try { await plaid.itemRemove({ access_token }); } catch { /* already removed */ }
      deleteItem(item_id);
    }
    res.json({});
  } catch (e) {
    console.error('remove error:', e.message);
    res.status(500).json({ error: 'Unable to remove item' });
  }
});

function mapTx(t) {
  return {
    transaction_id: t.transaction_id,
    account_id:     t.account_id,
    amount:         t.amount,
    iso_currency_code: t.iso_currency_code || 'USD',
    authorized_date:   t.authorized_date,
    date:              t.date,
    name:              t.name,
    merchant_name:     t.merchant_name,
    pending:           t.pending,
    personal_finance_category: t.personal_finance_category ? {
      primary:          t.personal_finance_category.primary,
      detailed:         t.personal_finance_category.detailed,
      confidence_level: t.personal_finance_category.confidence_level,
    } : null,
    logo_url: t.logo_url,
    location: t.location?.lat != null ? { lat: t.location.lat, lon: t.location.lon } : null,
  };
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Budget Goat backend started`);
  console.log(`  NODE_ENV:           ${NODE_ENV}`);
  console.log(`  PLAID_ENV:          ${PLAID_ENV}`);
  console.log(`  PLAID_REDIRECT_URI: ${PLAID_REDIRECT_URI ?? '(not set)'}`);
  console.log(`  PLAID_PRODUCTS:     ${PLAID_PRODUCTS.join(', ')}`);
  console.log(`  Listening on:       :${PORT}`);
});
