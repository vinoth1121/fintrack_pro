const { Router } = require('express');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();

router.use(authenticate);

// ── GET /api/exports/transactions/csv ────────────────────────────────────────
router.get('/transactions/csv', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    let query = `SELECT tv.*, c.name as category_name, c.type as category_type
                 FROM transactions_view tv
                 LEFT JOIN categories c ON c.id = tv.category_id
                 WHERE tv.user_id = $1`;
    const params = [req.userId];

    if (startDate) {
      params.push(startDate);
      query += ` AND tv.date >= $${params.length}`;
    }
    if (endDate) {
      params.push(endDate);
      query += ` AND tv.date <= $${params.length}`;
    }
    query += ' ORDER BY tv.date DESC';

    const result = await pool.query(query, params);

    // Build CSV
    const header = 'Type,Date,Category,Description,Amount,Currency,Note,Shared\n';
    const rows = result.rows.map(r =>
      `${r.type || ''},${r.date || ''},"${(r.category_name || '').replace(/"/g, '""')}","${(r.description || '').replace(/"/g, '""')}",${r.amount || 0},${r.currency || 'INR'},"${(r.note || '').replace(/"/g, '""')}",${r.shared_with_family ? 'Yes' : 'No'}`
    ).join('\n');

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="fintrack_export_${new Date().toISOString().split('T')[0]}.csv"`);
    res.send(header + rows);
  } catch (err) { next(err); }
});

// ── GET /api/exports/transactions/json ───────────────────────────────────────
router.get('/transactions/json', async (req, res, next) => {
  try {
    const [expenses, income] = await Promise.all([
      pool.query(
        `SELECT e.*, c.name as category_name
         FROM expenses e
         LEFT JOIN categories c ON c.id = e.category_id
         WHERE e.user_id = $1
         ORDER BY e.date DESC`,
        [req.userId],
      ),
      pool.query(
        `SELECT i.*, c.name as category_name
         FROM income i
         LEFT JOIN categories c ON c.id = i.category_id
         WHERE i.user_id = $1
         ORDER BY i.date DESC`,
        [req.userId],
      ),
    ]);

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="fintrack_export_${new Date().toISOString().split('T')[0]}.json"`);
    res.json({
      ok: true,
      expenses: expenses.rows,
      income: income.rows,
      exportedAt: new Date().toISOString(),
    });
  } catch (err) { next(err); }
});

// ── GET /api/exports/summary ─────────────────────────────────────────────────
router.get('/summary', async (req, res, next) => {
  try {
    const period = req.query.period || 'monthly'; // monthly, weekly, yearly
    const interval = period === 'weekly' ? '7 days' : period === 'yearly' ? '365 days' : '30 days';

    const [expSummary, incSummary, expenseByCat, incomeByCat] = await Promise.all([
      pool.query(
        `SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count
         FROM expenses WHERE user_id = $1 AND date >= NOW() - INTERVAL '${interval}'`,
        [req.userId],
      ),
      pool.query(
        `SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count
         FROM income WHERE user_id = $1 AND date >= NOW() - INTERVAL '${interval}'`,
        [req.userId],
      ),
      pool.query(
        `SELECT c.name as category, COALESCE(SUM(e.amount), 0) as total
         FROM expenses e
         LEFT JOIN categories c ON c.id = e.category_id
         WHERE e.user_id = $1 AND e.date >= NOW() - INTERVAL '${interval}'
         GROUP BY c.name ORDER BY total DESC`,
        [req.userId],
      ),
      pool.query(
        `SELECT c.name as category, COALESCE(SUM(i.amount), 0) as total
         FROM income i
         LEFT JOIN categories c ON c.id = i.category_id
         WHERE i.user_id = $1 AND i.date >= NOW() - INTERVAL '${interval}'
         GROUP BY c.name ORDER BY total DESC`,
        [req.userId],
      ),
    ]);

    res.json({
      ok: true,
      period,
      summary: {
        totalExpense: parseFloat(expSummary.rows[0]?.total || 0),
        totalIncome: parseFloat(incSummary.rows[0]?.total || 0),
        expenseCount: parseInt(expSummary.rows[0]?.count || 0, 10),
        incomeCount: parseInt(incSummary.rows[0]?.count || 0, 10),
        expensesByCategory: expenseByCat.rows,
        incomeByCategory: incomeByCat.rows,
      },
      exportedAt: new Date().toISOString(),
    });
  } catch (err) { next(err); }
});

// ── GET /api/exports/all ─────────────────────────────────────────────────────
router.get('/all', async (req, res, next) => {
  try {
    const [expenses, income, budgets, goals, subs] = await Promise.all([
      pool.query('SELECT * FROM expenses WHERE user_id = $1 ORDER BY date DESC', [req.userId]),
      pool.query('SELECT * FROM income WHERE user_id = $1 ORDER BY date DESC', [req.userId]),
      pool.query('SELECT * FROM budgets WHERE user_id = $1', [req.userId]),
      pool.query('SELECT * FROM savings_goals WHERE user_id = $1', [req.userId]),
      pool.query('SELECT * FROM subscriptions WHERE user_id = $1', [req.userId]),
    ]);

    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', 'attachment; filename=fintrack_full_export.json');
    res.json({
      ok: true,
      expenses: expenses.rows,
      income: income.rows,
      budgets: budgets.rows,
      goals: goals.rows,
      subscriptions: subs.rows,
      exportedAt: new Date().toISOString(),
    });
  } catch (err) { next(err); }
});

module.exports = router;