import { jwtVerify } from 'jose';

const JWT_SECRET_HEX = process.env.JWT_SECRET;
if (!JWT_SECRET_HEX) {
  console.error('Missing JWT_SECRET. Generate: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"');
  process.exit(1);
}
if (JWT_SECRET_HEX.length < 64) {
  console.error('JWT_SECRET must be at least 64 hex characters (32 bytes).');
  process.exit(1);
}
const JWT_SECRET = new TextEncoder().encode(JWT_SECRET_HEX);

// Production refuses to start with the DEV_SESSION_TOKEN bypass present.
// Non-production environments ignore the variable entirely.
if (process.env.NODE_ENV === 'production' && process.env.DEV_SESSION_TOKEN) {
  console.error('Refusing to start: DEV_SESSION_TOKEN is set in production. Remove it from Fly.io secrets.');
  process.exit(1);
}

export async function requireAuth(req, res, next) {
  const header = req.headers['authorization'];
  if (!header?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }
  const token = header.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWT_SECRET, {
      algorithms: ['HS256'],
    });
    if (!payload.sub || typeof payload.sub !== 'string') {
      return res.status(401).json({ error: 'Malformed token' });
    }
    req.userId = payload.sub;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}
