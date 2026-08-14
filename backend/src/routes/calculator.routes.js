const { Router } = require('express');
const router = Router();

// Calculator is a utility feature — no auth required
// All calculations happen client-side; the backend just provides the compute engine for expensive ones if needed.
// Most calls can be handled locally in Flutter, but we provide a server-side endpoint for savings projections and such.

// ── POST /api/calculator/savings-compound ───────────────────────────────────
router.post('/savings-compound', (req, res) => {
  try {
    const { principal = 0, monthlyContribution = 0, annualRate = 0, years = 1 } = req.body;

    if (years <= 0 || years > 100) return res.status(400).json({ ok: false, error: 'Years must be between 1-100' });

    const r = annualRate / 100 / 12; // monthly rate
    const n = years * 12;
    let futureValue = principal * Math.pow(1 + r, n);

    if (monthlyContribution > 0 && r > 0) {
      futureValue += monthlyContribution * ((Math.pow(1 + r, n) - 1) / r);
    } else if (monthlyContribution > 0 && r === 0) {
      futureValue += monthlyContribution * n;
    }

    const totalInvested = principal + monthlyContribution * n;
    const totalReturns = futureValue - totalInvested;

    res.json({
      ok: true,
      result: {
        futureValue: Math.round(futureValue * 100) / 100,
        totalInvested: Math.round(totalInvested * 100) / 100,
        totalReturns: Math.round(totalReturns * 100) / 100,
        years,
        annualRate,
        monthlyContribution,
      },
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message || 'Invalid input' });
  }
});

// ── POST /api/calculator/loan-emi ───────────────────────────────────────────
router.post('/loan-emi', (req, res) => {
  try {
    const { principal = 0, annualRate = 0, years = 1 } = req.body;

    if (years <= 0 || years > 50) return res.status(400).json({ ok: false, error: 'Years must be between 1-50' });

    const r = annualRate / 100 / 12;
    const n = years * 12;

    let emi = 0;
    if (r > 0) {
      emi = (principal * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);
    } else {
      emi = principal / n;
    }

    const totalPayment = emi * n;
    const totalInterest = totalPayment - principal;

    res.json({
      ok: true,
      result: {
        emi: Math.round(emi * 100) / 100,
        totalPayment: Math.round(totalPayment * 100) / 100,
        totalInterest: Math.round(totalInterest * 100) / 100,
        years,
        annualRate,
      },
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message || 'Invalid input' });
  }
});

// ── POST /api/calculator/split-bill ─────────────────────────────────────────
router.post('/split-bill', (req, res) => {
  try {
    const { total = 0, people = 2, tips = 0, tax = 0 } = req.body;

    if (people <= 0) return res.status(400).json({ ok: false, error: 'People must be >= 1' });

    const grandTotal = total + tips + tax;
    const perPerson = grandTotal / people;

    res.json({
      ok: true,
      result: {
        total: Math.round(total * 100) / 100,
        tips: Math.round(tips * 100) / 100,
        tax: Math.round(tax * 100) / 100,
        grandTotal: Math.round(grandTotal * 100) / 100,
        perPerson: Math.round(perPerson * 100) / 100,
        people,
      },
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message || 'Invalid input' });
  }
});

// ── POST /api/calculator/tip ────────────────────────────────────────
router.post('/tip', (req, res) => {
  try {
    const { amount = 0, tipPercent = 0, split = 1 } = req.body;

    if (amount < 0) return res.status(400).json({ ok: false, error: 'Amount must be >= 0' });
    if (split < 1) return res.status(400).json({ ok: false, error: 'Split must be >= 1' });

    const tipAmount = amount * (tipPercent / 100);
    const total = amount + tipAmount;
    const perPerson = split > 0 ? total / split : total;

    res.json({
      ok: true,
      result: {
        amount: Math.round(amount * 100) / 100,
        tipPercent,
        tipAmount: Math.round(tipAmount * 100) / 100,
        total: Math.round(total * 100) / 100,
        split,
        perPerson: Math.round(perPerson * 100) / 100,
      },
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message || 'Invalid input' });
  }
});

// ── POST /api/calculator/fire ───────────────────────────────────────────────
router.post('/fire', (req, res) => {
  try {
    const { currentAge = 25, retirementAge = 60, monthlyExpense = 30000, inflationRate = 6.0, currentSavings = 0 } = req.body;

    const yearsToRetire = retirementAge - currentAge;
    if (yearsToRetire <= 0) return res.status(400).json({ ok: false, error: 'Retirement age must be > current age' });

    const inflationMultiplier = Math.pow(1 + inflationRate / 100, yearsToRetire);
    const monthlyExpenseAtRetirement = monthlyExpense * inflationMultiplier;
    const yearlyExpense = monthlyExpenseAtRetirement * 12;

    // 4% rule: corpus = yearly_expense / 0.04
    const requiredCorpus = yearlyExpense / 0.04;

    res.json({
      ok: true,
      result: {
        requiredCorpus: Math.round(requiredCorpus),
        monthlyExpenseAtRetirement: Math.round(monthlyExpenseAtRetirement),
        yearsToRetire,
        inflationRate,
        currentSavings,
      },
    });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message || 'Invalid input' });
  }
});

module.exports = router;