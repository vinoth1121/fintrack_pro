const { Router } = require('express');
const { z } = require('zod');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = Router();
router.use(authenticate);

const createAccountSchema = z.object({
  name: z.string().min(1).max(255),
  type: z.enum(['checking', 'savings', 'credit', 'investment', 'cash']).default('checking'),
  balance: z.number().default(0),
  currency: z.string().length(3).default('USD'),
  institution: z.string().optional(),
  accountNumberMasked: z.string().optional(),
  color: z.string().optional(),
  icon: z.string().optional(),
});

const accountToJson = (row) => ({
  id: row.id,
  name: row.name,
  type: row.type,
  balance: parseFloat(row.balance),
  currency: row.currency,
  institution: row.institution,
  accountNumberMasked: row.account_number_masked,
  color: row.color,
  icon: row.icon,
  isActive: row.is_active,
  createdAt: row.created_at?.toISOString?.() ?? row.created_at,
});

router.get('/', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM accounts WHERE user_id = $1 ORDER BY is_active DESC, name ASC',
    [req.userId],
  );
  res.json(rows.map(accountToJson));
});

router.get('/:id', async (req, res) => {
  const { rows } = await pool.query(
    'SELECT * FROM accounts WHERE id = $1 AND user_id = $2',
    [req.params.id, req.userId],
  );
  if (rows.length === 0) return res.status(404).json({ message: 'Account not found.' });
  res.json(accountToJson(rows[0]));
});

router.post('/', validate(createAccountSchema), async (req, res) => {
  const d = req.body;
  const { rows } = await pool.query(
    `INSERT INTO accounts (user_id, name, type, balance, currency, institution, account_number_masked, color, icon)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
    [req.userId, d.name, d.type, d.balance, d.currency, d.institution || null, d.accountNumberMasked || null, d.color || null, d.icon || null],
  );
  res.status(201).json(accountToJson(rows[0]));
});

router.patch('/:id', async (req, res) => {
  const ex = await pool.query('SELECT id FROM accounts WHERE id=$1 AND user_id=$2', [req.params.id, req.userId]);
  if (ex.rows.length === 0) return res.status(404).json({ message: 'Account not found.' });

  const d = req.body;
  const map = { name: 'name', type: 'type', balance: 'balance', currency: 'currency', institution: 'institution', accountNumberMasked: 'account_number_masked', color: 'color', icon: 'icon', isActive: 'is_active' };
  const sets = [];
  const params = [];
  let idx = 1;
  for (const [k, v] of Object.entries(d)) {
    if (map[k] && v !== undefined) { sets.push(`${map[k]}=$${idx++}`); params.push(v); }
  }
  if (!sets.length) return res.status(400).json({ message: 'No fields.' });
  sets.push('updated_at=NOW()');
  params.push(req.params.id, req.userId);
  const { rows } = await pool.query(`UPDATE accounts SET ${sets.join(',')} WHERE id=$${idx++} AND user_id=$${idx++} RETURNING *`, params);
  res.json(accountToJson(rows[0]));
});

router.delete('/:id', async (req, res) => {
  const r = await pool.query('DELETE FROM accounts WHERE id=$1 AND user_id=$2 RETURNING id', [req.params.id, req.userId]);
  if (!r.rows.length) return res.status(404).json({ message: 'Account not found.' });
  res.status(204).send();
});

module.exports = router;