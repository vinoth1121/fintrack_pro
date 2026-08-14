import '../../domain/entities/note_entity.dart';

class NoteModel {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String? color;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    this.color,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        color: json['color'] as String?,
        isPinned: json['isPinned'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'title': title,
        'content': content,
        'tags': tags,
        if (color != null) 'color': color,
        'isPinned': isPinned,
      };

  NoteEntity toEntity() => NoteEntity(
        id: id,
        title: title,
        content: content,
        tags: tags,
        color: color,
        isPinned: isPinned,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
