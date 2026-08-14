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

router.get('/', async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
    const offset = (page - 1) * limit;
    const { startDate, endDate, type, categoryId, sort } = req.query;
    const orderDir = sort === 'oldest' ? 'ASC' : 'DESC';

    // Build parameterized WHERE clauses for each table independently so that
    // placeholder numbering ($1, $2, ...) is always correct per query.
    // This also closes the SQL-injection hole that the previous string
    // concatenation introduced (user-supplied startDate/endDate/categoryId
    // were interpolated directly into SQL).
    //
    // Helper: builds a { clauses, params } pair starting at placeholder `start`.
    function buildWhere(tableAlias, start) {
      const clauses = [`${tableAlias}.user_id = $${start}`];
      const params = [req.userId];
      let i = start + 1;
      if (startDate) {
        clauses.push(`${tableAlias}.date >= $${i++}`);
        params.push(startDate);
      }
      if (endDate) {
        clauses.push(`${tableAlias}.date <= $${i++}`);
        params.push(endDate);
      }
      return { clauses: clauses.join(' AND '), params };
    }

    // For standalone expense/income COUNT queries, each starts at $1.
    const expenseWhereStandalone = buildWhere('e', 1);
    const incomeWhereStandalone = buildWhere('i', 1);

    let ec = 0, ic = 0;
    if (!type || type === 'expense') {
      const r = await pool.query(`SELECT COUNT(*) FROM expenses e WHERE ${expenseWhereStandalone.clauses}`, expenseWhereStandalone.params);
      ec = parseInt(r.rows[0].count, 10);
    }
    if (!type || type === 'income') {
      const r = await pool.query(`SELECT COUNT(*) FROM income i WHERE ${incomeWhereStandalone.clauses}`, incomeWhereStandalone.params);
      ic = parseInt(r.rows[0].count, 10);
    }
    const total = ec + ic;
    const totalPages = Math.ceil(total / limit);

    // ── Build the UNION fetch ────────────────────────────────────────────────
    // Depending on `type` we include either one branch or both branches of the
    // UNION ALL. Each branch carries its own $N placeholders, so when both are
    // present the income branch's placeholders must be rebased to follow the
    // expense branch's parameters.
    let unionSql = '';
    let unionParams = [];

    const expenseClauseBase = expenseWhereStandalone.clauses; // placeholders $1..
    const expenseParamsBase = [...expenseWhereStandalone.params];
    // Append categoryId filter to the expense side only.
    let expenseClauseFinal = expenseClauseBase;
    if (categoryId) {
      const ni = expenseParamsBase.length + 1;
      expenseClauseFinal += ` AND e.category_id = $${ni}`;
      expenseParamsBase.push(categoryId);
    }

    const incomeClauseBase = incomeWhereStandalone.clauses; // placeholders $1..

    if (type === 'income') {
      // Only the income branch.
      const lIdx = incomeWhereStandalone.params.length + 1;
      const oIdx = lIdx + 1;
      unionSql = `SELECT * FROM (
        SELECT i.id,'income' AS type,i.title,i.amount,i.currency,i.date,i.category_id,
               c.name AS cat_name,c.icon AS cat_icon,c.color AS cat_color,
               i.notes AS note,NULL AS payment_method,NULL AS location,ARRAY[]::text[] AS tags,i.created_at
        FROM income i LEFT JOIN categories c ON i.category_id=c.id
        WHERE ${incomeClauseBase}
      ) combined
      ORDER BY combined.date ${orderDir}, combined.created_at ${orderDir}
      LIMIT $${lIdx} OFFSET $${oIdx}`;
      unionParams = [...incomeWhereStandalone.params, limit, offset];
    } else if (type === 'expense') {
      // Only the expense branch (including categoryId filter).
      const lIdx = expenseParamsBase.length + 1;
      const oIdx = lIdx + 1;
      unionSql = `SELECT * FROM (
        SELECT e.id,'expense' AS type,e.title,e.amount,e.currency,e.date,e.category_id,
               c.name AS cat_name,c.icon AS cat_icon,c.color AS cat_color,
               e.notes AS note,e.payment_method,e.location,e.tags,e.created_at
        FROM expenses e LEFT JOIN categories c ON e.category_id=c.id
        WHERE ${expenseClauseFinal}
      ) combined
      ORDER BY combined.date ${orderDir}, combined.created_at ${orderDir}
      LIMIT $${lIdx} OFFSET $${oIdx}`;
      unionParams = [...expenseParamsBase, limit, offset];
    } else {
      // Both branches — rebase income placeholders to follow expense params.
      const incomeStart = expenseParamsBase.length + 1;
      const incomeRebased = [`i.user_id = $${incomeStart}`];
      const incomeParamsRebased = [req.userId]; // userId for the income branch
      let ip = incomeStart + 1;
      if (startDate) {
        incomeRebased.push(`i.date >= $${ip++}`);
        incomeParamsRebased.push(startDate);
      }
      if (endDate) {
        incomeRebased.push(`i.date <= $${ip++}`);
        incomeParamsRebased.push(endDate);
      }
      const limitIdx = expenseParamsBase.length + incomeParamsRebased.length + 1;
      const offsetIdx = limitIdx + 1;
      unionSql = `SELECT * FROM (
        SELECT e.id,'expense' AS type,e.title,e.amount,e.currency,e.date,e.category_id,
               c.name AS cat_name,c.icon AS cat_icon,c.color AS cat_color,
               e.notes AS note,e.payment_method,e.location,e.tags,e.created_at
        FROM expenses e LEFT JOIN categories c ON e.category_id=c.id
        WHERE ${expenseClauseFinal}
        UNION ALL
        SELECT i.id,'income' AS type,i.title,i.amount,i.currency,i.date,i.category_id,
               c.name AS cat_name,c.icon AS cat_icon,c.color AS cat_color,
               i.notes AS note,NULL AS payment_method,NULL AS location,ARRAY[]::text[] AS tags,i.created_at
        FROM income i LEFT JOIN categories c ON i.category_id=c.id
        WHERE ${incomeRebased.join(' AND ')}
      ) combined
      ORDER BY combined.date ${orderDir}, combined.created_at ${orderDir}
      LIMIT $${limitIdx} OFFSET $${offsetIdx}`;
      unionParams = [...expenseParamsBase, ...incomeParamsRebased, limit, offset];
    }

    const result = await pool.query(unionSql, unionParams);

    const items = result.rows.map(r => {
      const tags = r.tags || [];
      return {
        id: r.id, type: r.type, title: r.title,
        amount: parseFloat(r.amount), currency: r.currency || 'INR',
        date: r.date?.toISOString?.() ?? r.date,
        category: r.cat_name ? { id: r.category_id, name: r.cat_name, icon: r.cat_icon, color: r.cat_color } : null,
        categoryId: r.category_id, note: r.note,
        paymentMethod: r.payment_method, location: r.location,
        tags: Array.isArray(tags) ? tags : [],
        createdAt: r.created_at?.toISOString?.() ?? r.created_at,
      };
    });

    res.json({ ok: true, items, pagination: { page, totalPages, total } });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
    const { type, title, description, amount, currency, date, categoryId, notes, paymentMethod, location, tags, isRecurring, receiptUrl } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const txTitle = title || description || (type === 'income' ? 'Income' : 'Expense');
    const validCategoryId = await resolveCategoryId(categoryId, req.userId);

    if (type === 'income') {
      const result = await pool.query(
        `INSERT INTO income (id, user_id, title, amount, currency, date, category_id, source, notes, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
        [id, req.userId, txTitle, amount, currency || 'INR', date || now, validCategoryId, txTitle, notes || null, now, now],
      );
      return res.status(201).json({
        ok: true,
        id: result.rows[0].id,
        type: 'income',
        title: result.rows[0].title,
        amount: parseFloat(result.rows[0].amount),
        currency: result.rows[0].currency,
        date: result.rows[0].date?.toISOString?.() ?? result.rows[0].date,
        categoryId: result.rows[0].category_id,
        note: result.rows[0].notes,
        createdAt: result.rows[0].created_at?.toISOString?.() ?? result.rows[0].created_at,
      });
    } else {
      const result = await pool.query(
        `INSERT INTO expenses (id, user_id, title, amount, currency, date, category_id, notes, payment_method, location, is_recurring, receipt_url, tags, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING *`,
        [id, req.userId, txTitle, amount, currency || 'INR', date || now, validCategoryId, notes || null, paymentMethod || null, location || null, isRecurring || false, receiptUrl || null, tags ? (Array.isArray(tags) ? tags : [tags]) : [], now, now],
      );
      return res.status(201).json({
        ok: true,
        id: result.rows[0].id,
        type: 'expense',
        title: result.rows[0].title,
        amount: parseFloat(result.rows[0].amount),
        currency: result.rows[0].currency,
        date: result.rows[0].date?.toISOString?.() ?? result.rows[0].date,
        categoryId: result.rows[0].category_id,
        note: result.rows[0].notes,
        paymentMethod: result.rows[0].payment_method,
        location: result.rows[0].location,
        tags: result.rows[0].tags,
        receiptUrl: result.rows[0].receipt_url,
        isRecurring: result.rows[0].is_recurring,
        createdAt: result.rows[0].created_at?.toISOString?.() ?? result.rows[0].created_at,
      });
    }
  } catch (err) { next(err); }
});

module.exports = router;