import '../models/models.dart';

/// Seed data — faithfully mirrored from the web app's seed.ts.
/// Calendar-aware so the current month always shows healthy data.

const _c = _Palette._();

class _Palette {
  const _Palette._();
  final iris = '#6C5CE7';
  final cyan = '#00D2FF';
  final green = '#00E676';
  final amber = '#FFB74D';
  final red = '#FF5252';
  final blue = '#448AFF';
  final pink = '#FF6FB5';
  final teal = '#26C6DA';
  final orange = '#FF8A65';
  final violet = '#B388FF';
  final lime = '#C6FF00';
  final rose = '#FF7AA2';
}

DateTime _thisMonthDay(int day, [int hour = 10]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, day.clamp(1, now.day), hour);
}

DateTime _dateInMonth(int offset, int day, [int hour = 10]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month - offset, day.clamp(1, 28), hour);
}

DateTime _daysAgo(int n) {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, 10).subtract(Duration(days: n));
}

DateTime _daysAhead(int n) {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day, 10).add(Duration(days: n));
}

final List<Category> defaultCategories = [
  Category(id: 'cat-food', name: 'Food & Dining', icon: 'restaurant', color: _c.orange, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-grocery', name: 'Groceries', icon: 'shopping_cart', color: _c.green, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-transport', name: 'Transport', icon: 'directions_car', color: _c.cyan, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-shopping', name: 'Shopping', icon: 'shopping_bag', color: _c.pink, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-bills', name: 'Bills & Utilities', icon: 'receipt_long', color: _c.amber, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-rent', name: 'Rent & Housing', icon: 'home', color: _c.violet, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-health', name: 'Health', icon: 'favorite', color: _c.red, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-entertain', name: 'Entertainment', icon: 'movie', color: _c.iris, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-edu', name: 'Education', icon: 'school', color: _c.blue, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-travel', name: 'Travel', icon: 'flight', color: _c.teal, kind: CategoryKind.expense, budgetable: true),
  Category(id: 'cat-invest', name: 'Investments', icon: 'trending_up', color: _c.lime, kind: CategoryKind.both, budgetable: false),
  Category(id: 'cat-salary', name: 'Salary', icon: 'wallet', color: _c.green, kind: CategoryKind.income, budgetable: false),
  Category(id: 'cat-freelance', name: 'Freelance', icon: 'laptop', color: _c.cyan, kind: CategoryKind.income, budgetable: false),
  Category(id: 'cat-gift', name: 'Gifts', icon: 'card_giftcard', color: _c.rose, kind: CategoryKind.both, budgetable: false),
  Category(id: 'cat-other', name: 'Other', icon: 'more_horiz', color: _c.amber, kind: CategoryKind.both, budgetable: false),
];

final List<Account> defaultAccounts = [
  Account(id: 'acc-hdfc', name: 'HDFC Savings', kind: 'bank', balance: 184250, color: _c.iris, institution: 'HDFC Bank'),
  Account(id: 'acc-cash', name: 'Cash Wallet', kind: 'cash', balance: 8400, color: _c.green),
  Account(id: 'acc-paytm', name: 'Paytm Wallet', kind: 'wallet', balance: 3120, color: _c.cyan),
  Account(id: 'acc-zerodha', name: 'Zerodha', kind: 'investment', balance: 268900, color: _c.blue, institution: 'Zerodha'),
];

final List<Transaction> seedTransactions = [
  // Current month
  Transaction(id: 't-i1', type: TxType.income, amount: 92000, categoryId: 'cat-salary', account: 'acc-hdfc', date: _thisMonthDay(1), merchant: 'Acme Corp', note: 'Monthly salary', recurring: true, createdAt: _thisMonthDay(1)),
  Transaction(id: 't-i2', type: TxType.income, amount: 18500, categoryId: 'cat-freelance', account: 'acc-hdfc', date: _thisMonthDay(2), merchant: 'Upwork', note: 'Logo design project', createdAt: _thisMonthDay(2)),
  Transaction(id: 't-e1', type: TxType.expense, amount: 18500, categoryId: 'cat-rent', account: 'acc-hdfc', date: _thisMonthDay(1), merchant: 'Landlord', note: 'Monthly rent', recurring: true, createdAt: _thisMonthDay(1)),
  Transaction(id: 't-e2', type: TxType.expense, amount: 6500, categoryId: 'cat-invest', account: 'acc-zerodha', date: _thisMonthDay(1), merchant: 'Zerodha', note: 'Mutual fund SIP', recurring: true, createdAt: _thisMonthDay(1)),
  Transaction(id: 't-e3', type: TxType.expense, amount: 899, categoryId: 'cat-bills', account: 'acc-hdfc', date: _thisMonthDay(1), merchant: 'Airtel', note: 'Internet', recurring: true, createdAt: _thisMonthDay(1)),
  Transaction(id: 't-e4', type: TxType.expense, amount: 1280, categoryId: 'cat-grocery', account: 'acc-hdfc', date: _thisMonthDay(2), merchant: 'BigBasket', createdAt: _thisMonthDay(2)),
  Transaction(id: 't-e5', type: TxType.expense, amount: 540, categoryId: 'cat-food', account: 'acc-paytm', date: _thisMonthDay(2), merchant: 'Swiggy', note: 'Dinner', createdAt: _thisMonthDay(2)),
  Transaction(id: 't-e6', type: TxType.expense, amount: 220, categoryId: 'cat-transport', account: 'acc-paytm', date: _thisMonthDay(2), merchant: 'Uber', note: 'Office commute', createdAt: _thisMonthDay(2)),
  Transaction(id: 't-e7', type: TxType.expense, amount: 3499, categoryId: 'cat-shopping', account: 'acc-hdfc', date: _thisMonthDay(2), merchant: 'Myntra', note: 'Jacket', createdAt: _thisMonthDay(2)),
  Transaction(id: 't-e8', type: TxType.expense, amount: 1299, categoryId: 'cat-entertain', account: 'acc-hdfc', date: _thisMonthDay(2), merchant: 'BookMyShow', note: 'Movie + snacks', createdAt: _thisMonthDay(2)),
  // Previous month
  Transaction(id: 't-i3', type: TxType.income, amount: 92000, categoryId: 'cat-salary', account: 'acc-hdfc', date: _dateInMonth(1, 1), merchant: 'Acme Corp', recurring: true, createdAt: _dateInMonth(1, 1)),
  Transaction(id: 't-i4', type: TxType.income, amount: 12500, categoryId: 'cat-freelance', account: 'acc-hdfc', date: _dateInMonth(1, 12), merchant: 'Fiverr', createdAt: _dateInMonth(1, 12)),
  Transaction(id: 't-e9', type: TxType.expense, amount: 18500, categoryId: 'cat-rent', account: 'acc-hdfc', date: _dateInMonth(1, 3), merchant: 'Landlord', recurring: true, createdAt: _dateInMonth(1, 3)),
  Transaction(id: 't-e10', type: TxType.expense, amount: 6500, categoryId: 'cat-invest', account: 'acc-zerodha', date: _dateInMonth(1, 5), merchant: 'Zerodha', recurring: true, createdAt: _dateInMonth(1, 5)),
  Transaction(id: 't-e11', type: TxType.expense, amount: 899, categoryId: 'cat-bills', account: 'acc-hdfc', date: _dateInMonth(1, 6), merchant: 'Airtel', recurring: true, createdAt: _dateInMonth(1, 6)),
  Transaction(id: 't-e12', type: TxType.expense, amount: 2400, categoryId: 'cat-bills', account: 'acc-hdfc', date: _dateInMonth(1, 8), merchant: 'BESCOM', note: 'Electricity', recurring: true, createdAt: _dateInMonth(1, 8)),
  Transaction(id: 't-e13', type: TxType.expense, amount: 450, categoryId: 'cat-food', account: 'acc-cash', date: _dateInMonth(1, 9), merchant: 'Cafe Coffee Day', createdAt: _dateInMonth(1, 9)),
  Transaction(id: 't-e14', type: TxType.expense, amount: 5400, categoryId: 'cat-travel', account: 'acc-hdfc', date: _dateInMonth(1, 18), merchant: 'IRCTC', note: 'Weekend trip', createdAt: _dateInMonth(1, 18)),
  Transaction(id: 't-e15', type: TxType.expense, amount: 2199, categoryId: 'cat-shopping', account: 'acc-hdfc', date: _dateInMonth(1, 20), merchant: 'Amazon', note: 'Headphones', createdAt: _dateInMonth(1, 20)),
  Transaction(id: 't-e16', type: TxType.expense, amount: 2200, categoryId: 'cat-food', account: 'acc-paytm', date: _dateInMonth(1, 27), merchant: 'Weekend dining', createdAt: _dateInMonth(1, 27)),
  // Two months ago
  Transaction(id: 't-i6', type: TxType.income, amount: 92000, categoryId: 'cat-salary', account: 'acc-hdfc', date: _dateInMonth(2, 1), merchant: 'Acme Corp', recurring: true, createdAt: _dateInMonth(2, 1)),
  Transaction(id: 't-e25', type: TxType.expense, amount: 18500, categoryId: 'cat-rent', account: 'acc-hdfc', date: _dateInMonth(2, 3), merchant: 'Landlord', recurring: true, createdAt: _dateInMonth(2, 3)),
  Transaction(id: 't-e29', type: TxType.expense, amount: 3500, categoryId: 'cat-grocery', account: 'acc-hdfc', date: _dateInMonth(2, 11), merchant: 'BigBasket', createdAt: _dateInMonth(2, 11)),
  Transaction(id: 't-e30', type: TxType.expense, amount: 2800, categoryId: 'cat-entertain', account: 'acc-hdfc', date: _dateInMonth(2, 15), merchant: 'Concert', createdAt: _dateInMonth(2, 15)),
];

final List<Budget> defaultBudgets = [
  Budget(id: 'b1', categoryId: 'cat-food', limit: 6000, period: BudgetPeriod.monthly, rollover: false, createdAt: _daysAgo(30)),
  Budget(id: 'b2', categoryId: 'cat-grocery', limit: 5000, period: BudgetPeriod.monthly, rollover: true, createdAt: _daysAgo(30)),
  Budget(id: 'b3', categoryId: 'cat-transport', limit: 2500, period: BudgetPeriod.monthly, rollover: false, createdAt: _daysAgo(30)),
  Budget(id: 'b4', categoryId: 'cat-shopping', limit: 4000, period: BudgetPeriod.monthly, rollover: false, createdAt: _daysAgo(30)),
  Budget(id: 'b5', categoryId: 'cat-bills', limit: 4000, period: BudgetPeriod.monthly, rollover: false, createdAt: _daysAgo(30)),
  Budget(id: 'b6', categoryId: 'cat-entertain', limit: 2500, period: BudgetPeriod.monthly, rollover: false, createdAt: _daysAgo(30)),
];

final List<SavingsGoal> defaultGoals = [
  SavingsGoal(id: 'g1', name: 'Emergency Fund', target: 150000, saved: 92500, deadline: _daysAhead(120), icon: 'verified_user', color: _c.green, createdAt: _daysAgo(60)),
  SavingsGoal(id: 'g2', name: 'Japan Trip 2025', target: 220000, saved: 78000, deadline: _daysAhead(210), icon: 'flight', color: _c.cyan, createdAt: _daysAgo(45)),
  SavingsGoal(id: 'g3', name: 'New MacBook Pro', target: 240000, saved: 145000, deadline: _daysAhead(75), icon: 'laptop', color: _c.iris, createdAt: _daysAgo(30)),
  SavingsGoal(id: 'g4', name: 'Home Down Payment', target: 1500000, saved: 320000, deadline: _daysAhead(720), icon: 'home', color: _c.amber, createdAt: _daysAgo(90)),
];

final List<Subscription> defaultSubscriptions = [
  Subscription(id: 's1', name: 'Netflix', amount: 649, cycle: 'monthly', nextBilling: _daysAhead(4), category: 'Entertainment', icon: 'movie', color: _c.red, active: true),
  Subscription(id: 's2', name: 'Spotify Premium', amount: 119, cycle: 'monthly', nextBilling: _daysAhead(9), category: 'Entertainment', icon: 'music_note', color: _c.green, active: true),
  Subscription(id: 's3', name: 'Google One 200GB', amount: 210, cycle: 'monthly', nextBilling: _daysAhead(12), category: 'Cloud', icon: 'cloud', color: _c.blue, active: true),
  Subscription(id: 's4', name: 'Notion Plus', amount: 850, cycle: 'monthly', nextBilling: _daysAhead(18), category: 'Productivity', icon: 'description', color: _c.iris, active: true),
  Subscription(id: 's5', name: 'Adobe Creative Cloud', amount: 1675, cycle: 'monthly', nextBilling: _daysAhead(22), category: 'Software', icon: 'palette', color: _c.pink, active: true),
  Subscription(id: 's6', name: 'Amazon Prime', amount: 1499, cycle: 'yearly', nextBilling: _daysAhead(140), category: 'Shopping', icon: 'inventory_2', color: _c.orange, active: true),
  Subscription(id: 's7', name: 'iCloud+ 50GB', amount: 75, cycle: 'monthly', nextBilling: _daysAhead(6), category: 'Cloud', icon: 'cloud', color: _c.cyan, active: false),
];

final List<Note> defaultNotes = [
  Note(id: 'n1', title: 'Tax-saving investments', body: 'Max out 80C: ELSS ₹1.5L before March. Consider NPS for extra ₹50k deduction.', color: _c.green, pinned: true, tags: const ['tax', 'investing'], createdAt: _daysAgo(12), updatedAt: _daysAgo(3)),
  Note(id: 'n2', title: 'Salary hike negotiation', body: 'Target 18% hike in Q1 review. Document shipped features + client wins.', color: _c.iris, pinned: false, tags: const ['career'], createdAt: _daysAgo(20), updatedAt: _daysAgo(20)),
  Note(id: 'n3', title: 'Refinance car loan?', body: 'Current rate 9.4%. Check HDFC for 8.6% — potential savings ~₹14k over tenure.', color: _c.amber, pinned: false, tags: const ['loan'], createdAt: _daysAgo(8), updatedAt: _daysAgo(8)),
  Note(id: 'n4', title: 'Weekly review', body: 'Cut dining spend — already at 78% of food budget mid-month.', color: _c.red, pinned: false, tags: const ['review'], createdAt: _daysAgo(2), updatedAt: _daysAgo(2)),
];

const UserProfile defaultProfile = UserProfile(
  name: 'Aarav Sharma',
  email: 'aarav.sharma@fintrack.app',
  avatarColor: '#6C5CE7',
  baseCurrency: 'INR',
  monthlyIncomeGoal: 120000,
);

final List<AppNotification> defaultNotifications = [
  AppNotification(id: 'nt1', title: 'Budget alert', body: "You've used 86% of your Food & Dining budget this month.", kind: NotificationKind.warning, read: false, createdAt: _daysAgo(0), action: const NotificationAction(label: 'Review', view: 'budget')),
  AppNotification(id: 'nt2', title: 'AI Insight', body: 'Your dining spend jumped 34% vs last month. Consider cooking 2 more meals/week to save ~₹1,800.', kind: NotificationKind.ai, read: false, createdAt: _daysAgo(1), action: const NotificationAction(label: 'Ask assistant', view: 'ai-chat')),
  AppNotification(id: 'nt3', title: 'Subscription renewal', body: 'Netflix renews in 4 days (₹649). Still watching it?', kind: NotificationKind.info, read: false, createdAt: _daysAgo(1), action: const NotificationAction(label: 'Manage', view: 'subscriptions')),
  AppNotification(id: 'nt4', title: 'Goal milestone 🎉', body: 'You hit 60% of your MacBook Pro goal. ₹95,000 to go!', kind: NotificationKind.success, read: true, createdAt: _daysAgo(3), action: const NotificationAction(label: 'View', view: 'goals')),
  AppNotification(id: 'nt5', title: 'Salary received', body: '₹92,000 credited from Acme Corp to HDFC Savings.', kind: NotificationKind.success, read: true, createdAt: _daysAgo(1)),
];

const Map<String, double> currencyRates = {
  'INR': 1, 'USD': 0.01196, 'EUR': 0.01102, 'GBP': 0.00938,
  'JPY': 1.876, 'AED': 0.0439, 'AUD': 0.0182, 'CAD': 0.0163,
};
