import '../../domain/entities/income_entity.dart';
import '../../../expenses/data/models/expense_model.dart';

class IncomeModel {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime date;
  final CategoryModel? category;
  final String? notes;
  final bool isRecurring;
  final String? source;
  final DateTime createdAt;

  const IncomeModel({
    required this.id,
    required this.title,
    required this.amount,
    this.currency = 'USD',
    required this.date,
    this.category,
    this.notes,
    this.isRecurring = false,
    this.source,
    required this.createdAt,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) => IncomeModel(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        date: DateTime.parse(json['date'] as String),
        category: json['category'] != null
            ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
            : null,
        notes: json['notes'] as String?,
        isRecurring: json['isRecurring'] as bool? ?? false,
        source: json['source'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        // Only send categoryId if it's a UUID from backend (not a local default)
        if (category != null && category!.id.contains('-'))
          'categoryId': category!.id,
        if (notes != null) 'notes': notes,
        'isRecurring': isRecurring,
        if (source != null) 'source': source,
      };

  IncomeEntity toEntity() => IncomeEntity(
        id: id,
        title: title,
        amount: amount,
        currency: currency,
        date: date,
        category: category?.toEntity(),
        notes: notes,
        isRecurring: isRecurring,
        source: source,
        createdAt: createdAt,
      );
}

class PaginatedIncomeModel {
  final List<IncomeModel> items;
  final int page;
  final int totalPages;
  final int total;

  const PaginatedIncomeModel({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory PaginatedIncomeModel.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return PaginatedIncomeModel(
      items: (json['items'] as List)
          .map((e) => IncomeModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int,
      totalPages: pagination['totalPages'] as int,
      total: pagination['total'] as int,
    );
  }
}
