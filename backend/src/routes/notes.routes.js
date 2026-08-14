const { Router } = require('express');
const { v4: uuid } = require('uuid');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');

const router = Router();
router.use(authenticate);

function formatNote(row) {
  return {
    id: row.id,
    title: row.title,
    body: row.content,
    content: row.content,
    color: row.color || '#6C5CE7',
    pinned: row.is_pinned || false,
    tags: row.tags || [],
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
  };
}

router.get('/', async (req, res, next) => {
  try {
    const result = await pool.query('SELECT * FROM notes WHERE user_id = $1 ORDER BY is_pinned DESC, updated_at DESC', [req.userId]);
    res.json({ ok: true, items: result.rows.map(formatNote) });
  } catch (err) { next(err); }
});

router.post('/', async (req, res, next) => {
  try {
    const { title, body, content, color, pinned, tags } = req.body;
    const now = new Date().toISOString();
    const id = uuid();
    const result = await pool.query(
      `INSERT INTO notes (id, user_id, title, content, color, is_pinned, tags, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [id, req.userId, title || 'Untitled', body || content || '', color || '#6C5CE7', pinned || false, tags ? (Array.isArray(tags) ? tags : [tags]) : [], now, now],
    );
    res.status(201).json(formatNote(result.rows[0]));
  } catch (err) { next(err); }
});

router.patch('/:id', async (req, res, next) => {
  try {
    const { title, body, content, color, pinned, tags } = req.body;
    const updates = [];
    const values = [];
    let idx = 1;
    if (title !== undefined) { updates.push(`title = $${idx++}`); values.push(title); }
    if (body !== undefined || content !== undefined) { updates.push(`content = $${idx++}`); values.push(body ?? content); }
    if (color !== undefined) { updates.push(`color = $${idx++}`); values.push(color); }
    if (pinned !== undefined) { updates.push(`is_pinned = $${idx++}`); values.push(pinned); }
    if (tags !== undefined) { updates.push(`tags = $${idx++}`); values.push(Array.isArray(tags) ? tags : [tags]); }
    if (updates.length === 0) return res.status(400).json({ ok: false, error: 'No fields to update' });
    updates.push(`updated_at = $${idx++}`); values.push(new Date().toISOString());
    values.push(req.params.id, req.userId);
    const result = await pool.query(`UPDATE notes SET ${updates.join(', ')} WHERE id = $${idx++} AND user_id = $${idx} RETURNING *`, values);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Note not found' });
    res.json(formatNote(result.rows[0]));
  } catch (err) { next(err); }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const result = await pool.query('DELETE FROM notes WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.userId]);
    if (result.rows.length === 0) return res.status(404).json({ ok: false, error: 'Note not found' });
    res.json({ ok: true, message: 'Note deleted' });
  } catch (err) { next(err); }
});

module.exports = router;