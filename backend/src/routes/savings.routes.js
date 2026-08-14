const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();

router.use(authenticate);

// ── Helper ──────────────────────────────────────────────────────────────────
function formatSavings(row) {
  const targetAmount = parseFloat(row.target_amount ?? row.target ?? 0);
  const savedAmount = parseFloat(row.saved_amount ?? row.saved ?? 0);

  let status = row.status || 'ACTIVE';
  if (targetAmount > 0 && savedAmount >= targetAmount) status = 'COMPLETED';

  return {
    id: row.id,
    name: row.name,
    targetAmount,
    savedAmount,
    currency: row.currency || 'INR',
    deadline: row.deadline ? (row.deadline?.toISOString?.() ?? row.deadline) : null,
    icon: row.icon,
    color: row.color,
    status,
    notes: row.notes,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    target: targetAmount,
    saved: savedAmount,
  };
}

// ── GET / ────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const result = await pool.query(
      'SELECT * FROM savings_goals WHERE user_id = $1 ORDER BY created_at DESC',
      [req.userId],
    );
    const goals = result.rows.map(formatSavings);
    res.json({ ok: true, items: goals });
  } catch (err) { next(err); }
});

// ── POST / ───────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const { name, targetAmount, target, savedAmount, saved, currency, deadline, icon, color, notes } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const ta = targetAmount ?? target ?? 0;
    const sa = savedAmount ?? saved ?? 0;

    const result = await pool.query(
      `INSERT INTO savings_goals (id, user_id, name, target_amount, saved_amount, currency, deadline, icon, color, notes, status, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
      [id, req.userId, name, ta, sa, currency || 'INR', deadline || null, icon || null, color || null, notes || null, ta > 0 && sa >= ta ? 'COMPLETED' : 'ACTIVE', now, now],
    );
    res.status(201).json(formatSavings(result.rows[0]));
  } catch (err) { next(err); }
});

// ── PATCH /:id ───────────────────────────────────────────────────────────────
router.patch('/:id', async (req, res, next) => {
  try {
    const { name, targetAmount, target, savedAmount, saved, deadline, icon, color, notes } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;

    if (name !== undefined) { updates.push(`name = $${idx++}`); values.push(name); }
    if (targetAmount !== undefined || target !== undefined) { updates.push(`target_amount = $${idx++}`); values.push(targetAmount ?? target); }
    if (savedAmount !== undefined || saved !== undefined) { updates.push(`saved_amount = $${idx++}`); values.push(savedAmount ?? saved); }
    if (deadline !== undefined) { updates.push(`deadline = $${idx++}`); values.push(deadline); }
    if (icon !== undefined) { updates.push(`icon = $${idx++}`); values.push(icon); }
    if (color !== undefined) { updates.push(`color = $${idx++}`); values.push(color); }
    if (notes !== undefined) { updates.push(`notes = $${idx++}`); values.push(notes); }

    if (updates.length === 0) return res.status(400).json({ ok: false, error: 'No fields to update' });

    updates.push(`updated_at = $${idx++}`);
    values.push(new Date().toISOString());
    values.push(req.params.id, req.userId);

    const result = await pool.query(
      `UPDATE savings_goals SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`,
      values,
    );
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Goal not found' });
    res.json(formatSavings(result.rows[0]));
  } catch (err) { next(err); }
});

// ── DELETE /:id ──────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query('DELETE FROM savings_goals WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Goal not found' });
    res.json({ ok: true, message: 'Goal deleted' });
  } catch (err) { next(err); }
});

// ── POST /:goalId/contribute ─────────────────────────────────────────────────
router.post('/:goalId/contribute', async (req, res, next) => {
  try {
    const { amount, notes } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ ok: false, error: 'Valid amount required' });

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        'UPDATE savings_goals SET saved_amount = saved_amount + $1, updated_at = $2 WHERE id = $3 AND user_id = $4 RETURNING *',
        [amount, new Date().toISOString(), req.params.goalId, req.userId],
      );
      if (result.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ ok: false, error: 'Goal not found' });
      }
      await client.query(
        `INSERT INTO savings_contributions (id, goal_id, user_id, amount, notes, created_at) VALUES ($1,$2,$3,$4,$5,$6)`,
        [uuid(), req.params.goalId, req.userId, amount, notes || null, new Date().toISOString()],
      );
      await client.query('COMMIT');
      res.json(formatSavings(result.rows[0]));
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) { next(err); }
});

module.exports = router;