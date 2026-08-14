const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();

router.use(authenticate);

// Validate categoryId belongs to user; return null if absent/invalid so we
// don't trigger a 500 FK violation when clients send stale/wrong ids.
async function resolveCategoryId(categoryId, userId) {
  if (!categoryId) return null;
  try {
    const { rows } = await pool.query(
      'SELECT id FROM categories WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)',
      [categoryId, userId],
    );
    return rows.length > 0 ? categoryId : null;
  } catch {
    return null;
  }
}

// ── Helper ──────────────────────────────────────────────────────────────────
function formatIncome(row, catRow) {
  return {
    id: row.id,
    title: row.title || row.source || 'Income',
    amount: parseFloat(row.amount),
    currency: row.currency || 'INR',
    date: row.date?.toISOString?.() ?? row.date,
    category: catRow ? {
      id: catRow.id, name: catRow.name, icon: catRow.icon, color: catRow.color, isDefault: catRow.is_default || false,
    } : null,
    source: row.source,
    note: row.notes,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
  };
}

// ── GET / (paginated) ─────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;
    const { startDate, endDate } = req.query;

    let where = 'WHERE i.user_id = $1';
    const params = [req.userId];
    let idx = 2;

    if (startDate) { where += ` AND i.date >= $${idx++}`; params.push(startDate); }
    if (endDate) { where += ` AND i.date <= $${idx++}`; params.push(endDate); }

    const countResult = await pool.query(`SELECT COUNT(*) FROM income i ${where}`, params);
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.ceil(total / limit);

    params.push(limit, offset);
    const result = await pool.query(
      `SELECT i.*, c.id AS cat_id, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color, c.is_default AS cat_is_default
       FROM income i LEFT JOIN categories c ON i.category_id = c.id
       ${where} ORDER BY i.date DESC, i.created_at DESC LIMIT $${idx++} OFFSET $${idx}`,
      params,
    );

    const items = result.rows.map(r => formatIncome(r, r.cat_id ? {
      id: r.cat_id, name: r.cat_name, icon: r.cat_icon, color: r.cat_color, is_default: r.cat_is_default,
    } : null));

    res.json({ ok: true, items, pagination: { page, totalPages, total } });
  } catch (err) { next(err); }
});

// ── POST / ───────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const { title, amount, currency, date, categoryId, source, notes } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const validCategoryId = await resolveCategoryId(categoryId, req.userId);

    const result = await pool.query(
      `INSERT INTO income (id, user_id, title, amount, currency, date, category_id, source, notes, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
      [id, req.userId, title || source || 'Income', amount, currency || 'INR', date || now, validCategoryId, source || null, notes || null, now, now],
    );

    let catRow = null;
    if (result.rows[0].category_id) {
      const cat = await pool.query('SELECT * FROM categories WHERE id = $1', [result.rows[0].category_id]);
      if (cat.rows.length > 0) catRow = cat.rows[0];
    }

    res.status(201).json(formatIncome(result.rows[0], catRow));
  } catch (err) { next(err); }
});

// ── PATCH /:id ───────────────────────────────────────────────────────────────
router.patch('/:id', async (req, res, next) => {
  try {
    const { title, amount, currency, date, categoryId, source, notes } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;

    if (title !== undefined) { updates.push(`title = $${idx++}`); values.push(title); }
    if (amount !== undefined) { updates.push(`amount = $${idx++}`); values.push(amount); }
    if (currency !== undefined) { updates.push(`currency = $${idx++}`); values.push(currency); }
    if (date !== undefined) { updates.push(`date = $${idx++}`); values.push(date); }
    if (categoryId !== undefined) {
      const v = await resolveCategoryId(categoryId, req.userId);
      updates.push(`category_id = $${idx++}`);
      values.push(v);
    }
    if (source !== undefined) { updates.push(`source = $${idx++}`); values.push(source); }
    if (notes !== undefined) { updates.push(`notes = $${idx++}`); values.push(notes); }

    if (updates.length === 0) return res.status(400).json({ ok: false, error: 'No fields to update' });

    updates.push(`updated_at = $${idx++}`);
    values.push(new Date().toISOString());
    values.push(req.params.id, req.userId);

    const result = await pool.query(
      `UPDATE income SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`,
      values,
    );
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Income not found' });

    let catRow = null;
    if (result.rows[0].category_id) {
      const cat = await pool.query('SELECT * FROM categories WHERE id = $1', [result.rows[0].category_id]);
      if (cat.rows.length > 0) catRow = cat.rows[0];
    }
    res.json(formatIncome(result.rows[0], catRow));
  } catch (err) { next(err); }
});

// ── DELETE /:id ──────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query('DELETE FROM income WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Income not found' });
    res.json({ ok: true, message: 'Income deleted' });
  } catch (err) { next(err); }
});

module.exports = router;