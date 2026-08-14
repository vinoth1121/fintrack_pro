import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/note_entity.dart';
import '../providers/note_provider.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final NoteEntity? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late String _selectedColor;
  late List<String> _tags;
  bool _isSaving = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagController = TextEditingController();
    _selectedColor = widget.note?.color ?? NoteColors.all.first;
    _tags = List.from(widget.note?.tags ?? []);

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() {
      _tags.add(trimmed);
      _tagController.clear();
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    final success = await ref.read(noteListProvider.notifier).saveNote(
      existingId: widget.note?.id,
      title: title.isEmpty ? 'Untitled Note' : title,
      content: content,
      tags: _tags,
      color: _selectedColor,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
    } else {
      AppSnackbar.error(context, 'Failed to save note. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasChanges) _save();
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (_hasChanges) {
                await _save();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () => _confirmDelete(context),
              ),
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  TextField(
                    controller: _titleController,
                    style: AppTypography.headlineSmall.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: AppTypography.headlineSmall.copyWith(color: AppColors.darkTextTertiary, fontWeight: FontWeight.w700),
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _contentController,
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextSecondary, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Start writing...',
                      hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.darkTextTertiary),
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    minLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Tags
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ..._tags.map((tag) => Chip(
                        label: Text(tag, style: AppTypography.labelSmall.copyWith(color: color)),
                        backgroundColor: color.withValues(alpha: 0.12),
                        deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        deleteIconColor: color,
                        onDeleted: () => setState(() { _tags.remove(tag); _hasChanges = true; }),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                      ),),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _tagController,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
                          decoration: InputDecoration(
                            hintText: '+ Add tag',
                            hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.darkTextTertiary),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: _addTag,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Color picker bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.md),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.darkDivider, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: NoteColors.all.map((c) {
                    final colorValue = Color(int.parse(c.replaceFirst('#', '0xFF')));
                    final isSelected = _selectedColor == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () => setState(() { _selectedColor = c; _hasChanges = true; }),
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          width: isSelected ? 32 : 26,
                          height: isSelected ? 32 : 26,
                          decoration: BoxDecoration(
                            color: colorValue,
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                          child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Note?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text('This cannot be undone.', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              ref.read(noteListProvider.notifier).deleteNote(widget.note!.id);
              Navigator.pop(context); // editor
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
