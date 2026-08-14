const { Router } = require('express');
const authenticate = require('../middleware/auth');
// Use Node.js built-in global fetch (Node 18+)

const router = Router();
router.use(authenticate);

// Cache rates in-memory (TTL 60 min)
let cachedRates = null;
let lastFetched = 0;

async function getRates(base = 'INR') {
  const now = Date.now();
  if (cachedRates && lastFetched > now - 3600000) return cachedRates;

  const API_KEY = process.env.EXCHANGE_RATE_API_KEY || '';
  // Try exchangerate-api.com first, fall back to open.er-api.com
  try {
    const resp = await fetch(
      `https://open.er-api.com/v6/latest/${base}`,
      { headers: API_KEY ? { Authorization: `Bearer ${API_KEY}` } : {} },
    );
    if (!resp.ok) throw new Error('Free API down');
    const data = await resp.json();
    cachedRates = { base: base, rates: data.rates, lastUpdated: new Date().toISOString() };
    lastFetched = now;
    return cachedRates;
  } catch (err) {
    // Fallback static rates for popular pairs
    const fallback = {
      INR: 83.23, USD: 1, EUR: 0.92, GBP: 0.79, JPY: 149.34, AUD: 1.52,
      CAD: 1.36, CHF: 0.88, CNY: 7.24, SGD: 1.34,
    };
    if (base !== 'USD') {
      // Convert fallback from USD to base
      const baseRate = fallback[base] || 1;
      const converted = {};
      Object.entries(fallback).forEach(([k, v]) => { converted[k] = +(v / baseRate).toFixed(6); });
      return { base, rates: converted, lastUpdated: new Date().toISOString(), fallback: true };
    }
    return { base: 'USD', rates: fallback, lastUpdated: new Date().toISOString(), fallback: true };
  }
}

// ── GET /api/currency/rates ──────────────────────────────────────────────────
router.get('/rates', async (req, res, next) => {
  try {
    const base = req.query.base || 'USD';
    const rates = await getRates(base);
    res.json({ ok: true, ...rates });
  } catch (err) { next(err); }
});

// ── POST /api/currency/convert ───────────────────────────────────────────────
router.post('/convert', async (req, res, next) => {
  try {
    const { amount, from, to } = req.body;
    if (!amount || !from || !to) {
      return res.status(400).json({ ok: false, error: 'amount, from, and to are required' });
    }

    const rates = await getRates(from);
    const rate = rates.rates[to];
    if (!rate) {
      return res.status(400).json({ ok: false, error: `Currency ${to} not supported` });
    }

    const converted = +(parseFloat(amount) * rate).toFixed(2);
    res.json({
      ok: true,
      from,
      to,
      amount: parseFloat(amount),
      rate,
      result: converted,
      lastUpdated: rates.lastUpdated,
    });
  } catch (err) { next(err); }
});

// ── GET /api/currency/list ───────────────────────────────────────────────────
router.get('/list', async (_req, res, next) => {
  try {
    const rates = await getRates('USD');
    res.json({
      ok: true,
      currencies: Object.keys(rates.rates).sort(),
      lastUpdated: rates.lastUpdated,
    });
  } catch (err) { next(err); }
});

module.exports = router;