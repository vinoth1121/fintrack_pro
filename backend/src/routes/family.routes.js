const { Router } = require('express');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();

// All family routes require auth
router.use(authenticate);

// ── GET /api/family/members ─────────────────────────────────────────────────
router.get('/members', async (req, res, next) => {
  try {
    const result = await pool.query(
       `SELECT fm.*, u.email, u.full_name as member_name
        FROM family_members fm
        JOIN users u ON u.id = fm.member_id
        WHERE fm.user_id = $1
        ORDER BY fm.created_at DESC`,
      [req.userId],
    );
    res.json({ ok: true, members: result.rows });
  } catch (err) { next(err); }
});

// ── POST /api/family/members ─────────────────────────────────────────────────
router.post('/members', async (req, res, next) => {
  try {
    const { email, role } = req.body;

    // Find the user by email
    const userResult = await pool.query('SELECT id, full_name as name, email FROM users WHERE email = $1', [email]);
    if (userResult.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'User not found with this email' });
    }

    const memberId = userResult.rows[0].id;
    if (memberId === req.userId) {
      return res.status(400).json({ ok: false, error: 'Cannot add yourself as a family member' });
    }

    // Check if already a member
    const existing = await pool.query(
      'SELECT id FROM family_members WHERE user_id = $1 AND member_id = $2',
      [req.userId, memberId],
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ ok: false, error: 'Member already added' });
    }

    const result = await pool.query(
      `INSERT INTO family_members (user_id, member_id, role) VALUES ($1, $2, $3) RETURNING *`,
      [req.userId, memberId, role || 'family'],
    );

    res.status(201).json({
      ok: true,
      member: {
        ...result.rows[0],
        name: userResult.rows[0].name,
        email: userResult.rows[0].email,
      },
    });
  } catch (err) { next(err); }
});

// ── PATCH /api/family/members/:id ────────────────────────────────────────────
router.patch('/members/:id', async (req, res, next) => {
  try {
    const { role } = req.body;
    const result = await pool.query(
      'UPDATE family_members SET role = $1 WHERE id = $2 AND user_id = $3 RETURNING *',
      [role, req.params.id, req.userId],
    );
    if (result.rows.length === 0)
      return res.status(404).json({ ok: false, error: 'Member not found' });

    res.json({ ok: true, member: result.rows[0] });
  } catch (err) { next(err); }
});

// ── DELETE /api/family/members/:id ───────────────────────────────────────────
router.delete('/members/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      'DELETE FROM family_members WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.userId],
    );
    if (result.rows.length === 0)
      return res.status(404).json({ ok: false, error: 'Member not found' });

    res.json({ ok: true, message: 'Member removed' });
  } catch (err) { next(err); }
});

// ── GET /api/family/overview ─────────────────────────────────────────────────
router.get('/overview', async (req, res, next) => {
  try {
    const members = await pool.query(
       `SELECT fm.*, u.full_name as name, u.email
        FROM family_members fm
        JOIN users u ON u.id = fm.member_id
        WHERE fm.user_id = $1`,
      [req.userId],
    );

    // Use the unified transactions_view for shared transactions
    const sharedTx = await pool.query(
      `SELECT tv.*, c.name as category_name
       FROM transactions_view tv
       LEFT JOIN categories c ON c.id = tv.category_id
       WHERE tv.user_id = $1 AND tv.shared_with_family = true
       ORDER BY tv.date DESC LIMIT 20`,
      [req.userId],
    );

    res.json({
      ok: true,
      members: members.rows,
      sharedTransactions: sharedTx.rows,
    });
  } catch (err) { next(err); }
});

module.exports = router;