require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// ── Route modules ────────────────────────────────────────────────────────────
const authRoutes       = require('./routes/auth.routes');
const expenseRoutes    = require('./routes/expenses.routes');
const incomeRoutes     = require('./routes/income.routes');
const budgetRoutes     = require('./routes/budgets.routes');
const savingsRoutes    = require('./routes/savings.routes');
const categoryRoutes   = require('./routes/categories.routes');
const subscriptionRoutes = require('./routes/subscriptions.routes');
const noteRoutes       = require('./routes/notes.routes');
const notificationRoutes = require('./routes/notifications.routes.js');
const familyRoutes     = require('./routes/family.routes.js');
const exportsRoutes    = require('./routes/exports.routes.js');
const calculatorRoutes = require('./routes/calculator.routes.js');
const currencyRoutes    = require('./routes/currency.routes.js');
const accountRoutes    = require('./routes/accounts.routes');
const aiRoutes         = require('./routes/ai.routes');
const transactionRoutes = require('./routes/transactions.routes');
const analyticsRoutes  = require('./routes/analytics.routes');

// ── App ──────────────────────────────────────────────────────────────────────
const app = express();

// ── Security & parsing ───────────────────────────────────────────────────────
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*', credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Logging ──────────────────────────────────────────────────────────────────
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// ── Rate limiting ────────────────────────────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many requests, slow down please.' },
});
app.use(globalLimiter);

// ── Auth rate limit (strict) ─────────────────────────────────────────────────
const authLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many auth attempts.' },
});

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ ok: true, status: 'healthy', timestamp: new Date().toISOString() });
});
app.get('/health', (_req, res) => {
  res.json({ ok: true, status: 'healthy', timestamp: new Date().toISOString() });
});

// ── Mount routes at BOTH /api/xxx AND /xxx ──────────────────────────────────
// Helper: mount route module at path with/without /api prefix
function mountBoth(app, path, router, limiter) {
  if (limiter) {
    app.use(`/api${path}`, limiter, router);
    app.use(path, limiter, router);
  } else {
    app.use(`/api${path}`, router);
    app.use(path, router);
  }
}

// Auth (with stricter rate limit)
app.use('/api/auth', authLimiter, authRoutes);
app.use('/auth', authLimiter, authRoutes);

// Features
mountBoth(app, '/expenses',      expenseRoutes);
mountBoth(app, '/income',        incomeRoutes);
mountBoth(app, '/budgets',       budgetRoutes);
mountBoth(app, '/savings',       savingsRoutes);
mountBoth(app, '/categories',    categoryRoutes);
mountBoth(app, '/subscriptions', subscriptionRoutes);
mountBoth(app, '/notes',         noteRoutes);
mountBoth(app, '/notifications', notificationRoutes);
mountBoth(app, '/accounts',      accountRoutes);
mountBoth(app, '/ai',            aiRoutes);
mountBoth(app, '/transactions',  transactionRoutes);
mountBoth(app, '/analytics',     analyticsRoutes);
mountBoth(app, '/family',        familyRoutes);
mountBoth(app, '/exports',       exportsRoutes);
mountBoth(app, '/calculator',    calculatorRoutes);
mountBoth(app, '/currency',      currencyRoutes);

// Goals alias → same as savings (the Flutter app uses /api/goals)
mountBoth(app, '/goals', savingsRoutes);

// ── 404 & error handler ──────────────────────────────────────────────────────
app.use('/api', notFoundHandler);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;