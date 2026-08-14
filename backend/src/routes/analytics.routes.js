const { Router } = require('express');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();
router.use(authenticate);

router.get('/category-breakdown', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const now = new Date();
    const start = startDate || new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const end = endDate || now.toISOString().split('T')[0];

    const exp = await pool.query(
      `SELECT c.id, c.name, c.icon, c.color, SUM(e.amount) AS total, COUNT(*) AS count
       FROM expenses e LEFT JOIN categories c ON e.category_id = c.id
       WHERE e.user_id = $1 AND e.date >= $2 AND e.date <= $3
       GROUP BY c.id, c.name, c.icon, c.color ORDER BY total DESC`,
      [req.userId, start, end],
    );

    const tr = await pool.query('SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE user_id=$1 AND date>=$2 AND date<=$3', [req.userId, start, end]);
    const total = parseFloat(tr.rows[0].total);

    res.json({
      ok: true,
      categories: exp.rows.map(r => ({
        id: r.id, name: r.name||'Uncategorized', icon: r.icon||'category', color: r.color||'#999',
        amount: parseFloat(r.total), count: parseInt(r.count,10),
        percentage: total>0 ? parseFloat(((parseFloat(r.total)/total)*100).toFixed(1)) : 0,
      })),
      totalExpenses: total,
      period: { start, end },
    });
  } catch (err) { next(err); }
});

router.get('/monthly-trend', async (req, res, next) => {
  try {
    const n = Math.min(24, Math.max(1, parseInt(req.query.months,10)||12));
    const exp = await pool.query(`SELECT DATE_TRUNC('month',date)::DATE AS month, SUM(amount) AS total FROM expenses WHERE user_id=$1 AND date>=DATE_TRUNC('month',NOW())-INTERVAL '${n} months' GROUP BY month ORDER BY month`, [req.userId]);
    const inc = await pool.query(`SELECT DATE_TRUNC('month',date)::DATE AS month, SUM(amount) AS total FROM income WHERE user_id=$1 AND date>=DATE_TRUNC('month',NOW())-INTERVAL '${n} months' GROUP BY month ORDER BY month`, [req.userId]);

    const em = {}; exp.rows.forEach(r => { em[r.month?.toISOString?.()?.substring(0,7)??r.month] = parseFloat(r.total); });
    const im = {}; inc.rows.forEach(r => { im[r.month?.toISOString?.()?.substring(0,7)??r.month] = parseFloat(r.total); });

    const data = [];
    for (let i=n-1; i>=0; i--) {
      const d = new Date(); d.setDate(1); d.setMonth(d.getMonth()-i);
      const k = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
      data.push({ month: k, expense: em[k]||0, income: im[k]||0, savings: (im[k]||0)-(em[k]||0) });
    }
    res.json({ ok: true, data });
  } catch (err) { next(err); }
});

router.get('/total-spent', async (req, res, next) => {
  try {
    let w = 'WHERE user_id=$1';
    const p = req.query.period;
    if (p==='today') w += " AND date=CURRENT_DATE";
    else if (p==='week') w += " AND date>=DATE_TRUNC('week',CURRENT_DATE)";
    else if (p==='month') w += " AND date>=DATE_TRUNC('month',CURRENT_DATE)";
    else if (p==='year') w += " AND date>=DATE_TRUNC('year',CURRENT_DATE)";

    const r1 = await pool.query(`SELECT COALESCE(SUM(amount),0) AS total, COUNT(*) AS count FROM expenses ${w}`, [req.userId]);
    const r2 = await pool.query(`SELECT COALESCE(SUM(amount),0) AS total FROM income ${w}`, [req.userId]);
    res.json({ ok: true, totalSpent: parseFloat(r1.rows[0].total), transactionCount: parseInt(r1.rows[0].count,10), totalIncome: parseFloat(r2.rows[0].total), period: p||'all' });
  } catch (err) { next(err); }
});

// ── Analytics sub-routes matching test expectations ────────────────────────────
router.get('/spending', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const now = new Date();
    const start = startDate || new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const end = endDate || now.toISOString().split('T')[0];
    const r = await pool.query('SELECT COALESCE(SUM(amount),0) AS total FROM expenses WHERE user_id=$1 AND date>=$2 AND date<=$3', [req.userId, start, end]);
    res.json({ ok: true, totalSpent: parseFloat(r.rows[0].total), period: { start, end } });
  } catch (err) { next(err); }
});

router.get('/income', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const now = new Date();
    const start = startDate || new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const end = endDate || now.toISOString().split('T')[0];
    const r = await pool.query('SELECT COALESCE(SUM(amount),0) AS total FROM income WHERE user_id=$1 AND date>=$2 AND date<$3', [req.userId, start, end]);
    res.json({ ok: true, totalIncome: parseFloat(r.rows[0].total), period: { start, end } });
  } catch (err) { next(err); }
});

router.get('/networth', async (req, res, next) => {
  try {
    const accounts = await pool.query('SELECT SUM(balance) AS total FROM accounts WHERE user_id=$1', [req.userId]);
    res.json({ ok: true, netWorth: parseFloat(accounts.rows[0]?.total || 0) });
  } catch (err) { next(err); }
});

router.get('/monthly', async (req, res, next) => {
  try {
    const n = 6;
    const exp = await pool.query(`SELECT DATE_TRUNC('month',date)::DATE AS month, SUM(amount) AS total FROM expenses WHERE user_id=$1 AND date>=DATE_TRUNC('month',NOW())-INTERVAL '${n} months' GROUP BY month ORDER BY month`, [req.userId]);
    const em = {}; exp.rows.forEach(r => { em[r.month?.toISOString?.()?.substring(0,7)??r.month] = parseFloat(r.total); });
    const data = [];
    for (let i=n-1; i>=0; i--) {
      const d = new Date(); d.setDate(1); d.setMonth(d.getMonth()-i);
      const k = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
      data.push({ month: k, total: em[k]||0 });
    }
    res.json({ ok: true, data });
  } catch (err) { next(err); }
});

module.exports = router;