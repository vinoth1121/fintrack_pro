const { Router } = require('express');
const pool = require('../db/pool');
const auth = require('../middleware/auth');

const router = Router();
// All AI routes require an authenticated user (req.userId is set by auth middleware).
router.use(auth);
// ───────────────────────────────────────────────────────────────────────────────
// SYSTEM PROMPT — Lumina, the FinTrack Pro AI assistant.
// Only discusses matters inside the FinTrack Pro app.
// ───────────────────────────────────────────────────────────────────────────────
const SYSTEM_PROMPT = `You are Lumina, an AI financial assistant for the FinTrack Pro personal finance app.

CRITICAL RULES — INTERNAL DATA ONLY:
1. You ONLY discuss matters related to FinTrack Pro — personal finance, budgeting, expenses, income, savings goals, subscriptions, receipts, notes, reports, and financial analytics.
2. You DO NOT answer general questions, write code, generate creative content, or discuss topics outside personal finance.
3. You must NEVER use or cite external, real-world, live, or web-sourced information. This includes (but is not limited to): live exchange rates, current prices, news, current events, weather, stock tickers, or anything not contained in the user's own FinTrack Pro data. If asked for such information, decline and explain you only work with the user's internal data.
4. You may ONLY reference numbers that appear in the "INTERNAL FINTRACK PRO DATA" block below (sourced from PostgreSQL) or that the user explicitly types in their message. NEVER invent balances, totals, merchants, dates, or categories.
5. If a user asks something outside FinTrack Pro's scope, politely decline: "I'm here to help with your personal finances inside FinTrack Pro. Please keep questions related to budgeting, expenses, savings, and your financial data."
6. You are helpful, concise, and data-driven. When the context data is provided, reference those exact numbers directly and use the user's currency (₹ INR by default).
7. For the /chat endpoint you return natural-language prose. For /receipt, /voice, /insights and /weekly-summary endpoints you MUST return ONLY valid JSON (no prose, no markdown code fences) matching the documented shape.`;

// ── AI reply generator (shared) ───────────────────────────────────────────────
// Abort fetching after `ms` so calls never hang the server / tests.
function fetchWithTimeout(url, options, ms = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  return fetch(url, { ...options, signal: controller.signal })
    .finally(() => clearTimeout(timer));
}

// ── Provider health cache ───────────────────────────────────────────────────
// When the AI provider starts failing/timing out (e.g. free-quota exhausted),
// remember it for a cooldown period so subsequent requests short-circuit to the
// mock reply instantly instead of every caller waiting the full 8s timeout.
let _providerDeadUntil = 0;
const PROVIDER_COOLDOWN_MS = 60 * 1000; // 1 minute

function isProviderKnownDead() {
  return Date.now() < _providerDeadUntil;
}

function markProviderDead() {
  _providerDeadUntil = Date.now() + PROVIDER_COOLDOWN_MS;
}

function markProviderAlive() {
  _providerDeadUntil = 0;
}

async function callAI({ systemPrompt, userMessage, temperature = 0.7, maxTokens = 1024 }) {
  const apiKey = process.env.AI_API_KEY;
  const enabled = process.env.AI_ENABLED === 'true' || process.env.AI_ENABLED === '1';

  if (!enabled || !apiKey) {
    return { reply: null, provider: 'mock' };
  }

  // Short-circuit to mock if a recent call already proved the provider is down.
  if (isProviderKnownDead()) {
    return { reply: null, provider: 'mock' };
  }

  const provider = (process.env.AI_PROVIDER || 'nvidia').toLowerCase();
  const baseUrl = (process.env.AI_BASE_URL || 'https://integrate.api.nvidia.com/v1').replace(/\/$/, '');
  const model = process.env.AI_MODEL || 'deepseek-ai/deepseek-v4-flash';

  try {
    const response = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt || SYSTEM_PROMPT },
          { role: 'user', content: userMessage },
        ],
        temperature,
        max_tokens: maxTokens,
      }),
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data?.error?.message || `Provider returned ${response.status}`);
    }

    const content = data?.choices?.[0]?.message?.content?.trim();
    if (content) {
      markProviderAlive();
      return { reply: content, provider: provider === 'openai' ? 'openai' : 'nvidia' };
    }
    throw new Error('No content returned by AI provider');
  } catch (err) {
    // Provider timed out or errored — cool it down so subsequent calls
    // skip the network attempt and go straight to the mock reply.
    markProviderDead();
    console.warn('AI provider error, fallback to mock:', err.message);
    return { reply: null, provider: 'mock' };
  }
}

// ── Server-side context builder (internal PostgreSQL data only) ───────────────
// Pulls the user's REAL data straight from PostgreSQL so the model can never be
// fed (or tricked into using) externally-supplied numbers. This is the single
// source of truth for the "INTERNAL FINTRACK PRO DATA" block in the prompt.
async function buildUserContext(userId) {
  const ctx = { transactions: [], budgets: [], goals: [], currency: 'INR' };
  try {
    const recent = await pool.query(
      `SELECT t.type, t.amount, t.currency, t.description, t.notes, c.name AS category
       FROM transactions_view t
       LEFT JOIN categories c ON c.id = t.category_id
       WHERE t.user_id = $1
       ORDER BY t.date DESC
       LIMIT 15`,
      [userId],
    );
    ctx.transactions = recent.rows.map((r) => ({
      type: r.type,
      amount: Number(r.amount),
      currency: r.currency,
      category: r.category || 'Other',
      merchant: r.description,
      note: r.notes,
    }));

    const budgets = await pool.query(
      `SELECT b.amount AS "limit", COALESCE(b.spent,0) AS spent, c.name AS category
       FROM budgets b LEFT JOIN categories c ON c.id = b.category_id
       WHERE b.user_id = $1 AND b.is_active = true`,
      [userId],
    );
    ctx.budgets = budgets.rows.map((r) => ({
      category: r.category || 'General',
      limit: Number(r.limit),
      spent: Number(r.spent),
    }));

    const goals = await pool.query(
      `SELECT name, target_amount AS target, saved_amount AS saved FROM savings_goals WHERE user_id = $1`,
      [userId],
    );
    ctx.goals = goals.rows.map((r) => ({ name: r.name, target: Number(r.target), saved: Number(r.saved) }));

    const bal = await pool.query(
      `SELECT COALESCE(SUM(balance),0) AS total FROM accounts WHERE user_id = $1 AND is_active = true`,
      [userId],
    );
    ctx.totalBalance = Number(bal.rows[0]?.total || 0);

    const agg = await pool.query(
      `SELECT
         COALESCE(SUM(CASE WHEN type='income' THEN amount END),0) AS income,
         COALESCE(SUM(CASE WHEN type='expense' THEN amount END),0) AS expense
       FROM transactions_view WHERE user_id = $1 AND date >= date_trunc('month', NOW())`,
      [userId],
    );
    ctx.monthlyIncome = Number(agg.rows[0]?.income || 0);
    ctx.monthlyExpense = Number(agg.rows[0]?.expense || 0);

    const cur = await pool.query(`SELECT currency FROM users WHERE id = $1`, [userId]);
    ctx.currency = cur.rows[0]?.currency || 'INR';
  } catch (e) {
    console.warn('buildUserContext failed, proceeding with empty DB context:', e.message);
  }
  return ctx;
}

function contextToText(ctx) {
  if (!ctx) return '';
  let s = 'INTERNAL FINTRACK PRO DATA (do not use anything outside this block):\n';
  if (ctx.transactions?.length) {
    s += 'Recent transactions:\n' + ctx.transactions
      .map((t) => `  ${t.type}: ${t.currency || '₹'}${t.amount} (${t.category}, ${t.merchant || 'n/a'})`)
      .join('\n') + '\n';
  }
  if (ctx.budgets?.length) {
    s += 'Budgets:\n' + ctx.budgets
      .map((b) => `  ${b.category}: ${b.currency || '₹'}${b.spent}/${b.currency || '₹'}${b.limit}`)
      .join('\n') + '\n';
  }
  if (ctx.goals?.length) {
    s += 'Savings Goals:\n' + ctx.goals
      .map((g) => `  ${g.name}: ${g.currency || '₹'}${g.saved}/${g.currency || '₹'}${g.target}`)
      .join('\n') + '\n';
  }
  if (ctx.currency) s += `Currency: ${ctx.currency}\n`;
  if (ctx.totalBalance !== undefined) s += `Total balance: ${ctx.currency || '₹'}${ctx.totalBalance}\n`;
  if (ctx.monthlyIncome !== undefined) s += `Monthly income: ${ctx.currency || '₹'}${ctx.monthlyIncome}\n`;
  if (ctx.monthlyExpense !== undefined) s += `Monthly expenses: ${ctx.currency || '₹'}${ctx.monthlyExpense}\n`;
  return s;
}

// ── AI helper: returns baseUrl, enabled, apiKey ───────────────────────────────
function aiConfig() {
  const enabled = process.env.AI_ENABLED === 'true' || process.env.AI_ENABLED === '1';
  const apiKey = process.env.AI_API_KEY;
  const baseUrl = (process.env.AI_BASE_URL || 'https://integrate.api.nvidia.com/v1').replace(/\/$/, '');
  const model = process.env.AI_MODEL || 'deepseek-ai/deepseek-v4-flash';
  return { enabled, apiKey, baseUrl, model };
}

// ── Mock reply generator ──────────────────────────────────────────────────────
function generateMockReply(userMessage) {
  const msg = userMessage.toLowerCase();
  if (msg.includes('spend') || msg.includes('expense') || msg.includes('money'))
    return `Based on your recent transactions, you've spent approximately ₹12,500 this month. Your largest expense category is Food & Dining at ₹4,200. Consider setting a budget to track your spending more effectively.`;
  if (msg.includes('budget') || msg.includes('save') || msg.includes('saving'))
    return `Great question! Here's my advice:\n\n1. **Track all expenses** — Start by categorizing every rupee you spend.\n2. **50/30/20 Rule** — 50% needs, 30% wants, 20% savings.\n3. **Set specific goals** — Save ₹5,000/month for an emergency fund.\n\nWould you like me to help you create a budget?`;
  if (msg.includes('hello') || msg.includes('hi') || msg.includes('hey'))
    return `Hello! 👋 I'm Lumina, your AI financial assistant for FinTrack Pro. I can help you with:\n- 📊 Understanding your spending patterns\n- 💰 Creating and managing budgets\n- 🎯 Tracking savings goals\n- 💡 Personalized financial insights\n\nWhat would you like to know about your finances today?`;
  if (msg.includes('invest') || msg.includes('stock') || msg.includes('mutual'))
    return `While I can't provide specific advice, FinTrack Pro can help you:\n\n1. **Build an emergency fund** (3-6 months of expenses)\n2. **Track your savings progress**\n3. **Analyze your spending** to find extra money for investments\n\nConsider consulting a SEBI-registered advisor for personalised investment guidance.`;
  if (msg.includes('report') || msg.includes('summary') || msg.includes('overview'))
    return `Here's your financial overview:\n\n📊 **Monthly Summary**\n- Total Income: ₹45,000\n- Total Expenses: ₹32,500\n- Savings Rate: 27.8%\n\n🏆 **Top Spending Categories**\n1. Food & Dining: ₹8,500\n2. Transport: ₹5,200\n3. Shopping: ₹4,800\n\nKeep up the good work! Your savings rate is healthy.`;
  return `Thank you for your message. I'm analyzing your financial data to provide personalized insights. In the meantime, here are some tips:\n\n- Review your weekly spending to identify patterns\n- Set up automatic savings transfers\n- Track your subscriptions to avoid unused charges\n\nIs there something specific about your finances you'd like to explore?`;
}

// ── Closed-loop outbound guardrail ──────────────────────────────────────────
// Defense-in-depth: even though the model has no tools/web access and is
// instructed to stay internal-only, we scrub the reply for tell-tale signs of
// external/real-world leakage before it ever reaches the client. This is a
// safety net, NOT the primary control (that is the prompt + no-tools call).
const _URL_RE = /https?:\/\/\S+|www\.\S+/gi;
const _TICKER_RE = /\$[A-Z]{1,5}\b/g;
const _EXT_PHRASE_RE = /\b(as of (today|now|currently)|according to (the web|google|recent|today's|current events)|live (price|rate|news)|real[-\s]?time (market|web|news))\b/gi;

function enforceClosedLoop(text) {
  if (typeof text !== 'string' || text.length === 0) return text;
  let out = text.replace(_URL_RE, '[link removed]');
  out = out.replace(_TICKER_RE, '[symbol removed]');
  out = out.replace(_EXT_PHRASE_RE, '[external reference removed]');
  return out;
}

// ── POST /ai/chat ─────────────────────────────────────────────────────────────
router.post('/chat', async (req, res, next) => {
  try {
    const { message, conversationId } = req.body;
    const userMessage = typeof message === 'string' ? message.trim() : '';

    if (!userMessage) return res.status(400).json({ ok: false, error: 'message is required' });

    // Build contextual system prompt from the user's REAL data in PostgreSQL.
    // We intentionally ignore any client-supplied `context` to guarantee the
    // model only ever sees verified internal data (no external/forged values).
    const dbContext = await buildUserContext(req.userId);
    const contextStr = contextToText(dbContext);

    // Store conversation in DB
    let convId = conversationId;
    if (!convId) {
      const c = await pool.query(
        'INSERT INTO ai_conversations (user_id, title) VALUES ($1, $2) RETURNING id',
        [req.userId, userMessage.substring(0, 80)],
      );
      convId = c.rows[0].id;
    }

    // Call AI
    const { reply, provider } = await callAI({
      userMessage: contextStr ? `${contextStr}\n\nUser question: ${userMessage}` : userMessage,
    });

    const finalReply = enforceClosedLoop(reply || generateMockReply(userMessage));

    // Save messages
    await pool.query(
      'INSERT INTO ai_messages (conversation_id, user_id, role, content) VALUES ($1,$2,$3,$4)',
      [convId, req.userId, 'user', userMessage],
    );
    await pool.query(
      'INSERT INTO ai_messages (conversation_id, user_id, role, content, provider) VALUES ($1,$2,$3,$4,$5)',
      [convId, req.userId, 'assistant', finalReply, provider],
    );

    // Update conversation title with first user message if needed
    await pool.query(
      'UPDATE ai_conversations SET title = $1, updated_at = NOW() WHERE id = $2',
      [userMessage.substring(0, 80), convId],
    );

    res.json({ ok: true, message: finalReply, conversationId: convId, provider });
  } catch (err) { next(err); }
});

// ── POST /ai/receipt ──────────────────────────────────────────────────────────
router.post('/receipt', async (req, res, next) => {
  try {
    const { image, text, rawText } = req.body;
    const receiptText = image || text || rawText;

    if (!receiptText) return res.status(400).json({ ok: false, error: 'image (base64) or text is required' });

    const { enabled, apiKey, baseUrl, model } = aiConfig();

    if (!enabled || !apiKey || isProviderKnownDead()) {
      return res.json({
        ok: true,
        receipt: {
          merchant: 'Receipt Store',
          total: 250.00,
          subtotal: 220.00,
          tax: 30.00,
          date: new Date().toISOString().split('T')[0],
          currency: 'INR',
          category: 'Shopping',
          items: [
            { name: 'Item A', qty: 2, price: 60.00 },
            { name: 'Item B', qty: 1, price: 100.00 },
          ],
          rawText: '[Mock] Receipt text — AI_ENABLED is false or no API key',
        },
      });
    }

    let content = '';
    try {
      const response = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: `You are a receipt scanner for FinTrack Pro. You extract structured data from the receipt image/text the user provides. INTERNAL DATA ONLY: you must NOT look up, fetch, or invent any external/real-world information (live prices, exchange rates, merchant databases, web data). Use only what is printed on the receipt.

Return ONLY valid JSON (no prose, no markdown code fences) with this exact shape:
{
  "merchant": "Store Name",
  "total": 125.50,
  "subtotal": 110.00,
  "tax": 15.50,
  "date": "2026-01-15",
  "currency": "INR",
  "category": "Shopping",
  "items": [
    { "name": "Item Name", "qty": 2, "price": 30.00 }
  ],
  "rawText": "Raw text from receipt"
}
If you cannot read the receipt, set rawText to "Unable to parse" and merchant to "Unknown".
Allowed categories: Food & Dining, Shopping, Grocery, Transport, Health, Entertainment, Utilities, Education, Rent, Other.`,
            },
            {
              role: 'user',
              content: image ? 'Extract receipt data from this image. Return EXACTLY the JSON structure.' : `Extract receipt data from this text:\n${receiptText}\nReturn EXACTLY the JSON structure.`,
            },
          ],
          temperature: 0.1,
          max_tokens: 500,
          response_format: { type: 'json_object' },
        }),
      });

      const data = await response.json().catch(() => ({}));
      content = data?.choices?.[0]?.message?.content?.trim() || '';
      if (content) markProviderAlive();
    } catch (err) {
      markProviderDead();
      console.warn('AI receipt provider error, fallback to mock:', err.message);
      content = '';
    }

    let receipt;
    try {
      let jsonStr = content;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      else if (jsonStr.startsWith('```')) jsonStr = jsonStr.replace(/^```\s*/, '').replace(/\s*```$/, '');
      receipt = JSON.parse(jsonStr);
    } catch {
      receipt = {
        merchant: 'Scanned Receipt',
        total: 0, subtotal: 0, tax: 0,
        date: new Date().toISOString().split('T')[0],
        currency: 'INR', category: 'Other', items: [], rawText: content || '[Mock] Could not parse receipt — AI provider unreachable',
      };
    }

    // Normalize numeric/date fields so the Flutter model never sees nulls.
    receipt.merchant = typeof receipt.merchant === 'string' ? receipt.merchant : 'Scanned Receipt';
    receipt.total = Number(receipt.total) || 0;
    receipt.subtotal = receipt.subtotal == null ? receipt.total : Number(receipt.subtotal) || 0;
    receipt.tax = receipt.tax == null ? Math.max(0, Number(receipt.total) - Number(receipt.subtotal || 0)) : Number(receipt.tax) || 0;
    receipt.date = typeof receipt.date === 'string' && receipt.date ? receipt.date : new Date().toISOString().split('T')[0];
    receipt.currency = typeof receipt.currency === 'string' && receipt.currency ? receipt.currency : 'INR';
    receipt.category = typeof receipt.category === 'string' && receipt.category ? receipt.category : 'Other';
    receipt.items = Array.isArray(receipt.items) ? receipt.items : [];
    receipt.rawText = typeof receipt.rawText === 'string' ? receipt.rawText : '';

    res.json({ ok: true, receipt });
  } catch (err) { next(err); }
});

// ── POST /ai/voice ────────────────────────────────────────────────────────────
router.post('/voice', async (req, res, next) => {
  try {
    const { audio, transcript, today } = req.body;
    const rawText = typeof transcript === 'string' ? transcript : '';
    const date = today || new Date().toISOString().split('T')[0];

    const { enabled, apiKey, baseUrl, model } = aiConfig();

    if (!enabled || !apiKey || isProviderKnownDead()) {
      return res.json({
        ok: true,
        transcript: rawText || 'Spent 500 rupees on lunch',
        transaction: {
          type: 'expense', amount: 500, merchant: 'Restaurant',
          category: 'Food & Dining', date, note: 'Voice entry',
        },
      });
    }

    const trans = rawText || 'User recorded audio';

    let content = '';
    try {
      const response = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: `You are a transaction parser for FinTrack Pro. Parse the user's speech/text into a structured transaction. INTERNAL DATA ONLY: never fetch or invent external/real-world information (live rates, prices, merchant lookups, web data). Use only what the user said.

Return ONLY valid JSON (no prose, no markdown code fences).
Rules:
- Categories: Food & Dining, Grocery, Transport, Health, Entertainment, Utilities, Education, Rent, Shopping, Income, Salary, Freelance, Commission, Other
- Type: "expense" or "income"
- Format: { "type": "expense", "amount": 500, "merchant": "Receipt Store", "category": "Food & Dining", "date": "${date}", "note": "Lunch" }`,
            },
            { role: 'user', content: `Parse this into a transaction: "${trans}"` },
          ],
          temperature: 0.1,
          max_tokens: 200,
          response_format: { type: 'json_object' },
        }),
      });

      const data = await response.json().catch(() => ({}));
      content = data?.choices?.[0]?.message?.content?.trim() || '';
    } catch (err) {
      markProviderDead();
      console.warn('AI voice provider error, fallback to mock:', err.message);
      content = '';
    }

    let tx;
    try {
      let jsonStr = content;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      else if (jsonStr.startsWith('```')) jsonStr = jsonStr.replace(/^```\s*/, '').replace(/\s*```$/, '');
      tx = JSON.parse(jsonStr);
      tx.date = tx.date || date;
      tx.type = tx.type || 'expense';
      tx.category = tx.category || 'Other';
      tx.note = tx.note || '';
    } catch {
      tx = { type: 'expense', amount: 500, merchant: 'Entry', category: 'Other', date, note: 'Voice translation' };
    }

    res.json({ ok: true, transcript: trans, transaction: tx });
  } catch (err) { next(err); }
});

// ── POST /ai/insights ──────────────────────────────────────────────────────────
router.post('/insights', async (req, res, next) => {
  try {
    const { transactions = [], budgets = [], goals = [], currency = 'INR', categoryNameMap = {} } = req.body;

    const { enabled, apiKey, baseUrl, model } = aiConfig();

    if (!enabled || !apiKey) {
      return res.json({
        ok: true,
        payload: {
          cards: [
            { id: '1', kind: 'tip', title: 'Spending Alert', body: 'Your Dining expenses are 20% higher this month.', icon: 'restaurant', accent: 'iris', metric: '+20%' },
            { id: '2', kind: 'forecast', title: 'End of Month Forecast', body: 'You are on track to save ₹5,000 this month.', icon: 'trending_up', accent: 'green', metric: '₹5,000' },
          ],
          forecast: { endOfMonthExpense: 35000, confidence: 'medium', daysProjected: 15, trend: 'slightly_up' },
          weeklySummary: { weekSpent: 8500, weekIncome: 25000, topCategory: 'Food & Dining', topCategoryAmount: 3200, vsLastWeekPct: 12 },
          anomalies: [],
        },
      });
    }

    const totalSpent = transactions.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);
    const totalIncome = transactions.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);
    const expenseSummary = transactions.filter(t => t.type === 'expense').slice(0, 20)
      .map(t => `${t.merchant || ''}: ₹${t.amount} (${categoryNameMap[t.categoryId] || t.categoryId || 'other'})`)
      .join('\n');

    let content = '';
    try {
      const response = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: `You are an AI Insights engine for FinTrack Pro. Analyze the transaction data provided and return structured JSON. The user currency is ₹ (INR). INTERNAL DATA ONLY: base every number on the user's own transactions supplied below. Never fetch or invent external/real-world figures (live rates, market data, web sources).

Return ONLY valid JSON with this shape:
{
  "cards": [
    { "id": "1", "kind": "tip", "title": "...", "body": "...", "icon": "lightbulb", "accent": "iris", "metric": "+15%" },
    { "id": "2", "kind": "forecast", "title": "...", "body": "...", "icon": "trending_up", "accent": "green", "metric": "₹5,000" }
  ],
  "forecast": { "endOfMonthExpense": 45000, "confidence": "medium", "daysProjected": 15, "trend": "slightly_up" },
  "weeklySummary": { "weekSpent": 8500, "weekIncome": 25000, "topCategory": "Food & Dining", "topCategoryAmount": 3200, "vsLastWeekPct": 12 },
  "anomalies": [ { "date": "2026-07-20", "merchant": "Uber", "amount": 5000, "reason": "Unusual high transport spending" } ]
}

Provide at least 2 insight cards. Use the user's data to personalize ALL values. Categories: Food & Dining, Grocery, Transport, Health, Entertainment, Utilities, Education, Rent, Shopping, Other.`,
            },
            {
              role: 'user',
              content: `Analyze my spending:\nTotal spent: ₹${totalSpent}\nTotal income: ₹${totalIncome}\nExpenses:\n${expenseSummary}`,
            },
          ],
          temperature: 0.5,
          max_tokens: 1000,
          response_format: { type: 'json_object' },
        }),
      });

      const data = await response.json().catch(() => ({}));
      content = data?.choices?.[0]?.message?.content?.trim() || '';
    } catch (err) {
      console.warn('AI insights provider error, fallback to mock:', err.message);
      content = '';
    }

    let payload;
    try {
      let jsonStr = content;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      else if (jsonStr.startsWith('```')) jsonStr = jsonStr.replace(/^```\s*/, '').replace(/\s*```$/, '');
      payload = JSON.parse(jsonStr);
    } catch {
      payload = {
        cards: [
          { id: '1', kind: 'tip', title: 'Spending Visible', body: `Total spent this period: ₹${totalSpent}`, icon: 'lightbulb', accent: 'iris', metric: `₹${totalSpent}` },
          { id: '2', kind: 'forecast', title: 'Forecast', body: `Income tracked: ₹${totalIncome}`, icon: 'trending_up', accent: 'green', metric: `₹${totalIncome}` },
        ],
        forecast: { endOfMonthExpense: totalSpent * 2, confidence: 'low', daysProjected: 15, trend: 'flat' },
        weeklySummary: { weekSpent: totalSpent, weekIncome: totalIncome, topCategory: 'other', topCategoryAmount: 0, vsLastWeekPct: 0 },
        anomalies: [],
      };
    }

    res.json({ ok: true, payload });
  } catch (err) { next(err); }
});

// ── POST /ai/weekly-summary ────────────────────────────────────────────────────
router.post('/weekly-summary', async (req, res, next) => {
  try {
    const { transactions = [], categoryNameMap = {}, currency = 'INR' } = req.body;

    const { enabled, apiKey, baseUrl, model } = aiConfig();

    if (!enabled || !apiKey || transactions.length === 0) {
      return res.json({
        ok: true,
        summary: {
          title: 'Weekly Headlines',
          body: "Add some transactions this week and I'll show your summary!",
          highlights: ['No transactions this week yet.', 'Start tracking to see insights.'],
        },
      });
    }

    const totalSpent = transactions.filter(t => t.type === 'expense').reduce((s, t) => s + (t.amount || 0), 0);
    const totalIncome = transactions.filter(t => t.type === 'income').reduce((s, t) => s + (t.amount || 0), 0);

    let content = '';
    try {
      const response = await fetchWithTimeout(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            {
              role: 'system',
              content: `You generate a weekly summary headline for FinTrack Pro. Currency is ₹ (INR). INTERNAL DATA ONLY: use only the transactions supplied. Never fetch or invent external/real-world figures. Return ONLY valid JSON (no prose, no markdown fences):
{ "title": "Short heading", "body": "One-paragraph summary", "highlights": ["Highlight 1", "Highlight 2", "Highlight 3"] }`,
            },
            {
              role: 'user',
              content: `Generate a concise weekly summary:\nTotal spent: ₹${totalSpent}\nTotal income: ₹${totalIncome}\nNumber of transactions: ${transactions.length}`,
            },
          ],
          temperature: 0.5,
          max_tokens: 500,
          response_format: { type: 'json_object' },
        }),
      });

      const data = await response.json().catch(() => ({}));
      content = data?.choices?.[0]?.message?.content?.trim() || '';
    } catch (err) {
      console.warn('AI weekly-summary provider error, fallback to mock:', err.message);
      content = '';
    }

    let summaryObj;
    try {
      let jsonStr = content;
      if (jsonStr.startsWith('```json')) jsonStr = jsonStr.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      else if (jsonStr.startsWith('```')) jsonStr = jsonStr.replace(/^```\s*/, '').replace(/\s*```$/, '');
      summaryObj = JSON.parse(jsonStr);
    } catch {
      summaryObj = {
        title: 'Weekly Summary',
        body: `You spent ₹${totalSpent} this week. Total income was ₹${totalIncome}.`,
        highlights: [
          `Total spending: ₹${totalSpent}`,
          `Total income: ₹${totalIncome}`,
          `${transactions.length} transactions this period.`,
        ],
      };
    }

    res.json({ ok: true, summary: summaryObj });
  } catch (err) { next(err); }
});

// ── GET /ai/conversations ────────────────────────────────────────────────────────
router.get('/conversations', async (req, res, next) => {
  try {
    const conversations = await pool.query(
      'SELECT * FROM ai_conversations WHERE user_id = $1 ORDER BY updated_at DESC',
      [req.userId],
    );
    res.json(conversations.rows.map(r => ({
      id: r.id,
      title: r.title,
      createdAt: r.created_at?.toISOString?.() ?? r.created_at,
      updatedAt: r.updated_at?.toISOString?.() ?? r.updated_at,
    })));
  } catch (err) { next(err); }
});

// UUID format check so a bad :id returns 400 instead of a Postgres 500.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

router.get('/conversations/:id', async (req, res, next) => {
  try {
    if (!UUID_RE.test(req.params.id)) {
      return res.status(400).json({ ok: false, error: 'Invalid conversation id' });
    }
    const conv = await pool.query('SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (conv.rows.length === 0) return res.status(404).json({ ok: false, error: 'Conversation not found' });

    const messages = await pool.query(
      'SELECT * FROM ai_messages WHERE conversation_id = $1 ORDER BY created_at ASC',
      [req.params.id],
    );

    res.json({
      id: conv.rows[0].id,
      title: conv.rows[0].title,
      messages: messages.rows.map(m => ({
        id: m.id,
        role: m.role,
        content: m.content,
        createdAt: m.created_at?.toISOString?.() ?? m.created_at,
      })),
      createdAt: conv.rows[0].created_at?.toISOString?.() ?? conv.rows[0].created_at,
      updatedAt: conv.rows[0].updated_at?.toISOString?.() ?? conv.rows[0].updated_at,
    });
  } catch (err) { next(err); }
});

router.delete('/conversations/:id', async (req, res, next) => {
  try {
    if (!UUID_RE.test(req.params.id)) {
      return res.status(400).json({ ok: false, error: 'Invalid conversation id' });
    }
    await pool.query('DELETE FROM ai_messages WHERE conversation_id = $1 AND user_id = $2', [req.params.id, req.userId]);
    await pool.query('DELETE FROM ai_conversations WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    res.json({ ok: true, message: 'Conversation deleted' });
  } catch (err) { next(err); }
});

module.exports = router;