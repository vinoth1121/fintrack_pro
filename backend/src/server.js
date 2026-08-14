require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const app = require('./app');
const pool = require('./db/pool');

const PORT = parseInt(process.env.PORT, 10) || 3000;
const HOST = process.env.HOST || '0.0.0.0';

async function start() {
  // Verify database connection
  try {
    const { rows } = await pool.query('SELECT NOW() AS current_time');
    console.log(`🗄️  PostgreSQL connected — server time: ${rows[0].current_time}`);
  } catch (err) {
    console.error('❌ Failed to connect to PostgreSQL. Check DATABASE_URL in .env');
    console.error(err.message);
    process.exit(1);
  }

  app.listen(PORT, HOST, () => {
    console.log(`🚀 FinTrack Pro API running on http://${HOST}:${PORT}`);
    console.log(`   Health check: http://${HOST}:${PORT}/api/health`);
  });
}

start();