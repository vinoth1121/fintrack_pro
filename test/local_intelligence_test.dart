// Unit tests for the offline intelligence engine — every AI-dependent feature
// must work with no backend, no internet and no AI API key.
import 'package:flutter_test/flutter_test.dart';

import 'package:fintrack_pro/core/services/local_intelligence.dart';
import 'package:fintrack_pro/providers/fintrack_provider.dart';

void main() {
  group('parseVoiceText', () {
    test('parses a basic expense', () {
      final r = LocalIntelligence.parseVoiceText('Spent 540 on dinner at Swiggy');
      expect(r.type, 'expense');
      expect(r.amount, 540);
      expect(r.merchant, 'Swiggy');
      expect(r.category, 'Food & Dining');
    });

    test('parses income', () {
      final r = LocalIntelligence.parseVoiceText('Received 18000 from Upwork');
      expect(r.type, 'income');
      expect(r.amount, 18000);
      expect(r.merchant, 'Upwork');
      expect(r.category, 'Freelance');
    });

    test('parses rent with keyword merchant fallback', () {
      final r = LocalIntelligence.parseVoiceText('Paid 18500 rent today');
      expect(r.type, 'expense');
      expect(r.amount, 18500);
      expect(r.category, 'Rent & Housing');
    });

    test('handles currency symbols, commas and k suffix', () {
      expect(LocalIntelligence.parseVoiceText('₹1,250 groceries at BigBasket').amount, 1250);
      expect(LocalIntelligence.parseVoiceText('Rs 2.5k uber to office').amount, 2500);
      expect(LocalIntelligence.parseVoiceText('Rs 2.5k uber to office').category, 'Transport');
    });

    test('parses relative dates', () {
      final today = DateTime(2026, 8, 25);
      final r = LocalIntelligence.parseVoiceText('Spent 200 on coffee yesterday', today: today);
      expect(r.date, '2026-08-24');
    });

    test('empty text returns safe defaults, never throws', () {
      final r = LocalIntelligence.parseVoiceText('');
      expect(r.type, 'expense');
      expect(r.amount, isNull);
      expect(r.category, 'Other');
    });
  });

  group('parseReceiptText', () {
    test('extracts merchant, total, date and category', () {
      const text = 'Cafe Coffee Day\n'
          '12 MG Road\n'
          'Date: 2026-08-20\n'
          'Coffee 2 x 150.00\n'
          'Sandwich 220.00\n'
          'Subtotal 520.00\n'
          'GST 26.00\n'
          'Grand Total 546.00';
      final r = LocalIntelligence.parseReceiptText(text);
      expect(r.merchant, 'Cafe Coffee Day');
      expect(r.total, 546.0);
      expect(r.subtotal, 520.0);
      expect(r.tax, 26.0);
      expect(r.date, '2026-08-20');
      expect(r.category, 'Food & Dining');
      expect(r.items, isNotEmpty);
    });

    test('falls back to the largest amount when no TOTAL label exists', () {
      final r = LocalIntelligence.parseReceiptText('MY SHOP\nitem one 100.00\nitem two 999.95');
      expect(r.total, 999.95);
    });

    test('empty text returns safe defaults, never throws', () {
      final r = LocalIntelligence.parseReceiptText('');
      expect(r.merchant, 'Scanned Receipt');
      expect(r.total, 0);
      expect(r.category, 'Other');
      expect(r.items, isEmpty);
    });
  });

  group('assistantReply', () {
    test('empty message returns guidance without throwing', () {
      final reply = LocalIntelligence.assistantReply('  ', _emptyState(), _emptyDerived());
      expect(reply, isNotEmpty);
      expect(reply, contains('FinTrack Pro'));
    });
  });
}

// Minimal fixtures — the engine only reads plain fields.

FinTrackState _emptyState() => FinTrackState(
      categories: const [],
      accounts: const [],
      budgets: const [],
      goals: const [],
      subscriptions: const [],
      notes: const [],
      notifications: const [],
    );

DerivedData _emptyDerived() => const DerivedData(
      monthExpenses: 0,
      monthIncome: 0,
      totalExpenses: 0,
      totalIncome: 0,
      netBalance: 0,
      savingsRate: 0,
      categoryBreakdown: [],
      sparkline: [],
      budgetUsage: [],
      goalsOnTrack: 0,
      goalsTotal: 0,
      expenseDelta: 0,
      incomeDelta: 0,
      trend: [],
      budgetsOver: 0,
    );
