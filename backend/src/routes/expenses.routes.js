const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();

// All routes require authentication
router.use(authenticate);

// ── Helper: format expense with nested category ──────────────────────────────
function formatExpense(row, catRow) {
  return {
    id: row.id,
    title: row.title || row.notes || 'Untitled',
    amount: parseFloat(row.amount),
    currency: row.currency || 'INR',
    date: row.date?.toISOString?.() ?? row.date,
    category: catRow ? {
      id: catRow.id,
      name: catRow.name,
      icon: catRow.icon,
      color: catRow.color,
      isDefault: catRow.is_default || false,
    } : null,
    notes: row.notes,
    receiptUrl: row.receipt_url,
    isRecurring: row.is_recurring || false,
    tags: row.tags || [],
    paymentMethod: row.payment_method,
    location: row.location,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
  };
}

// ── GET / (paginated list) ───────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 20));
    const offset = (page - 1) * limit;
    const { categoryId, startDate, endDate, search } = req.query;

    let where = 'WHERE e.user_id = $1';
    const params = [req.userId];
    let idx = 2;

    if (categoryId) {
      where += ` AND e.category_id = $${idx++}`;
      params.push(categoryId);
    }
    if (startDate) {
      where += ` AND e.date >= $${idx++}`;
      params.push(startDate);
    }
    if (endDate) {
      where += ` AND e.date <= $${idx++}`;
      params.push(endDate);
    }
    if (search) {
      where += ` AND (e.title ILIKE $${idx} OR e.notes ILIKE $${idx})`;
      params.push(`%${search}%`);
      idx++;
    }

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM expenses e ${where}`,
      params,
    );
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.ceil(total / limit);

    params.push(limit, offset);
    const result = await pool.query(
      `SELECT e.*, c.id AS cat_id, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color, c.is_default AS cat_is_default
       FROM expenses e
       LEFT JOIN categories c ON e.category_id = c.id
       ${where}
       ORDER BY e.date DESC, e.created_at DESC
       LIMIT $${idx++} OFFSET $${idx}`,
      params,
    );

    const items = result.rows.map(r => formatExpense(r, r.cat_id ? {
      id: r.cat_id, name: r.cat_name, icon: r.cat_icon, color: r.cat_color, is_default: r.cat_is_default,
    } : null));

    res.json({
      ok: true,
      items,
      pagination: { page, totalPages, total },
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /:id ─────────────────────────────────────────────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT e.*, c.id AS cat_id, c.name AS cat_name, c.icon AS cat_icon, c.color AS cat_color, c.is_default AS cat_is_default
       FROM expenses e
       LEFT JOIN categories c ON e.category_id = c.id
       WHERE e.id = $1 AND e.user_id = $2`,
      [req.params.id, req.userId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Expense not found' });
    }
    const r = result.rows[0];
    res.json(formatExpense(r, r.cat_id ? {
      id: r.cat_id, name: r.cat_name, icon: r.cat_icon, color: r.cat_color, is_default: r.cat_is_default,
    } : null));
  } catch (err) {
    next(err);
  }
});

// ── POST / ───────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const { title, amount, currency, date, categoryId, notes, receiptUrl, isRecurring, tags, paymentMethod, location } = req.body;
    const now = new Date().toISOString();
    const id = uuid();

    const result = await pool.query(
      `INSERT INTO expenses (id, user_id, title, amount, currency, date, category_id, notes, receipt_url, is_recurring, tags, payment_method, location, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       RETURNING *`,
      [
        id, req.userId,
        title || notes || 'Untitled',
        amount, currency || 'INR',
        date || now,
        categoryId || null,
        notes || null,
        receiptUrl || null,
        isRecurring || false,
        tags ? (Array.isArray(tags) ? tags : [tags]) : [],
        paymentMethod || null,
        location || null,
        now, now,
      ],
    );

    // Fetch category if present
    let catRow = null;
    if (result.rows[0].category_id) {
      const cat = await pool.query('SELECT * FROM categories WHERE id = $1', [result.rows[0].category_id]);
      if (cat.rows.length > 0) catRow = cat.rows[0];
    }

    res.status(201).json(formatExpense(result.rows[0], catRow));
  } catch (err) {
    next(err);
  }
});

// ── PATCH /:id ───────────────────────────────────────────────────────────────
router.patch('/:id', async (req, res, next) => {
  try {
    const { title, amount, currency, date, categoryId, notes, receiptUrl, isRecurring, tags, paymentMethod, location } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;

    if (title !== undefined) { updates.push(`title = $${idx++}`); values.push(title); }
    if (amount !== undefined) { updates.push(`amount = $${idx++}`); values.push(amount); }
    if (currency !== undefined) { updates.push(`currency = $${idx++}`); values.push(currency); }
    if (date !== undefined) { updates.push(`date = $${idx++}`); values.push(date); }
    if (categoryId !== undefined) { updates.push(`category_id = $${idx++}`); values.push(categoryId); }
    if (notes !== undefined) { updates.push(`notes = $${idx++}`); values.push(notes); }
    if (receiptUrl !== undefined) { updates.push(`receipt_url = $${idx++}`); values.push(receiptUrl); }
    if (isRecurring !== undefined) { updates.push(`is_recurring = $${idx++}`); values.push(isRecurring); }
    if (tags !== undefined) { updates.push(`tags = $${idx++}`); values.push(Array.isArray(tags) ? tags : [tags]); }
    if (paymentMethod !== undefined) { updates.push(`payment_method = $${idx++}`); values.push(paymentMethod); }
    if (location !== undefined) { updates.push(`location = $${idx++}`); values.push(location); }

    if (updates.length === 0) {
      return res.status(400).json({ ok: false, error: 'No fields to update' });
    }

    updates.push(`updated_at = $${idx++}`);
    values.push(new Date().toISOString());
    values.push(req.params.id, req.userId);

    const result = await pool.query(
      `UPDATE expenses SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`,
      values,
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Expense not found' });
    }

    let catRow = null;
    if (result.rows[0].category_id) {
      const cat = await pool.query('SELECT * FROM categories WHERE id = $1', [result.rows[0].category_id]);
      if (cat.rows.length > 0) catRow = cat.rows[0];
    }

    res.json(formatExpense(result.rows[0], catRow));
  } catch (err) {
    next(err);
  }
});

// ── DELETE /:id ──────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query(
      'DELETE FROM expenses WHERE id = $1 AND user_id = $2 RETURNING id',
      [req.params.id, req.userId],
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ ok: false, error: 'Expense not found' });
    }
    res.json({ ok: true, message: 'Expense deleted' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;