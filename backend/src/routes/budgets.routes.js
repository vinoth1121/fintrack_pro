const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();
router.use(authenticate);

function formatBudget(row) {
  return {
    id: row.id,
    categoryId: row.category_id,
    limit: parseFloat(row.amount ?? row.limit_val ?? 0),
    amount: parseFloat(row.amount ?? row.limit_val ?? 0),
    period: row.period || 'monthly',
    rollover: row.rollover || false,
    startDate: row.start_date?.toISOString?.() ?? row.start_date,
    endDate: row.end_date?.toISOString?.() ?? row.end_date,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
  };
}

router.get('/', async (req, res, next) => {
  try {
    const result = await pool.query('SELECT * FROM budgets WHERE user_id = $1 ORDER BY created_at DESC', [req.userId]);
    res.json({ ok: true, items: result.rows.map(formatBudget) });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
  const { categoryId, limit, amount, period, name: budgetName, startDate, endDate } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const limitVal = limit ?? amount ?? 0;
    const result = await pool.query(
      `INSERT INTO budgets (id, user_id, name, category_id, amount, spent, period, start_date, end_date, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [id, req.userId, budgetName || (period || 'monthly') + ' budget', categoryId || null, limitVal, 0, period || 'monthly', startDate || now, endDate || null, now, now],
    );
    res.status(201).json(formatBudget(result.rows[0]));
  } catch (err) { next(err); }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { categoryId, limit, amount, period, rollover, startDate, endDate } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;
    if (categoryId !== undefined) { updates.push(`category_id = $${idx++}`); values.push(categoryId); }
    if (limit !== undefined || amount !== undefined) { updates.push(`amount = $${idx++}`); values.push(limit ?? amount); }
    if (period !== undefined) { updates.push(`period = $${idx++}`); values.push(period); }
    if (updates.length === 0) return res.status(400).json({ ok: false, error: 'No fields to update' });
    updates.push(`updated_at = $${idx++}`); values.push(new Date().toISOString());
    values.push(req.params.id, req.userId);
    const result = await pool.query(`UPDATE budgets SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`, values);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Budget not found' });
    res.json(formatBudget(result.rows[0]));
  } catch (err) { next(err); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query('DELETE FROM budgets WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Budget not found' });
    res.json({ ok: true, message: 'Budget deleted' });
  } catch (err) { next(err); }
});

module.exports = router;