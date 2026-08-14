const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();
router.use(authenticate);

function formatNotification(row) {
  let action = null;
  try {
    if (row.action) action = typeof row.action === 'string' ? JSON.parse(row.action) : row.action;
  } catch { action = null; }

  return {
    id: row.id,
    title: row.title,
    body: row.message || row.body || '',
    message: row.message || row.body || '',
    kind: row.kind || row.type || 'info',
    type: row.type || row.kind || 'info',
    read: row.is_read || false,
    isRead: row.is_read || false,
    action,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
  };
}

router.get('/', async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
    const offset = (page - 1) * limit;

    const countResult = await pool.query('SELECT COUNT(*) FROM notifications WHERE user_id = $1', [req.userId]);
    const total = parseInt(countResult.rows[0].count, 10);
    const totalPages = Math.ceil(total / limit);

    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
      [req.userId, limit, offset],
    );

    const items = result.rows.map(formatNotification);
    res.json({ ok: true, items, pagination: { page, totalPages, total } });
  } catch (err) { next(err); }
});

router.get('/unread-count', async (req, res, next) => {
  try {
    const result = await pool.query('SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false', [req.userId]);
    res.json({ ok: true, count: parseInt(result.rows[0].count, 10) });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
    const { title, body, message, kind, type, read, action } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const result = await pool.query(
      `INSERT INTO notifications (id, user_id, title, message, body, kind, type, is_read, action, created_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [id, req.userId, title, message || body || '', message || body || '', kind || type || 'info', kind || type || 'info', read || false, action ? JSON.stringify(action) : null, now],
    );
    res.status(201).json(formatNotification(result.rows[0]));
  } catch (err) { next(err); }
});

router.patch('/:id/read', async (req, res, next) => {
  try {
    const result = await pool.query('UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *', [req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Notification not found' });
    res.json(formatNotification(result.rows[0]));
  } catch (err) { next(err); }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { read } = req.body;
    const result = await pool.query('UPDATE notifications SET is_read = $1 WHERE id = $2 AND user_id = $3 RETURNING *', [read !== false, req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Notification not found' });
    res.json(formatNotification(result.rows[0]));
  } catch (err) { next(err); }
});

router.patch('/read-all', async (req, res, next) => {
  try {
    await pool.query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.userId]);
    res.json({ ok: true, message: 'All notifications marked as read' });
  } catch (err) { next(err); }
});

router.post('/read-all', async (req, res, next) => {
  try {
    await pool.query('UPDATE notifications SET is_read = true WHERE user_id = $1', [req.userId]);
    res.json({ ok: true, message: 'All notifications marked as read' });
  } catch (err) { next(err); }
});

module.exports = router;