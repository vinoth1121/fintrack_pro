import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_tokens.dart';
import '../../domain/entities/note_entity.dart';
import '../providers/note_provider.dart';
import '../../../../shared/widgets/shell/main_shell.dart';
import '../../../../shared/widgets/states/app_states.dart';
import 'note_editor_screen.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteListProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => ShellScaffoldData.of(context)?.openDrawer(),
          ),
        ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextTertiary),
                  border: InputBorder.none,
                ),
                onChanged: (v) => ref.read(noteListProvider.notifier).setSearch(v),
              )
            : Text('Notes', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (!_showSearch) {
                _searchController.clear();
                ref.read(noteListProvider.notifier).setSearch('');
              }
            },
          ),
        ],
      ),
      body: state.status == NoteListStatus.loading
          ? const Padding(padding: EdgeInsets.all(AppSpacing.base), child: AppShimmerList(itemCount: 4, itemHeight: 100))
          : state.filtered.isEmpty
              ? AppEmptyState(
                  icon: Icons.sticky_note_2_rounded,
                  title: state.searchQuery.isEmpty ? 'No notes yet' : 'No matches found',
                  subtitle: state.searchQuery.isEmpty
                      ? 'Jot down reminders, disputes, or financial thoughts.'
                      : 'Try a different search term.',
                  actionLabel: state.searchQuery.isEmpty ? 'New Note' : null,
                  onAction: state.searchQuery.isEmpty ? () => _openEditor(context) : null,
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(noteListProvider.notifier).load(),
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 100),
                    children: [
                      if (state.pinned.isNotEmpty) ...[
                        const _SectionLabel(label: 'PINNED', icon: Icons.push_pin_rounded),
                        const SizedBox(height: AppSpacing.sm),
                        _NoteGrid(notes: state.pinned, onOpen: (n) => _openEditor(context, note: n)),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (state.unpinned.isNotEmpty) ...[
                        if (state.pinned.isNotEmpty) const _SectionLabel(label: 'OTHERS', icon: Icons.notes_rounded),
                        if (state.pinned.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                        _NoteGrid(notes: state.unpinned, onOpen: (n) => _openEditor(context, note: n)),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _openEditor(BuildContext context, {NoteEntity? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.darkTextTertiary),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, letterSpacing: 1, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Note Grid (2-column staggered) ────────────────────────────────────────────

class _NoteGrid extends ConsumerWidget {
  final List<NoteEntity> notes;
  final ValueChanged<NoteEntity> onOpen;

  const _NoteGrid({required this.notes, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: notes.map((note) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - AppSpacing.base * 2 - AppSpacing.sm) / 2,
          child: _NoteCard(
            note: note,
            onTap: () => onOpen(note),
            onTogglePin: () => ref.read(noteListProvider.notifier).togglePin(note),
            onDelete: () => _confirmDelete(context, ref, note),
          ),
        );
      }).toList(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NoteEntity note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
        title: Text('Delete Note?', style: AppTypography.titleMedium.copyWith(color: AppColors.darkTextPrimary)),
        content: Text('This will permanently delete "${note.title}".', style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.darkTextSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(noteListProvider.notifier).deleteNote(note.id);
            },
            child: Text('Delete', style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteEntity note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onTap, required this.onTogglePin, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = note.color != null ? Color(int.parse(note.color!.replaceFirst('#', '0xFF'))) : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(AppRadius.base),
          border: Border(left: BorderSide(color: color, width: 3), top: const BorderSide(color: AppColors.darkBorder, width: 0.5), right: const BorderSide(color: AppColors.darkBorder, width: 0.5), bottom: const BorderSide(color: AppColors.darkBorder, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onTogglePin,
                  child: Icon(
                    note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 16,
                    color: note.isPinned ? color : AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              note.content,
              style: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary, height: 1.4),
              maxLines: 4, overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (note.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      children: note.tags.take(2).map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text(t, style: AppTypography.labelSmall.copyWith(color: color, fontSize: 9)),
                      ),).toList(),
                    ),
                  )
                else
                  const Spacer(),
                Text(DateFormat.MMMd().format(note.updatedAt), style: AppTypography.labelSmall.copyWith(color: AppColors.darkTextTertiary, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
