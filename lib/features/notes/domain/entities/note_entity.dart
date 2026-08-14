import 'package:equatable/equatable.dart';

class NoteEntity extends Equatable {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String? color;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteEntity({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.color,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteEntity copyWith({
    String? title,
    String? content,
    List<String>? tags,
    String? color,
    bool? isPinned,
  }) {
    return NoteEntity(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, content, tags, color, isPinned, createdAt, updatedAt];
}

/// Preset note colors for quick visual categorization
abstract final class NoteColors {
  static const all = [
    '#6C63FF', '#00D4A8', '#FFB300', '#FF5252',
    '#2196F3', '#E040FB', '#607D8B',
  ];
}
