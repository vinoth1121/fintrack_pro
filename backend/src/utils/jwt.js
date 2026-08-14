const jwt = require('jsonwebtoken');
const pool = require('../db/pool');

/**
 * Generate an access token (short-lived) and a refresh token (long-lived).
 * Stores the refresh token in the DB for invalidation / rotation.
 */
async function generateTokens(userId) {
  const accessToken = jwt.sign(
    { sub: userId },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m' },
  );

  const refreshToken = jwt.sign(
    { sub: userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' },
  );

  // Decode to get the actual expiry instant for DB storage
  const decoded = jwt.decode(refreshToken);
  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, to_timestamp($3))',
    [userId, refreshToken, decoded.exp],
  );

  return { accessToken, refreshToken };
}

/**
 * Verify a refresh token — checks both JWT validity and DB existence.
 * Returns the user ID if valid, null otherwise.
 */
async function verifyRefreshToken(token) {
  try {
    const payload = jwt.verify(token, process.env.JWT_REFRESH_SECRET);
    const { rows } = await pool.query(
      'SELECT id FROM refresh_tokens WHERE token = $1 AND user_id = $2 AND expires_at > NOW()',
      [token, payload.sub],
    );
    if (rows.length === 0) return null;
    return payload.sub;
  } catch {
    return null;
  }
}

/**
 * Delete a single refresh token (used on logout) or all tokens for a user.
 */
async function revokeRefreshToken(token) {
  await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
}

async function revokeAllUserTokens(userId) {
  await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
}

/**
 * Sign a short-lived access token.
 */
function signAccessToken(payload) {
  return jwt.sign(payload, process.env.JWT_ACCESS_SECRET, {
    expiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  });
}

/**
 * Sign a long-lived refresh token.
 */
function signRefreshToken(payload) {
  return jwt.sign(
    { ...payload, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d' },
  );
}

/**
 * Verify a token with a given secret.
 */
function verifyToken(token, secret) {
  return jwt.verify(token, secret);
}

module.exports = {
  generateTokens,
  verifyRefreshToken,
  revokeRefreshToken,
  revokeAllUserTokens,
  signAccessToken,
  signRefreshToken,
  verifyToken,
};
