import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/toast.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/fintrack_provider.dart';

/// Lumina sticky-note palette.
const _kNotePalette = <String>[
  '#6C5CE7', '#00D2FF', '#00E676', '#FFB74D',
  '#FF5252', '#448AFF', '#FF6FB5', '#B388FF',
];

Color _hex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

enum _FilterKind { all, pinned, tag }

class _FilterState {
  final _FilterKind kind;
  final String? tag;
  const _FilterState(this.kind) : tag = null;
  const _FilterState.all() : this(_FilterKind.all);
  const _FilterState.pinned() : this(_FilterKind.pinned);
  const _FilterState.tag(String t) : kind = _FilterKind.tag, tag = t;
}

/// Notes screen — masonry-style notes with pin/edit/delete, filter chips, search,
/// and a create/edit dialog with color picker + tags. Pinned notes sort first.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _NotesView();
  }
}

class _NotesView extends ConsumerStatefulWidget {
  const _NotesView();
  @override
  ConsumerState<_NotesView> createState() => _NotesViewState();
}

class _NotesViewState extends ConsumerState<_NotesView> {
  String _search = '';
  _FilterState _filter = const _FilterState.all();

  void _handlePin(Note n) {
    ref.read(fintrackProvider.notifier).updateNote(
          n.id,
          n.copyWith(pinned: !n.pinned),
        );
    final t = ref.read(tProvider);
    showAppToast(
      context,
      n.pinned ? 'Note unpinned' : 'Note pinned',
      description: n.title.isEmpty ? t.messages.untitled : n.title,
    );
  }

  void _handleDelete(Note n) {
    final t = ref.read(tProvider);
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${n.title.isEmpty ? 'this note' : n.title}"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.common.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () {
              ref.read(fintrackProvider.notifier).deleteNote(n.id);
              Navigator.pop(c);
              showAppToast(
                context,
                t.messages.noteDeleted,
                description: n.title.isEmpty ? t.messages.untitled : n.title,
              );
            },
            child: Text(t.common.delete),
          ),
        ],
      ),
    );
  }

  void _handleSave({
    required String title,
    required String body,
    required String color,
    required List<String> tags,
  }) {
    final t = ref.read(tProvider);
    final notifier = ref.read(fintrackProvider.notifier);
    if (title.isEmpty && body.isEmpty) return;
    final editing = _editingBuffer;
    if (_editingFromDialog && editing != null) {
      notifier.updateNote(
        editing.id,
        editing.copyWith(title: title, body: body, color: color, tags: tags),
      );
      showAppToast(
        context,
        t.messages.noteUpdated,
        description: title.isEmpty ? t.messages.untitled : title,
      );
    } else {
      final now = DateTime.now();
      notifier.addNote(Note(
        id: uid('n'),
        title: title,
        body: body,
        color: color,
        pinned: false,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      ),);
      showAppToast(
        context,
        t.messages.noteCreated,
        description: title.isEmpty ? t.messages.untitled : title,
      );
    }
    _editingFromDialog = false;
    _editingBuffer = null;
  }

  // Buffer used by the dialog callback to know whether we are editing.
  bool _editingFromDialog = false;
  Note? _editingBuffer;

  void _openDialog({Note? editing}) {
    _editingFromDialog = editing != null;
    _editingBuffer = editing;
    showDialog<void>(
      context: context,
      builder: (_) => _NoteDialog(editing: editing, onSave: _handleSave),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final state = ref.watch(fintrackProvider);
    final notes = state.notes;
    final l = context.lumina;

    final allTags = <String>{};
    for (final n in notes) {
      allTags.addAll(n.tags);
    }
    final sortedTags = allTags.toList()..sort();

    final q = _search.trim().toLowerCase();
    final visible = notes.where((n) {
      if (_filter.kind == _FilterKind.pinned && !n.pinned) return false;
      if (_filter.kind == _FilterKind.tag && !n.tags.contains(_filter.tag)) {
        return false;
      }
      if (q.isEmpty) return true;
      return '${n.title} ${n.body} ${n.tags.join(' ')}'.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          GlassCard(
            strong: true,
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(t.notes.financialNotes,
                              style: AppTypography.display(context, size: 20),),
                          const GradientPill(child: Text('Markdown-friendly')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Memos, reminders & insights',
                        style: AppTypography.body(context, size: 12)
                            .copyWith(color: l.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GradientButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => _openDialog(),
                  child: Text(t.notes.newNote),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Search + filter chips
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18, color: l.mutedForeground),
                    hintText: t.notes.searchNotes,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      active: _filter.kind == _FilterKind.all,
                      onTap: () => setState(() => _filter = const _FilterState.all()),
                      children: [
                        Text(t.common.all),
                        _Count('${notes.length}'),
                      ],
                    ),
                    _Chip(
                      active: _filter.kind == _FilterKind.pinned,
                      onTap: () => setState(() => _filter = const _FilterState.pinned()),
                      children: [
                        const Icon(Icons.push_pin, size: 12),
                        Text(t.notes.pinned),
                        _Count('${notes.where((n) => n.pinned).length}'),
                      ],
                    ),
                    ...sortedTags.map((tag) => _Chip(
                          active: _filter.kind == _FilterKind.tag && _filter.tag == tag,
                          onTap: () => setState(() => _filter = _FilterState.tag(tag)),
                          children: [const Icon(Icons.tag, size: 12), Text(tag)],
                        ),),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (visible.isEmpty)
            EmptyState(
              icon: const Icon(Icons.sticky_note_2_outlined),
              title: t.notes.noNotes,
              description: notes.isEmpty
                  ? 'Capture ideas, reminders and financial insights in one place.'
                  : 'Try a different search term or clear your filters.',
              action: GradientButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => _openDialog(),
                child: Text(t.notes.createFirst),
              ),
            )
          else
            _NotesMasonry(
              notes: visible,
              onPin: _handlePin,
              onEdit: (n) => _openDialog(editing: n),
              onDelete: _handleDelete,
            ),
        ],
          ),
        ),
      ),
    );
  }
}

/* ----------------------------- Filter chip ----------------------------- */

class _Chip extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  final List<Widget> children;
  const _Chip({required this.active, required this.onTap, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.transparent : context.lumina.surface3.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: active ? AppColors.brandGradient : null,
            border: active ? null : Border.all(color: context.lumina.border, width: 1),
          ),
          child: DefaultTextStyle.merge(
            style: AppTypography.label(context, size: 12).copyWith(
              color: active ? Colors.white : context.lumina.foreground,
              fontWeight: FontWeight.w500,
            ),
            child: IconTheme(
              data: IconThemeData(
                size: 12,
                color: active ? Colors.white : context.lumina.mutedForeground,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String text;
  const _Count(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTypography.label(context, size: 10).copyWith(color: Colors.white),
      ),
    );
  }
}

/* ----------------------------- Notes masonry ----------------------------- */

class _NotesMasonry extends StatelessWidget {
  final List<Note> notes;
  final void Function(Note) onPin;
  final void Function(Note) onEdit;
  final void Function(Note) onDelete;
  const _NotesMasonry({
    required this.notes,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Distribute alternately across two columns for a masonry feel.
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < notes.length; i++) {
      final card = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _NoteCard(
          note: notes[i],
          index: i,
          onPin: onPin,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      );
      (i.isEven ? left : right).add(card);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final int index;
  final void Function(Note) onPin;
  final void Function(Note) onEdit;
  final void Function(Note) onDelete;
  const _NoteCard({
    required this.note,
    required this.index,
    required this.onPin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final accent = _hex(note.color);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: l.border, width: 1),
        color: l.surface2.withValues(alpha: 0.65),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Color tint overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 0.16), Colors.transparent],
                  stops: const [0, 0.6],
                ),
              ),
            ),
          ),
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 6, color: accent),
          ),
          // Pinned indicator
          if (note.pinned)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.iris.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.push_pin, size: 12, color: AppColors.iris),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  style: AppTypography.heading(context, size: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.body,
                    style: AppTypography.body(context, size: 12)
                        .copyWith(color: l.mutedForeground),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: note.tags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: l.surface3.withValues(alpha: 0.5),
                                border: Border.all(color: l.border, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tag, size: 10, color: l.mutedForeground),
                                  const SizedBox(width: 2),
                                  Text(
                                    tag,
                                    style: AppTypography.label(context, size: 10)
                                        .copyWith(color: l.mutedForeground),
                                  ),
                                ],
                              ),
                            ),)
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: l.border.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDate(note.updatedAt, style: 'rel'),
                        style: AppTypography.label(context, size: 10)
                            .copyWith(color: l.mutedForeground),
                      ),
                    ),
                    _IconBtn(
                      icon: Icons.push_pin,
                      tooltip: note.pinned ? 'Unpin note' : 'Pin note',
                      active: note.pinned,
                      onTap: () => onPin(note),
                    ),
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: () => onEdit(note),
                    ),
                    _IconBtn(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete',
                      danger: true,
                      onTap: () => onDelete(note),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: 300.ms,
          delay: (index * 40).clamp(0, 400).ms,
        )
        .slideY(begin: 0.05, end: 0, duration: 300.ms);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final color = active
        ? AppColors.iris
        : danger
            ? l.mutedForeground
            : l.mutedForeground;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/* ----------------------------- Note dialog ----------------------------- */

class _NoteDialog extends ConsumerStatefulWidget {
  final Note? editing;
  final void Function({
    required String title,
    required String body,
    required String color,
    required List<String> tags,
  }) onSave;
  const _NoteDialog({this.editing, required this.onSave});

  @override
  ConsumerState<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends ConsumerState<_NoteDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  late String _color;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.editing?.title ?? '');
    _body = TextEditingController(text: widget.editing?.body ?? '');
    _tags = TextEditingController(
        text: (widget.editing?.tags ?? const <String>[]).join(', '),);
    _color = widget.editing?.color ?? _kNotePalette.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSave) return;
    final tags = _tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    widget.onSave(
      title: _title.text.trim(),
      body: _body.text,
      color: _color,
      tags: tags,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.lumina;
    final t = ref.watch(tProvider);
    return AlertDialog(
      title: Text(
        widget.editing == null ? t.notes.newNote : 'Edit note',
        style: AppTypography.heading(context, size: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.notes.title.toUpperCase(),
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Tax-saving investments',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text(
                t.notes.body.toUpperCase(),
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                maxLines: 6,
                minLines: 4,
                style: AppTypography.body(context, size: 13),
                decoration: const InputDecoration(
                  hintText: 'Write your note… (markdown supported)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              Text(
                'COLOR',
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kNotePalette.map((c) {
                  final selected = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _hex(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? _hex(c) : Colors.transparent,
                          width: 4,
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: _hex(c).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                t.notes.tags.toUpperCase(),
                style: AppTypography.label(context, size: 10)
                    .copyWith(letterSpacing: 1.2, color: l.mutedForeground),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(hintText: 'comma, separated, tags'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        GradientButton(
          onPressed: _canSave ? _submit : null,
          child: Text(widget.editing == null ? 'Create note' : t.common.saveChanges),
        ),
      ],
    );
  }
}
