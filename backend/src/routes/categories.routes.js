const { Router } = require('express');
const { z } = require('zod');
const pool = require('../db/pool');
const authenticate = require('../middleware/auth');
const validate = require('../middleware/validate');

const router = Router();
router.use(authenticate);

const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
  icon: z.string().default('category'),
  color: z.string().default('#607D8B'),
  type: z.enum(['expense', 'income', 'both']).default('expense'),
});

const categoryRowToJson = (row) => ({
  id: row.id,
  name: row.name,
  icon: row.icon,
  color: row.color,
  type: row.type,
  isDefault: row.is_default,
  createdAt: row.created_at?.toISOString?.() ?? row.created_at,
});

// GET /api/categories
router.get('/', async (req, res) => {
  try {
    // User's custom categories + default categories
    const { rows } = await pool.query(
      `SELECT * FROM categories WHERE user_id = $1 OR (user_id IS NULL AND is_default = TRUE)
       ORDER BY is_default DESC, name ASC`,
      [req.userId],
    );
    res.json(rows.map(categoryRowToJson));
  } catch (err) {
    console.error('GET /categories error:', err);
    res.status(500).json({ message: 'Failed to fetch categories.' });
  }
});

// POST /api/categories
router.post('/', validate(createCategorySchema), async (req, res) => {
  try {
    const d = req.body;

    // Check duplicate name for user
    const dupe = await pool.query('SELECT id FROM categories WHERE user_id = $1 AND name = $2', [req.userId, d.name]);
    if (dupe.rows.length > 0) {
      return res.status(409).json({ message: 'A category with this name already exists.', code: 'DUPLICATE_NAME' });
    }

    const { rows } = await pool.query(
      'INSERT INTO categories (user_id, name, icon, color, type) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [req.userId, d.name, d.icon, d.color, d.type],
    );
    res.status(201).json(categoryRowToJson(rows[0]));
  } catch (err) {
    console.error('POST /categories error:', err);
    res.status(500).json({ message: 'Failed to create category.' });
  }
});

// DELETE /api/categories/:id (only user-created, non-default)
router.delete('/:id', async (req, res) => {
  try {
    const r = await pool.query(
      'DELETE FROM categories WHERE id = $1 AND user_id = $2 AND is_default = FALSE RETURNING id',
      [req.params.id, req.userId],
    );
    if (r.rows.length === 0) return res.status(404).json({ message: 'Category not found or cannot be deleted.' });
    res.status(204).send();
  } catch (err) {
    console.error('DELETE /categories/:id error:', err);
    res.status(500).json({ message: 'Failed to delete category.' });
  }
});

module.exports = router;