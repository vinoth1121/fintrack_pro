const { Router } = require('express');
const { z } = require('zod');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = Router();
router.use(authenticate);

const createSubSchema = z.object({
  name: z.string().min(1).max(255),
  amount: z.number().min(0),
  currency: z.string().length(3).default('USD'),
  billingCycle: z.preprocess(
    (v) => (typeof v === 'string' ? v.toUpperCase() : v),
    z.enum(['WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY']).default('MONTHLY'),
  ),
  nextBillingDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  categoryId: z.string().uuid().optional(),
  notes: z.string().optional(),
  logoUrl: z.string().optional(),
});

const subRowToJson = (row) => ({
  id: row.id,
  name: row.name,
  amount: parseFloat(row.amount),
  currency: row.currency,
  billingCycle: row.billing_cycle,
  nextBillingDate: row.next_billing_date instanceof Date ? row.next_billing_date.toISOString().split('T')[0] : String(row.next_billing_date).split('T')[0],
  category: row.category_id ? { id: row.category_id, name: row.category_name, icon: row.category_icon, color: row.category_color } : null,
  notes: row.notes,
  isActive: row.is_active,
  logoUrl: row.logo_url,
  createdAt: row.created_at?.toISOString?.() ?? row.created_at,
});

// GET /api/subscriptions
router.get('/', async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT s.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
       FROM subscriptions s LEFT JOIN categories c ON s.category_id = c.id
       WHERE s.user_id = $1 ORDER BY s.is_active DESC, s.next_billing_date ASC`,
      [req.userId],
    );
    res.json({ ok: true, items: rows.map(subRowToJson) });
  } catch (err) {
    console.error('GET /subscriptions error:', err);
    res.status(500).json({ message: 'Failed to fetch subscriptions.' });
  }
});

// POST /api/subscriptions
router.post('/', validate(createSubSchema), async (req, res) => {
  try {
    const d = req.body;
    const nextDate = d.nextBillingDate.includes('T') ? d.nextBillingDate.split('T')[0] : d.nextBillingDate;

    const { rows } = await pool.query(
      `INSERT INTO subscriptions (user_id, name, amount, currency, billing_cycle, next_billing_date, category_id, notes, logo_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [req.userId, d.name, d.amount, d.currency, d.billingCycle, nextDate, d.categoryId || null, d.notes || null, d.logoUrl || null],
    );

    const full = await pool.query(
      `SELECT s.*, c.name AS category_name, c.icon AS category_icon, c.color AS category_color
       FROM subscriptions s LEFT JOIN categories c ON s.category_id = c.id WHERE s.id = $1`,
      [rows[0].id],
    );
    res.status(201).json(subRowToJson(full.rows[0]));
  } catch (err) {
    console.error('POST /subscriptions error:', err);
    res.status(500).json({ message: 'Failed to create subscription.' });
  }
});

// DELETE /api/subscriptions/:id
router.delete('/:id', async (req, res) => {
  try {
    const r = await pool.query('DELETE FROM subscriptions WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.userId]);
    if (r.rows.length === 0) return res.status(404).json({ message: 'Subscription not found.' });
    res.status(204).send();
  } catch (err) {
    console.error('DELETE /subscriptions/:id error:', err);
    res.status(500).json({ message: 'Failed to delete subscription.' });
  }
});

module.exports = router;