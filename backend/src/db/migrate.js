require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
const pool = require('./pool');

async function migrate() {
  const client = await pool.connect();
  try {
    // Reset schema – drop and recreate public to avoid type mismatches from prior partial runs
    await client.query('DROP SCHEMA IF EXISTS public CASCADE');
    await client.query('CREATE SCHEMA IF NOT EXISTS public');
    await client.query('GRANT ALL ON SCHEMA public TO public');

    await client.query('BEGIN');

    // ─── Users ─────────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(255) NOT NULL,
        avatar_url TEXT,
        phone VARCHAR(50),
        currency VARCHAR(10) DEFAULT 'USD',
        is_email_verified BOOLEAN DEFAULT FALSE,
        is_biometric_enabled BOOLEAN DEFAULT FALSE,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Refresh Tokens ──────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token TEXT UNIQUE NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── OTP Codes ───────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS otp_codes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) NOT NULL,
        code VARCHAR(10) NOT NULL,
        purpose VARCHAR(20) NOT NULL DEFAULT 'verify',
        expires_at TIMESTAMPTZ NOT NULL,
        used BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Categories ──────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(100) NOT NULL,
        icon VARCHAR(50) DEFAULT 'category',
        color VARCHAR(7) DEFAULT '#607D8B',
        type VARCHAR(10) DEFAULT 'expense',
        is_default BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, name)
      );
    `);

    // ─── Expenses ────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS expenses (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        amount DECIMAL(12,2) NOT NULL CHECK(amount >= 0),
        currency VARCHAR(10) DEFAULT 'USD',
        date DATE NOT NULL,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        notes TEXT,
        receipt_url TEXT,
        is_recurring BOOLEAN DEFAULT FALSE,
        tags TEXT[] DEFAULT '{}',
        payment_method VARCHAR(50),
        location TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Income ──────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS income (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        amount DECIMAL(12,2) NOT NULL CHECK(amount >= 0),
        currency VARCHAR(10) DEFAULT 'USD',
        date DATE NOT NULL,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        notes TEXT,
        is_recurring BOOLEAN DEFAULT FALSE,
        source VARCHAR(100),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Budgets ─────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS budgets (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        amount DECIMAL(12,2) NOT NULL CHECK(amount > 0),
        spent DECIMAL(12,2) DEFAULT 0 CHECK(spent >= 0),
        period VARCHAR(20) DEFAULT 'MONTHLY',
        start_date DATE NOT NULL,
        end_date DATE,
        alert_at INT DEFAULT 80 CHECK(alert_at BETWEEN 1 AND 100),
        is_active BOOLEAN DEFAULT TRUE,
        color VARCHAR(7),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Savings Goals ───────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS savings_goals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        target_amount DECIMAL(12,2) NOT NULL CHECK(target_amount > 0),
        saved_amount DECIMAL(12,2) DEFAULT 0 CHECK(saved_amount >= 0),
        currency VARCHAR(10) DEFAULT 'USD',
        deadline DATE,
        icon VARCHAR(50),
        color VARCHAR(7),
        status VARCHAR(20) DEFAULT 'ACTIVE',
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Savings Contributions ───────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS savings_contributions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        goal_id UUID NOT NULL REFERENCES savings_goals(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount DECIMAL(12,2) NOT NULL CHECK(amount > 0),
        notes TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Subscriptions ──────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        amount DECIMAL(12,2) NOT NULL CHECK(amount >= 0),
        currency VARCHAR(10) DEFAULT 'USD',
        billing_cycle VARCHAR(20) DEFAULT 'MONTHLY',
        next_billing_date DATE NOT NULL,
        category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
        notes TEXT,
        is_active BOOLEAN DEFAULT TRUE,
        logo_url TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Notes ───────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS notes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        content TEXT,
        color VARCHAR(7),
        tags TEXT[] DEFAULT '{}',
        is_pinned BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Accounts ────────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS accounts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        type VARCHAR(50) DEFAULT 'checking',
        balance DECIMAL(14,2) DEFAULT 0,
        currency VARCHAR(10) DEFAULT 'USD',
        institution VARCHAR(255),
        account_number_masked VARCHAR(20),
        color VARCHAR(7),
        icon VARCHAR(50),
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Notifications ──────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        body TEXT,
        type VARCHAR(50) NULL DEFAULT 'info',
        is_read BOOLEAN DEFAULT FALSE,
        related_entity_type VARCHAR(50),
        related_entity_id UUID,
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── Family Members ─────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS family_members (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        member_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role VARCHAR(50) DEFAULT 'family',
        created_at TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, member_id)
      );
    `);

    // ─── Add shared_with_family to expenses and income ──────────────────────
    await client.query(`ALTER TABLE expenses ADD COLUMN IF NOT EXISTS shared_with_family BOOLEAN DEFAULT false;`);
    await client.query(`ALTER TABLE income ADD COLUMN IF NOT EXISTS shared_with_family BOOLEAN DEFAULT false;`);

    // ─── Unified transactions view for exports ──────────────────────────────
    await client.query(`
      CREATE OR REPLACE VIEW transactions_view AS
      SELECT
        id, 'expense' AS type, user_id, category_id, amount, currency, date,
        title AS description, notes, payment_method, receipt_url, is_recurring,
        shared_with_family, created_at, updated_at
      FROM expenses
      UNION ALL
      SELECT
        id, 'income' AS type, user_id, category_id, amount, currency, date,
        title AS description, notes, NULL AS payment_method, NULL AS receipt_url,
        is_recurring, shared_with_family, created_at, updated_at
      FROM income;
    `);

    // ─── AI Conversations ────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS ai_conversations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);

    // ─── AI Messages ─────────────────────────────────────────────────────────
    await client.query(`
      CREATE TABLE IF NOT EXISTS ai_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        role VARCHAR(20) NOT NULL,
        content TEXT NOT NULL,
        provider VARCHAR(20),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
    // Backfill missing columns for DBs created before these were added.
    await client.query(`ALTER TABLE ai_messages ADD COLUMN IF NOT EXISTS provider VARCHAR(20);`);
    await client.query(`ALTER TABLE ai_conversations ADD COLUMN IF NOT EXISTS title VARCHAR(255);`);

    // ─── Indexes ─────────────────────────────────────────────────────────────
    await client.query('CREATE INDEX IF NOT EXISTS idx_expenses_user_date ON expenses(user_id, date DESC);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_income_user_date ON income(user_id, date DESC);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_budgets_user ON budgets(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_savings_goals_user ON savings_goals(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_notes_user ON notes(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_accounts_user ON accounts(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations(user_id, updated_at DESC);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_ai_messages_conv ON ai_messages(conversation_id, created_at);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);');
    await client.query('CREATE INDEX IF NOT EXISTS idx_otp_codes_email ON otp_codes(email, purpose);');

    await client.query('COMMIT');
    console.log('✅ All migrations completed successfully.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌ Migration failed:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate();