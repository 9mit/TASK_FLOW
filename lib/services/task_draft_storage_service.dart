import 'package:hive/hive.dart';

import '../models/task_draft.dart';

class TaskDraftStorageService {
  TaskDraftStorageService._();

  static TaskDraftStorageService? _instance;

  static TaskDraftStorageService get instance =>
      _instance ??= TaskDraftStorageService._();

  static const _boxName = 'task_draft_v2';
  static const _draftKey = 'active_task_draft';

  Box<dynamic>? _box;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _draftBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'TaskDraftStorageService not initialized. Call initialize() first.',
      );
    }
    return _box!;
  }

  TaskDraft loadDraft() {
    final raw = _draftBox.get(_draftKey);
    if (raw is Map) {
      return TaskDraft.fromJson(Map<String, dynamic>.from(raw));
    }
    return const TaskDraft();
  }

  Future<void> saveDraft(TaskDraft draft) async {
    if (draft.isEmpty) {
      await clearDraft();
      return;
    }

    await _draftBox.put(_draftKey, draft.toJson());
  }

  Future<void> clearDraft() async {
    await _draftBox.delete(_draftKey);
  }

  Future<void> close() async {
    if (_box?.isOpen == true) {
      await _box!.close();
    }
  }
}
