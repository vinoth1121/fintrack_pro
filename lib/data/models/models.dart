/// FinTrack Pro — Domain Models
/// Faithfully mirrored from the web app's types.ts.
library;

enum TxType { expense, income }
enum CategoryKind { expense, income, both }

class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final CategoryKind kind;
  final bool budgetable;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.kind,
    required this.budgetable,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String,
        color: j['color'] as String,
        kind: CategoryKind.values.firstWhere((k) => k.name == j['kind']),
        budgetable: j['budgetable'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'icon': icon, 'color': color,
        'kind': kind.name, 'budgetable': budgetable,
      };
}

class Account {
  final String id;
  final String name;
  final String kind; // bank | cash | wallet | card | investment
  final double balance;
  final String color;
  final String? institution;

  const Account({
    required this.id, required this.name, required this.kind,
    required this.balance, required this.color, this.institution,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String, name: j['name'] as String, kind: j['kind'] as String,
        balance: (j['balance'] as num).toDouble(), color: j['color'] as String,
        institution: j['institution'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'kind': kind, 'balance': balance,
        'color': color, 'institution': institution,
      };
}

class Transaction {
  final String id;
  final TxType type;
  final double amount;
  final String categoryId;
  final String account;
  final DateTime date;
  final String? note;
  final String? merchant;
  final bool recurring;
  final String? receiptId;
  final DateTime createdAt;

  const Transaction({
    required this.id, required this.type, required this.amount,
    required this.categoryId, required this.account, required this.date,
    this.note, this.merchant, this.recurring = false, this.receiptId,
    required this.createdAt,
  });

  Transaction copyWith({
    TxType? type, double? amount, String? categoryId, String? account,
    DateTime? date, String? note, String? merchant, bool? recurring,
  }) => Transaction(
    id: id, type: type ?? this.type, amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId, account: account ?? this.account,
    date: date ?? this.date, note: note ?? this.note,
    merchant: merchant ?? this.merchant, recurring: recurring ?? this.recurring,
    receiptId: receiptId, createdAt: createdAt,
  );

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        type: j['type'] == 'income' ? TxType.income : TxType.expense,
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['categoryId'] as String,
        account: j['account'] as String,
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
        merchant: j['merchant'] as String?,
        recurring: j['recurring'] as bool? ?? false,
        receiptId: j['receiptId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.name, 'amount': amount, 'categoryId': categoryId,
        'account': account, 'date': date.toIso8601String(), 'note': note,
        'merchant': merchant, 'recurring': recurring, 'receiptId': receiptId,
        'createdAt': createdAt.toIso8601String(),
      };
}

enum BudgetPeriod { monthly, weekly, yearly }

class Budget {
  final String id;
  final String categoryId;
  final double limit;
  final BudgetPeriod period;
  final bool rollover;
  final DateTime createdAt;

  const Budget({
    required this.id, required this.categoryId, required this.limit,
    required this.period, required this.rollover, required this.createdAt,
  });

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String, categoryId: j['categoryId'] as String,
        limit: (j['limit'] as num).toDouble(),
        period: BudgetPeriod.values.firstWhere((p) => p.name == j['period']),
        rollover: j['rollover'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'categoryId': categoryId, 'limit': limit,
        'period': period.name, 'rollover': rollover,
        'createdAt': createdAt.toIso8601String(),
      };
}

class SavingsGoal {
  final String id;
  final String name;
  final double target;
  final double saved;
  final DateTime? deadline;
  final String icon;
  final String color;
  final DateTime createdAt;

  const SavingsGoal({
    required this.id, required this.name, required this.target,
    required this.saved, this.deadline, required this.icon,
    required this.color, required this.createdAt,
  });

  SavingsGoal copyWith({double? saved, String? name, double? target}) => SavingsGoal(
    id: id, name: name ?? this.name, target: target ?? this.target,
    saved: saved ?? this.saved, deadline: deadline, icon: icon, color: color,
    createdAt: createdAt,
  );

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        id: j['id'] as String, name: j['name'] as String,
        target: (j['target'] as num).toDouble(), saved: (j['saved'] as num).toDouble(),
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline'] as String) : null,
        icon: j['icon'] as String, color: j['color'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'target': target, 'saved': saved,
        'deadline': deadline?.toIso8601String(), 'icon': icon, 'color': color,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Subscription {
  final String id;
  final String name;
  final double amount;
  final String cycle; // monthly | yearly | weekly
  final DateTime nextBilling;
  final String category;
  final String icon;
  final String color;
  final bool active;
  final String? note;

  const Subscription({
    required this.id, required this.name, required this.amount,
    required this.cycle, required this.nextBilling, required this.category,
    required this.icon, required this.color, required this.active, this.note,
  });

  Subscription copyWith({bool? active}) => Subscription(
    id: id, name: name, amount: amount, cycle: cycle,
    nextBilling: nextBilling, category: category, icon: icon, color: color,
    active: active ?? this.active, note: note,
  );

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String, name: j['name'] as String,
        amount: (j['amount'] as num).toDouble(), cycle: j['cycle'] as String,
        nextBilling: DateTime.parse(j['nextBilling'] as String),
        category: j['category'] as String, icon: j['icon'] as String,
        color: j['color'] as String, active: j['active'] as bool? ?? true,
        note: j['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'amount': amount, 'cycle': cycle,
        'nextBilling': nextBilling.toIso8601String(), 'category': category,
        'icon': icon, 'color': color, 'active': active, 'note': note,
      };
}

class Note {
  final String id;
  final String title;
  final String body;
  final String color;
  final bool pinned;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id, required this.title, required this.body,
    required this.color, required this.pinned, required this.tags,
    required this.createdAt, required this.updatedAt,
  });

  Note copyWith({String? title, String? body, String? color, bool? pinned, List<String>? tags}) =>
    Note(
      id: id, title: title ?? this.title, body: body ?? this.body,
      color: color ?? this.color, pinned: pinned ?? this.pinned,
      tags: tags ?? this.tags, createdAt: createdAt,
      updatedAt: DateTime.now(),
    );

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String, title: j['title'] as String, body: j['body'] as String,
        color: j['color'] as String, pinned: j['pinned'] as bool? ?? false,
        tags: (j['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'body': body, 'color': color,
        'pinned': pinned, 'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

enum NotificationKind { info, success, warning, error, ai }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationKind kind;
  final bool read;
  final DateTime createdAt;
  final NotificationAction? action;

  const AppNotification({
    required this.id, required this.title, required this.body,
    required this.kind, required this.read, required this.createdAt, this.action,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id, title: title, body: body, kind: kind,
    read: read ?? this.read, createdAt: createdAt, action: action,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String, title: j['title'] as String, body: j['body'] as String,
        kind: NotificationKind.values.firstWhere((k) => k.name == j['kind']),
        read: j['read'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        action: j['action'] != null ? NotificationAction.fromJson(j['action']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'body': body, 'kind': kind.name,
        'read': read, 'createdAt': createdAt.toIso8601String(),
        'action': action?.toJson(),
      };
}

class NotificationAction {
  final String label;
  final String view;
  const NotificationAction({required this.label, required this.view});
  factory NotificationAction.fromJson(Map<String, dynamic> j) =>
    NotificationAction(label: j['label'] as String, view: j['view'] as String);
  Map<String, dynamic> toJson() => {'label': label, 'view': view};
}

class ChatMessage {
  final String id;
  final String role; // user | assistant | system
  final String content;
  final DateTime createdAt;

  const ChatMessage({required this.id, required this.role, required this.content, required this.createdAt});

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String, role: j['role'] as String,
    content: j['content'] as String, createdAt: DateTime.parse(j['createdAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'role': role, 'content': content, 'createdAt': createdAt.toIso8601String(),
  };
}

class UserProfile {
  final String name;
  final String email;
  final String avatarColor;
  final String baseCurrency;
  final double monthlyIncomeGoal;

  const UserProfile({
    required this.name, required this.email, required this.avatarColor,
    required this.baseCurrency, required this.monthlyIncomeGoal,
  });

  UserProfile copyWith({String? name, String? email, String? avatarColor, String? baseCurrency, double? monthlyIncomeGoal}) =>
    UserProfile(
      name: name ?? this.name, email: email ?? this.email,
      avatarColor: avatarColor ?? this.avatarColor,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      monthlyIncomeGoal: monthlyIncomeGoal ?? this.monthlyIncomeGoal,
    );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] as String, email: j['email'] as String,
    avatarColor: j['avatarColor'] as String, baseCurrency: j['baseCurrency'] as String,
    monthlyIncomeGoal: (j['monthlyIncomeGoal'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'name': name, 'email': email, 'avatarColor': avatarColor,
    'baseCurrency': baseCurrency, 'monthlyIncomeGoal': monthlyIncomeGoal,
  };
}
