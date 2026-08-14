import 'package:equatable/equatable.dart';
import '../../../expenses/domain/entities/expense_entity.dart';

class IncomeEntity extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime date;
  final CategoryEntity? category;
  final String? notes;
  final bool isRecurring;
  final String? source;
  final DateTime createdAt;

  const IncomeEntity({
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

  @override
  List<Object?> get props => [
    id, title, amount, currency, date, category, notes, isRecurring, source, createdAt,
  ];
}
