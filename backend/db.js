import { createCipheriv, createDecipheriv, randomBytes, createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const MASTER_KEY_HEX = process.env.DB_ENCRYPTION_KEY;
if (!MASTER_KEY_HEX) {
  console.error('Missing DB_ENCRYPTION_KEY. Generate: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"');
  process.exit(1);
}
const MASTER_KEY = Buffer.from(MASTER_KEY_HEX, 'hex');
if (MASTER_KEY.length !== 32) {
  console.error('DB_ENCRYPTION_KEY must be 64 hex chars (32 bytes)');
  process.exit(1);
}

const STORE_PATH = process.env.DB_PATH || path.join(__dirname, 'items.enc');

// In-memory cache — read once on startup, write-through on mutation
let cache = load();

function deriveDataKey(itemId) {
  return createHash('sha256').update(MASTER_KEY).update(itemId).digest();
}

function encryptToken(itemId, plaintext) {
  const iv  = randomBytes(16);
  const key = deriveDataKey(itemId);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return { iv: iv.toString('hex'), data: enc.toString('hex'), tag: tag.toString('hex') };
}

function decryptToken(itemId, record) {
  const key = deriveDataKey(itemId);
  const decipher = createDecipheriv('aes-256-gcm', key, Buffer.from(record.iv, 'hex'));
  decipher.setAuthTag(Buffer.from(record.tag, 'hex'));
  return Buffer.concat([
    decipher.update(Buffer.from(record.data, 'hex')),
    decipher.final(),
  ]).toString('utf8');
}

function load() {
  if (!existsSync(STORE_PATH)) return {};
  try {
    return JSON.parse(readFileSync(STORE_PATH, 'utf8'));
  } catch {
    return {};
  }
}

function persist() {
  writeFileSync(STORE_PATH, JSON.stringify(cache), { mode: 0o600 });
}

export function storeItem(itemId, accessToken, institutionId, institutionName) {
  cache[itemId] = {
    enc: encryptToken(itemId, accessToken),
    institutionId,
    institutionName,
    createdAt: cache[itemId]?.createdAt ?? Date.now(),
    updatedAt: Date.now(),
  };
  persist();
}

export function getAccessToken(itemId) {
  const entry = cache[itemId];
  if (!entry) return null;
  try {
    return decryptToken(itemId, entry.enc);
  } catch {
    return null;
  }
}

export function deleteItem(itemId) {
  delete cache[itemId];
  persist();
}

export function itemExists(itemId) {
  return itemId in cache;
}
