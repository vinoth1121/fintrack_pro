import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  @override
  List<Object?> get props => [id, name, icon, color, isDefault];
}

class ExpenseEntity extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime date;
  final CategoryEntity? category;
  final String? notes;
  final String? receiptUrl;
  final bool isRecurring;
  final List<String> tags;
  final String? paymentMethod;
  final String? location;
  final DateTime createdAt;

  const ExpenseEntity({
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

  ExpenseEntity copyWith({
    String? title,
    double? amount,
    DateTime? date,
    CategoryEntity? category,
    String? notes,
    bool? isRecurring,
  }) {
    return ExpenseEntity(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency,
      date: date ?? this.date,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      receiptUrl: receiptUrl,
      isRecurring: isRecurring ?? this.isRecurring,
      tags: tags,
      paymentMethod: paymentMethod,
      location: location,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id, title, amount, currency, date, category, notes,
    receiptUrl, isRecurring, tags, paymentMethod, location, createdAt,
  ];
}

// ─── Default Categories (used until backend categories are seeded/fetched) ──

abstract final class DefaultCategories {
  static const expense = [
    CategoryEntity(id: 'food', name: 'Food & Dining', icon: 'restaurant', color: '#FF9800', isDefault: true),
    CategoryEntity(id: 'transport', name: 'Transport', icon: 'car', color: '#2196F3', isDefault: true),
    CategoryEntity(id: 'shopping', name: 'Shopping', icon: 'bag', color: '#FF5252', isDefault: true),
    CategoryEntity(id: 'entertainment', name: 'Entertainment', icon: 'movie', color: '#E040FB', isDefault: true),
    CategoryEntity(id: 'utilities', name: 'Utilities', icon: 'flash', color: '#00BCD4', isDefault: true),
    CategoryEntity(id: 'health', name: 'Health', icon: 'health', color: '#4CAF50', isDefault: true),
    CategoryEntity(id: 'education', name: 'Education', icon: 'book', color: '#9C27B0', isDefault: true),
    CategoryEntity(id: 'rent', name: 'Rent & Housing', icon: 'home', color: '#795548', isDefault: true),
    CategoryEntity(id: 'travel', name: 'Travel', icon: 'flight', color: '#3F51B5', isDefault: true),
    CategoryEntity(id: 'other', name: 'Other', icon: 'category', color: '#607D8B', isDefault: true),
  ];

  static const income = [
    CategoryEntity(id: 'salary', name: 'Salary', icon: 'work', color: '#00D4A8', isDefault: true),
    CategoryEntity(id: 'freelance', name: 'Freelance', icon: 'code', color: '#00BCD4', isDefault: true),
    CategoryEntity(id: 'investment', name: 'Investment', icon: 'trending_up', color: '#6C63FF', isDefault: true),
    CategoryEntity(id: 'gift', name: 'Gift', icon: 'gift', color: '#E040FB', isDefault: true),
    CategoryEntity(id: 'business', name: 'Business', icon: 'business', color: '#FF9800', isDefault: true),
    CategoryEntity(id: 'other_income', name: 'Other', icon: 'category', color: '#607D8B', isDefault: true),
  ];
}
