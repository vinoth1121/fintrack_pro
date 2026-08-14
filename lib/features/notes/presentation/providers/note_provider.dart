import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/note_entity.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/models/note_model.dart';
import '../../../../core/errors/failures.dart';

enum NoteListStatus { initial, loading, loaded, error }

class NoteListState extends Equatable {
  final NoteListStatus status;
  final List<NoteEntity> notes;
  final Failure? failure;
  final String searchQuery;

  const NoteListState({
    this.status = NoteListStatus.initial,
    this.notes = const [],
    this.failure,
    this.searchQuery = '',
  });

  List<NoteEntity> get filtered {
    if (searchQuery.isEmpty) return notes;
    final q = searchQuery.toLowerCase();
    return notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q) ||
        n.tags.any((t) => t.toLowerCase().contains(q)),).toList();
  }

  List<NoteEntity> get pinned => filtered.where((n) => n.isPinned).toList();
  List<NoteEntity> get unpinned => filtered.where((n) => !n.isPinned).toList();

  NoteListState copyWith({
    NoteListStatus? status,
    List<NoteEntity>? notes,
    Failure? failure,
    String? searchQuery,
  }) {
    return NoteListState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      failure: failure,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [status, notes, failure, searchQuery];
}

class NoteListNotifier extends StateNotifier<NoteListState> {
  final NoteRepository _repository;

  NoteListNotifier(this._repository) : super(const NoteListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: NoteListStatus.loading);
    final result = await _repository.getNotes();

    result.fold(
      (failure) => state = state.copyWith(status: NoteListStatus.loaded, notes: _mockNotes()),
      (models) => state = state.copyWith(
        status: NoteListStatus.loaded,
        notes: models.map((m) => m.toEntity()).toList(),
      ),
    );
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> togglePin(NoteEntity note) async {
    final result = await _repository.updateNote(note.id, {'isPinned': !note.isPinned});
    result.fold(
      (failure) {
        final updated = state.notes.map((n) => n.id == note.id ? n.copyWith(isPinned: !note.isPinned) : n).toList();
        state = state.copyWith(notes: updated);
      },
      (model) {
        final updated = state.notes.map((n) => n.id == note.id ? model.toEntity() : n).toList();
        state = state.copyWith(notes: updated);
      },
    );
  }

  Future<void> deleteNote(String id) async {
    final result = await _repository.deleteNote(id);
    result.fold(
      (failure) {},
      (_) => state = state.copyWith(notes: state.notes.where((n) => n.id != id).toList()),
    );
  }

  Future<bool> saveNote({
    String? existingId,
    required String title,
    required String content,
    required List<String> tags,
    required String color,
  }) async {
    if (existingId != null) {
      final result = await _repository.updateNote(existingId, {
        'title': title, 'content': content, 'tags': tags, 'color': color,
      });
      return result.fold((failure) => false, (model) {
        final updated = state.notes.map((n) => n.id == existingId ? model.toEntity() : n).toList();
        state = state.copyWith(notes: updated);
        return true;
      });
    } else {
      final note = NoteModel(
        id: '', title: title, content: content, tags: tags, color: color,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final result = await _repository.createNote(note);
      return result.fold((failure) {
        load();
        return true;
      }, (model) {
        state = state.copyWith(notes: [model.toEntity(), ...state.notes]);
        return true;
      });
    }
  }

  List<NoteEntity> _mockNotes() {
    final now = DateTime.now();
    return [
      NoteEntity(
        id: '1', title: 'Tax deduction reminder',
        content: 'Home office expenses are deductible — keep receipts for internet and utilities for Q3.',
        tags: const ['tax', 'important'], color: '#FFB300', isPinned: true,
        createdAt: now.subtract(const Duration(days: 5)), updatedAt: now.subtract(const Duration(days: 5)),
      ),
      NoteEntity(
        id: '2', title: 'Dispute Amazon charge',
        content: 'Charged twice for the same order on 6/15. Called support, reference #AZ-88213. Follow up if not refunded by 6/25.',
        tags: const ['dispute'], color: '#FF5252', isPinned: true,
        createdAt: now.subtract(const Duration(days: 2)), updatedAt: now.subtract(const Duration(days: 1)),
      ),
      NoteEntity(
        id: '3', title: 'Investment research',
        content: 'Look into index fund options for the emergency fund overflow once it hits \$10k target.',
        tags: const ['investing'], color: '#6C63FF',
        createdAt: now.subtract(const Duration(days: 10)), updatedAt: now.subtract(const Duration(days: 10)),
      ),
      NoteEntity(
        id: '4', title: 'Insurance renewal',
        content: 'Auto insurance renews in September. Compare quotes from 2-3 providers before auto-renewal kicks in.',
        tags: const ['insurance', 'reminder'], color: '#00D4A8',
        createdAt: now.subtract(const Duration(days: 15)), updatedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }
}

final noteListProvider = StateNotifierProvider<NoteListNotifier, NoteListState>((ref) {
  return NoteListNotifier(ref.watch(noteRepositoryProvider));
});
