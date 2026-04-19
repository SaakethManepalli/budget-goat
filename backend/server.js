import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Configuration, PlaidApi, PlaidEnvironments, Products, CountryCode } from 'plaid';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PLAID_CLIENT_ID = process.env.PLAID_CLIENT_ID;
const PLAID_SECRET    = process.env.PLAID_SECRET;
const PLAID_ENV       = process.env.PLAID_ENV || 'sandbox';
const PORT            = Number(process.env.PORT || 8787);

if (!PLAID_CLIENT_ID || !PLAID_SECRET) {
  console.error('Missing PLAID_CLIENT_ID or PLAID_SECRET in env. Set them in backend/.env');
  process.exit(1);
}

const plaid = new PlaidApi(new Configuration({
  basePath: PlaidEnvironments[PLAID_ENV],
  baseOptions: { headers: {
    'PLAID-CLIENT-ID': PLAID_CLIENT_ID,
    'PLAID-SECRET':    PLAID_SECRET,
  }}
}));

const STORE_PATH = path.join(__dirname, '.items.json');
const readStore  = () => { try { return JSON.parse(fs.readFileSync(STORE_PATH, 'utf8')); } catch { return {}; } };
const writeStore = (s) => fs.writeFileSync(STORE_PATH, JSON.stringify(s, null, 2));

const app = express();
app.use(cors());
app.use(express.json({ limit: '512kb' }));

app.use((req, _res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

app.get('/health', (_req, res) => res.json({ ok: true, env: PLAID_ENV }));

app.post('/api/link/token/create', async (req, res) => {
  try {
    const response = await plaid.linkTokenCreate({
      user: { client_user_id: 'dev-user' },
      client_name: 'Budget Goat',
      products: [Products.Transactions],
      country_codes: [CountryCode.Us],
      language: 'en',
    });
    res.json({ link_token: response.data.link_token, expiration: response.data.expiration });
  } catch (e) {
    console.error('link/token/create failed:', e.response?.data || e.message);
    res.status(500).json({ error: e.response?.data || e.message });
  }
});

app.post('/api/item/public_token/exchange', async (req, res) => {
  try {
    const { public_token, institution_id } = req.body;
    if (!public_token) return res.status(400).json({ error: 'public_token required' });

    const ex = await plaid.itemPublicTokenExchange({ public_token });
    const access_token = ex.data.access_token;
    const item_id      = ex.data.item_id;

    const accts = await plaid.accountsGet({ access_token });
    const institutionName = accts.data.item.institution_id
      ? (await plaid.institutionsGetById({
          institution_id: accts.data.item.institution_id,
          country_codes:  [CountryCode.Us],
        })).data.institution.name
      : 'Unknown Institution';

    const store = readStore();
    store[item_id] = { access_token, institution_id, institutionName };
    writeStore(store);

    res.json({
      item_id,
      institution_id: institution_id || accts.data.item.institution_id,
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
    console.error('exchange failed:', e.response?.data || e.message);
    res.status(500).json({ error: e.response?.data || e.message });
  }
});

app.post('/api/transactions/sync', async (req, res) => {
  try {
    const { item_id, cursor, count } = req.body;
    const store = readStore();
    const entry = store[item_id];
    if (!entry) return res.status(404).json({ error: 'item not found' });

    const response = await plaid.transactionsSync({
      access_token: entry.access_token,
      cursor: cursor || undefined,
      count:  count || 500,
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
    console.error('sync failed:', e.response?.data || e.message);
    const code = e.response?.data?.error_code;
    if (code === 'ITEM_LOGIN_REQUIRED') {
      return res.status(409).json({ error: 'ITEM_LOGIN_REQUIRED', item_id: req.body.item_id });
    }
    res.status(500).json({ error: e.response?.data || e.message });
  }
});

app.post('/api/item/remove', async (req, res) => {
  try {
    const { item_id } = req.body;
    const store = readStore();
    const entry = store[item_id];
    if (entry) {
      await plaid.itemRemove({ access_token: entry.access_token });
      delete store[item_id];
      writeStore(store);
    }
    res.json({});
  } catch (e) {
    console.error('remove failed:', e.response?.data || e.message);
    res.status(500).json({ error: e.response?.data || e.message });
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
      primary:  t.personal_finance_category.primary,
      detailed: t.personal_finance_category.detailed,
      confidence_level: t.personal_finance_category.confidence_level,
    } : null,
    logo_url: t.logo_url,
    location: t.location ? { lat: t.location.lat, lon: t.location.lon } : null,
  };
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Budget Goat backend listening on http://0.0.0.0:${PORT} (${PLAID_ENV})`);
});
