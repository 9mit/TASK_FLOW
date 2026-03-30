import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task_draft.dart';
import '../models/task_status.dart';
import '../services/task_draft_storage_service.dart';

class TaskDraftNotifier extends StateNotifier<TaskDraft> {
  TaskDraftNotifier(this._storage) : super(_storage.loadDraft());

  final TaskDraftStorageService _storage;

  void setTitle(String value) => _setState(state.copyWith(title: value));

  void setDescription(String value) =>
      _setState(state.copyWith(description: value));

  void setDueDate(DateTime? value) => _setState(state.copyWith(dueDate: value));

  void setStatus(TaskStatus value) => _setState(state.copyWith(status: value));

  void setBlockedByKey(int? value) =>
      _setState(state.copyWith(blockedByKey: value));

  void initNew() {
    _setState(const TaskDraft());
  }

  void initEdit({
    required int taskKey,
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    int? blockedByKey,
  }) {
    _setState(
      TaskDraft(
        editingTaskKey: taskKey,
        title: title,
        description: description,
        dueDate: dueDate,
        status: status,
        blockedByKey: blockedByKey,
      ),
    );
  }

  void clear() {
    _setState(const TaskDraft());
  }

  void _setState(TaskDraft nextState) {
    state = nextState;
    unawaited(_storage.saveDraft(nextState));
  }
}

final taskDraftProvider = StateNotifierProvider<TaskDraftNotifier, TaskDraft>((
  ref,
) {
  return TaskDraftNotifier(TaskDraftStorageService.instance);
});
