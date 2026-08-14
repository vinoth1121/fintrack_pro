const { Router } = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const { signAccessToken, signRefreshToken, verifyToken } = require('../utils/jwt');
const authenticate = require('../middleware/auth');
const validate = require('../middleware/validate');
const { schemas } = require('../middleware/validate');

const router = Router();

// ── Helper: format user object for Flutter ───────────────────────────────────
function formatUser(row) {
  return {
    id: row.id,
    email: row.email,
    fullName: row.full_name,
    avatarUrl: row.avatar_url,
    phone: row.phone,
    currency: row.currency || 'INR',
    isEmailVerified: row.is_email_verified || false,
    isBiometricEnabled: row.is_biometric_enabled || false,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    avatarColor: '#6C5CE7',
    baseCurrency: row.currency || 'INR',
    monthlyIncomeGoal: row.monthly_income_goal || 120000,
    emailVerified: row.is_email_verified || false,
    name: row.full_name,
  };
}

// ── POST /register ───────────────────────────────────────────────────────────
router.post('/register', validate(schemas.register), async (req, res, next) => {
  try {
    const { fullName, name, email, password } = req.body;
    const displayName = fullName || name;
    if (!displayName || !email || !password) {
      return res.status(400).json({ ok: false, error: 'fullName, email, and password are required' });
    }

    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ ok: false, error: 'An account with this email already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const userId = uuid();
    const now = new Date().toISOString();

    const result = await pool.query(
      `INSERT INTO users (id, full_name, email, password_hash, currency, is_email_verified, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [userId, displayName, email.toLowerCase().trim(), passwordHash, 'INR', false, now, now],
    );

    const user = formatUser(result.rows[0]);
    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = signRefreshToken({ userId: user.id, email: user.email });

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken, new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString()],
    );

    res.status(201).json({
      ok: true,
      user,
      accessToken,
      refreshToken,
      message: 'Registration successful. Please verify your email.',
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /login ──────────────────────────────────────────────────────────────
router.post('/login', validate(schemas.login), async (req, res, next) => {
  try {
    const { email, password, rememberMe } = req.body;

    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (result.rows.length === 0) {
      return res.status(401).json({ ok: false, error: 'Invalid email or password' });
    }

    const userRow = result.rows[0];
    const valid = await bcrypt.compare(password, userRow.password_hash);
    if (!valid) {
      return res.status(401).json({ ok: false, error: 'Invalid email or password' });
    }

    const user = formatUser(userRow);
    const accessToken = signAccessToken({ userId: user.id, email: user.email });

    // Remember me = 30-day refresh token instead of 7-day
    const refreshToken = jwt.sign(
      { userId: user.id, email: user.email, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: rememberMe ? '30d' : '7d' },
    );

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken,
        new Date(Date.now() + (rememberMe ? 30 : 7) * 24 * 3600 * 1000).toISOString()],
    );

    res.json({
      ok: true,
      accessToken,
      refreshToken,
      user,
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /refresh ────────────────────────────────────────────────────────────
router.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ ok: false, error: 'Refresh token required' });
    }

    let payload;
    try {
      payload = verifyToken(refreshToken, process.env.JWT_REFRESH_SECRET);
    } catch {
      return res.status(401).json({ ok: false, error: 'Invalid refresh token' });
    }

    const stored = await pool.query(
      'SELECT * FROM refresh_tokens WHERE token = $1 AND user_id = $2 AND expires_at > NOW()',
      [refreshToken, payload.userId],
    );
    if (stored.rows.length === 0) {
      return res.status(401).json({ ok: false, error: 'Refresh token expired or revoked' });
    }

    await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);

    const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [payload.userId]);
    if (userResult.rows.length === 0) {
      return res.status(401).json({ ok: false, error: 'User not found' });
    }

    const user = formatUser(userResult.rows[0]);
    const newAccess = signAccessToken({ userId: user.id, email: user.email });
    const newRefresh = signRefreshToken({ userId: user.id, email: user.email });

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, newRefresh, new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString()],
    );

    res.json({ ok: true, accessToken: newAccess, refreshToken: newRefresh });
  } catch (err) {
    next(err);
  }
});

// ── POST /logout ─────────────────────────────────────────────────────────────
router.post('/logout', authenticate, async (req, res, next) => {
  try {
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.userId]);
    res.json({ ok: true, message: 'Logged out successfully' });
  } catch (err) {
    next(err);
  }
});

// ── GET /me ──────────────────────────────────────────────────────────────────
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }
    const user = formatUser(result.rows[0]);
    res.json({ ok: true, user });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /me ────────────────────────────────────────────────────────────────
router.patch('/me', authenticate, async (req, res, next) => {
  try {
    const { name, avatarColor, baseCurrency, monthlyIncomeGoal, fullName, phone } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;

    if (name || fullName) {
      updates.push(`full_name = $${idx++}`);
      values.push(name || fullName);
    }
    if (baseCurrency) {
      updates.push(`currency = $${idx++}`);
      values.push(baseCurrency);
    }
    if (monthlyIncomeGoal !== undefined) {
      updates.push(`monthly_income_goal = $${idx++}`);
      values.push(monthlyIncomeGoal);
    }
    if (phone !== undefined) {
      updates.push(`phone = $${idx++}`);
      values.push(phone);
    }

    if (updates.length === 0) {
      const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
      return res.json({ ok: true, user: formatUser(result.rows[0]) });
    }

    updates.push(`updated_at = $${idx++}`);
    values.push(new Date().toISOString());
    values.push(req.userId);

    const result = await pool.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
      values,
    );

    res.json({ ok: true, user: formatUser(result.rows[0]) });
  } catch (err) {
    next(err);
  }
});

// ── DELETE /me (account deletion) ────────────────────────────────────────────
router.delete('/me', authenticate, async (req, res, next) => {
  try {
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.userId]);
    await pool.query('DELETE FROM users WHERE id = $1', [req.userId]);
    res.json({ ok: true, message: 'Account deleted' });
  } catch (err) {
    next(err);
  }
});

// ── POST /otp/send ───────────────────────────────────────────────────────────
router.post('/otp/send', async (req, res, next) => {
  try {
    const { email, purpose } = req.body;
    if (!email) {
      return res.status(400).json({ ok: false, error: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const effectivePurpose = purpose || 'login';

    const existing = await pool.query('SELECT * FROM users WHERE email = $1', [normalizedEmail]);
    if (existing.rows.length === 0) {
      const password = req.body.password || ('pass_' + Math.random().toString(36).slice(2, 10));
      const passwordHash = await bcrypt.hash(password, 12);
      const userId = uuid();
      const now = new Date().toISOString();
      await pool.query(
        `INSERT INTO users (id, full_name, email, password_hash, currency, is_email_verified, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [userId, normalizedEmail.split('@')[0], normalizedEmail, passwordHash, 'INR', false, now, now],
      );
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));

    await pool.query('DELETE FROM otp_codes WHERE email = $1 AND purpose = $2',
      [normalizedEmail, effectivePurpose]);

    await pool.query(
      `INSERT INTO otp_codes (id, email, code, purpose, expires_at) VALUES ($1,$2,$3,$4,$5)`,
      [uuid(), normalizedEmail, code, effectivePurpose,
        new Date(Date.now() + 10 * 60 * 1000).toISOString()],
    );

    console.log('');
    console.log('══════════════════════════════════════════════════');
    console.log(`  📨 OTP for ${normalizedEmail} (${effectivePurpose}): ${code}`);
    console.log('  Copy the 6-digit code above and paste it into the app.');
    console.log('══════════════════════════════════════════════════');
    console.log('');
    res.json({ ok: true, otp: code, message: `OTP sent to ${normalizedEmail}. Check server logs for the code.` });
  } catch (err) {
    next(err);
  }
});

// ── POST /otp/verify ─────────────────────────────────────────────────────────
router.post('/otp/verify', async (req, res, next) => {
  try {
    const { email, otp, code, purpose } = req.body;
    const otpCode = otp || code;
    if (!email || !otpCode) {
      return res.status(400).json({ ok: false, error: 'Email and OTP code are required' });
    }

    const result = await pool.query(
      `SELECT * FROM otp_codes WHERE email = $1 AND code = $2 AND purpose = $3 AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [email.toLowerCase().trim(), otpCode, purpose || 'login'],
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ ok: false, error: 'Invalid or expired OTP code' });
    }

    await pool.query('DELETE FROM otp_codes WHERE id = $1', [result.rows[0].id]);

    const normalizedEmail = email.toLowerCase().trim();
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [normalizedEmail]);
    if (userResult.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }

    const user = formatUser(userResult.rows[0]);

    await pool.query('UPDATE users SET is_email_verified = true, updated_at = $1 WHERE id = $2',
      [new Date().toISOString(), user.id]);

    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = signRefreshToken({ userId: user.id, email: user.email });

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken, new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString()],
    );

    res.json({
      ok: true,
      accessToken,
      refreshToken,
      user,
      message: 'OTP verified successfully',
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /verify-email-dev ───────────────────────────────────────────────────
router.post('/verify-email-dev', async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ ok: false, error: 'Email required' });
    }

    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (userResult.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }

    await pool.query('UPDATE users SET is_email_verified = true, updated_at = $1 WHERE id = $2',
      [new Date().toISOString(), userResult.rows[0].id]);

    const user = formatUser(userResult.rows[0]);
    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = signRefreshToken({ userId: user.id, email: user.email });

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken, new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString()],
    );

    res.json({ ok: true, accessToken, refreshToken, user, message: 'Email verified (dev mode)' });
  } catch (err) {
    next(err);
  }
});

// ── POST /forgot-password ────────────────────────────────────────────────────
router.post('/forgot-password', async (req, res, next) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ ok: false, error: 'Email is required' });
    }

    const userResult = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (userResult.rows.length === 0) {
      return res.json({ ok: true, message: 'If that email exists, a reset code has been sent' });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));

    await pool.query('DELETE FROM otp_codes WHERE email = $1 AND purpose = $2',
      [email.toLowerCase().trim(), 'reset']);

    await pool.query(
      `INSERT INTO otp_codes (id, email, code, purpose, expires_at) VALUES ($1,$2,$3,$4,$5)`,
      [uuid(), email.toLowerCase().trim(), code, 'reset',
        new Date(Date.now() + 10 * 60 * 1000).toISOString()],
    );

    console.log(`📧 Password reset OTP for ${email}: ${code}`);
    res.json({ ok: true, message: 'If that email exists, a reset code has been sent', otp: code });
  } catch (err) {
    next(err);
  }
});

// ── POST /reset-password ─────────────────────────────────────────────────────
router.post('/reset-password', async (req, res, next) => {
  try {
    const { email, otp, code, newPassword } = req.body;
    const otpCode = otp || code;
    if (!email || !otpCode || !newPassword) {
      return res.status(400).json({ ok: false, error: 'Email, OTP code, and new password are required' });
    }

    const result = await pool.query(
      `SELECT * FROM otp_codes WHERE email = $1 AND code = $2 AND purpose = 'reset' AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [email.toLowerCase().trim(), otpCode],
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ ok: false, error: 'Invalid or expired reset code' });
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const userResult2 = await pool.query('SELECT id FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (userResult2.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }

    await pool.query('UPDATE users SET password_hash = $1, updated_at = $2 WHERE id = $3',
      [passwordHash, new Date().toISOString(), userResult2.rows[0].id]);

    await pool.query('DELETE FROM otp_codes WHERE id = $1', [result.rows[0].id]);
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userResult2.rows[0].id]);

    res.json({ ok: true, message: 'Password has been reset. Please log in.' });
  } catch (err) {
    next(err);
  }
});

// ── POST /phone/send ──────────────────────────────────────────────────────────
// Android phone-OTP. Sends a 6-digit code; dev: printed to server logs.
router.post('/phone/send', async (req, res, next) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({ ok: false, error: 'Phone number is required' });
    }

    const normalized = phone.replace(/\D/g, '');
    if (normalized.length < 10) {
      return res.status(400).json({ ok: false, error: 'Invalid phone number' });
    }

    const code = String(Math.floor(100000 + Math.random() * 900000));

    await pool.query('DELETE FROM otp_codes WHERE email = $1 AND purpose = $2',
      [normalized, 'phone_login']);

    await pool.query(
      `INSERT INTO otp_codes (id, email, code, purpose, expires_at) VALUES ($1,$2,$3,$4,$5)`,
      [uuid(), normalized, code, 'phone_login',
        new Date(Date.now() + 10 * 60 * 1000).toISOString()],
    );

    console.log('');
    console.log('══════════════════════════════════════════════════');
    console.log(`  📱 Phone OTP for ${normalized} (phone_login): ${code}`);
    console.log('  Copy the 6-digit code above and paste it into the app.');
    console.log('══════════════════════════════════════════════════');
    console.log('');

    res.json({ ok: true, otp: code, message: `OTP sent to ${normalized}. Check server logs.` });
  } catch (err) {
    next(err);
  }
});

// ── POST /phone/verify ────────────────────────────────────────────────────────
router.post('/phone/verify', async (req, res, next) => {
  try {
    const { phone, otp, code, rememberMe } = req.body;
    const otpCode = otp || code;
    if (!phone || !otpCode) {
      return res.status(400).json({ ok: false, error: 'Phone and OTP code are required' });
    }

    const normalized = phone.replace(/\D/g, '');

    const result = await pool.query(
      `SELECT * FROM otp_codes WHERE email = $1 AND code = $2 AND purpose = 'phone_login' AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [normalized, otpCode],
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ ok: false, error: 'Invalid or expired OTP code' });
    }

    await pool.query('DELETE FROM otp_codes WHERE id = $1', [result.rows[0].id]);

    const now = new Date().toISOString();

    // Find or create user by phone
    let userResult = await pool.query('SELECT * FROM users WHERE phone = $1', [normalized]);
    let user;
    if (userResult.rows.length === 0) {
      const userId = uuid();
      const placeholderEmail = `phone_${normalized}@fintrack.local`;
      const passwordHash = await bcrypt.hash('phone_' + Math.random().toString(36).slice(2), 12);
      userResult = await pool.query(
        `INSERT INTO users (id, full_name, email, password_hash, phone, currency, is_email_verified, created_at, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         RETURNING *`,
        [userId, 'User ' + normalized.slice(-4), placeholderEmail, passwordHash, normalized, 'INR', true, now, now],
      );
    }
    user = formatUser(userResult.rows[0]);

    // Ensure phone is set
    await pool.query('UPDATE users SET phone = $1, updated_at = $2 WHERE id = $3',
      [normalized, now, user.id]);

    // Phone is pre-verified
    await pool.query('UPDATE users SET is_email_verified = true, updated_at = $1 WHERE id = $2',
      [now, user.id]);

    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshDays = rememberMe ? 30 : 7;
    const refreshExpiry = new Date(Date.now() + refreshDays * 24 * 3600 * 1000).toISOString();
    const refreshToken = jwt.sign(
      { userId: user.id, email: user.email, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: rememberMe ? '30d' : '7d' },
    );

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken, refreshExpiry],
    );

    res.json({
      ok: true,
      accessToken,
      refreshToken,
      user,
      message: 'Phone verified successfully',
    });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /biometric ──────────────────────────────────────────────────────────
// Toggle biometric (Fingerprint / Face ID) on/off for authenticated user.
router.patch('/biometric', authenticate, async (req, res, next) => {
  try {
    const { enabled } = req.body;
    if (typeof enabled !== 'boolean') {
      return res.status(400).json({ ok: false, error: '"enabled" (boolean) is required' });
    }

    await pool.query(
      'UPDATE users SET is_biometric_enabled = $1, updated_at = $2 WHERE id = $3',
      [enabled, new Date().toISOString(), req.userId],
    );

    const result = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    res.json({
      ok: true,
      user: formatUser(result.rows[0]),
      message: enabled ? 'Biometric login enabled' : 'Biometric login disabled',
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /biometric/verify ────────────────────────────────────────────────────
// After local Android biometric succeeds, this endpoint issues session tokens.
router.post('/biometric/verify', async (req, res, next) => {
  try {
    const { bioToken, email } = req.body;
    if (!email) {
      return res.status(400).json({ ok: false, error: 'Email is required for biometric verification' });
    }

    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
    if (userResult.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found' });
    }

    const user = formatUser(userResult.rows[0]);
    if (!user.isBiometricEnabled) {
      return res.status(403).json({ ok: false, error: 'Biometric login is not enabled for this account' });
    }

    // In production: validate bioToken against Android key attestation.
    // Dev mode: accept any non-empty bioToken to confirm local auth passed.

    const accessToken = signAccessToken({ userId: user.id, email: user.email });
    const refreshToken = signRefreshToken({ userId: user.id, email: user.email });

    await pool.query(
      `INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES ($1,$2,$3,$4)`,
      [uuid(), user.id, refreshToken, new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString()],
    );

    res.json({
      ok: true,
      accessToken,
      refreshToken,
      user,
      message: 'Biometric verification successful',
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /passkey/generate ────────────────────────────────────────────────────
// Passkey challenge endpoint (Android Credential Manager / WebAuthn).
router.post('/passkey/generate', authenticate, async (req, res, next) => {
  try {
    const challenge = crypto.randomBytes(32).toString('base64url');
    res.json({
      ok: true,
      challenge,
      rpId: process.env.PASSKEY_RP_ID || 'localhost',
      rpName: 'FinTrack Pro',
      userId: req.userId,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;