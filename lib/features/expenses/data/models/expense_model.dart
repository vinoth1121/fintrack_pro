import '../../domain/entities/expense_entity.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  CategoryEntity toEntity() => CategoryEntity(
        id: id, name: name, icon: icon, color: color, isDefault: isDefault,
      );
}

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime date;
  final CategoryModel? category;
  final String? notes;
  final String? receiptUrl;
  final bool isRecurring;
  final List<String> tags;
  final String? paymentMethod;
  final String? location;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    this.currency = 'USD',
    required this.date,
    this.category,
    this.notes,
    this.receiptUrl,
    this.isRecurring = false,
    this.tags = const [],
    this.paymentMethod,
    this.location,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        date: DateTime.parse(json['date'] as String),
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        notes: json['notes'] as String?,
        receiptUrl: json['receiptUrl'] as String?,
        isRecurring: json['isRecurring'] as bool? ?? false,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        paymentMethod: json['paymentMethod'] as String?,
        location: json['location'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        // Only send categoryId if it's not a default local-only category
        // (default categories have non-UUID string IDs like "food", "transport")
        if (category != null && category!.id.contains('-'))
          'categoryId': category!.id,
        if (notes != null) 'notes': notes,
        if (receiptUrl != null) 'receiptUrl': receiptUrl,
        'isRecurring': isRecurring,
        'tags': tags,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (location != null) 'location': location,
      };

  ExpenseEntity toEntity() => ExpenseEntity(
        id: id,
        title: title,
        amount: amount,
        currency: currency,
        date: date,
        category: category?.toEntity(),
        notes: notes,
        receiptUrl: receiptUrl,
        isRecurring: isRecurring,
        tags: tags,
        paymentMethod: paymentMethod,
        location: location,
        createdAt: createdAt,
      );
}

class PaginatedExpensesModel {
  final List<ExpenseModel> items;
  final int page;
  final int totalPages;
  final int total;

  const PaginatedExpensesModel({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory PaginatedExpensesModel.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return PaginatedExpensesModel(
      items: (json['items'] as List)
          .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int,
      totalPages: pagination['totalPages'] as int,
      total: pagination['total'] as int,
    );
  }
}
