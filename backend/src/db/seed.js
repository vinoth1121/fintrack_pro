require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
const { v4: uuid } = require('uuid');
const bcrypt = require('bcryptjs');
const pool = require('./pool');

async function seed() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    console.log('🌱 Seeding default categories...');

    // ─── Default Expense Categories ────────────────────────────────────────────
    const expenseCategories = [
      { name: '🍔 Food & Dining',   icon: 'restaurant',     color: '#FF6B6B', type: 'expense' },
      { name: '🚗 Transportation',  icon: 'directions_car',  color: '#4ECDC4', type: 'expense' },
      { name: '🛒 Shopping',        icon: 'shopping_cart',   color: '#45B7D1', type: 'expense' },
      { name: '🏠 Housing',         icon: 'home',            color: '#96CEB4', type: 'expense' },
      { name: '💊 Healthcare',      icon: 'local_hospital',  color: '#FFEAA7', type: 'expense' },
      { name: '🎬 Entertainment',   icon: 'movie',           color: '#DDA0DD', type: 'expense' },
      { name: '📚 Education',       icon: 'school',          color: '#98D8C8', type: 'expense' },
      { name: '💻 Utilities',       icon: 'power',           color: '#F7DC6F', type: 'expense' },
      { name: '👕 Clothing',        icon: 'checkroom',       color: '#BB8FCE', type: 'expense' },
      { name: '🎁 Gifts',           icon: 'card_giftcard',   color: '#F1948A', type: 'expense' },
      { name: '📱 Phone & Internet',icon: 'phone_android',   color: '#85C1E9', type: 'expense' },
      { name: '✈️ Travel',          icon: 'flight',          color: '#52BE80', type: 'expense' },
      { name: '🐾 Pets',            icon: 'pets',            color: '#F0B27A', type: 'expense' },
      { name: '🧾 Other',           icon: 'receipt_long',    color: '#607D8B', type: 'expense' },
    ];

    for (const cat of expenseCategories) {
      await client.query(
        `INSERT INTO categories (name, icon, color, type, is_default) VALUES ($1,$2,$3,$4,TRUE)
         ON CONFLICT (user_id, name) DO NOTHING`,
        [cat.name, cat.icon, cat.color, cat.type],
      );
    }

    // ─── Default Income Categories ─────────────────────────────────────────────
    const incomeCategories = [
      { name: '💼 Salary',          icon: 'work',         color: '#27AE60', type: 'income' },
      { name: '📈 Investments',     icon: 'trending_up',  color: '#2ECC71', type: 'income' },
      { name: '💸 Freelance',       icon: 'laptop',       color: '#1ABC9C', type: 'income' },
      { name: '🏠 Rental Income',   icon: 'apartment',    color: '#16A085', type: 'income' },
      { name: '🎁 Gifts Received',  icon: 'redeem',       color: '#F1C40F', type: 'income' },
      { name: '📊 Dividends',       icon: 'pie_chart',    color: '#8E44AD', type: 'income' },
      { name: '💰 Other Income',    icon: 'attach_money', color: '#7F8C8D', type: 'income' },
    ];

    for (const cat of incomeCategories) {
      await client.query(
        `INSERT INTO categories (name, icon, color, type, is_default) VALUES ($1,$2,$3,$4,TRUE)
         ON CONFLICT (user_id, name) DO NOTHING`,
        [cat.name, cat.icon, cat.color, cat.type],
      );
    }

    console.log('✅ Default categories seeded.');
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Seed failed:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

seed();