import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/task_draft.dart';
import 'package:taskflow/models/task_status.dart';
import 'package:taskflow/providers/draft_provider.dart';
import 'package:taskflow/services/task_draft_storage_service.dart';

void main() {
  ProviderContainer makeContainer() => ProviderContainer();

  setUpAll(() async {
    Hive.init('draft_test_${DateTime.now().millisecondsSinceEpoch}');
    await TaskDraftStorageService.instance.initialize();
  });

  tearDown(() async {
    await TaskDraftStorageService.instance.clearDraft();
  });

  tearDownAll(() async {
    await TaskDraftStorageService.instance.close();
    await Hive.deleteFromDisk();
  });

  group('TaskDraftNotifier', () {
    test('initial state is empty', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final draft = container.read(taskDraftProvider);
      expect(draft.isEmpty, isTrue);
      expect(draft.isEditMode, isFalse);
    });

    test('initNew resets state to empty', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container.read(taskDraftProvider.notifier).setTitle('Some title');
      container.read(taskDraftProvider.notifier).initNew();

      final draft = container.read(taskDraftProvider);
      expect(draft.title, isEmpty);
      expect(draft.isEmpty, isTrue);
    });

    test('setters update state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final date = DateTime(2025, 12, 25);
      final notifier = container.read(taskDraftProvider.notifier);
      notifier.setTitle('My Task');
      notifier.setDescription('Details');
      notifier.setDueDate(date);
      notifier.setStatus(TaskStatus.done);
      notifier.setBlockedByKey(7);

      final draft = container.read(taskDraftProvider);
      expect(draft.title, equals('My Task'));
      expect(draft.description, equals('Details'));
      expect(draft.dueDate, equals(date));
      expect(draft.status, equals(TaskStatus.done));
      expect(draft.blockedByKey, equals(7));
    });

    test('initEdit populates all fields and sets edit mode', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      final dueDate = DateTime(2025, 11, 1);
      container
          .read(taskDraftProvider.notifier)
          .initEdit(
            taskKey: 5,
            title: 'Edit Me',
            description: 'Some details',
            dueDate: dueDate,
            status: TaskStatus.inProgress,
            blockedByKey: 2,
          );

      final draft = container.read(taskDraftProvider);
      expect(draft.editingTaskKey, equals(5));
      expect(draft.title, equals('Edit Me'));
      expect(draft.description, equals('Some details'));
      expect(draft.dueDate, equals(dueDate));
      expect(draft.status, equals(TaskStatus.inProgress));
      expect(draft.blockedByKey, equals(2));
      expect(draft.isEditMode, isTrue);
    });

    test('clear resets to empty state', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      container
          .read(taskDraftProvider.notifier)
          .initEdit(
            taskKey: 4,
            title: 'X',
            description: '',
            dueDate: DateTime.now(),
            status: TaskStatus.todo,
          );
      container.read(taskDraftProvider.notifier).clear();

      final draft = container.read(taskDraftProvider);
      expect(draft.isEmpty, isTrue);
      expect(draft.isEditMode, isFalse);
    });

    test('draft state is persisted through storage service', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(taskDraftProvider.notifier);
      notifier.setTitle('Work in progress');
      notifier.setDescription('Details here');
      notifier.setStatus(TaskStatus.inProgress);
      await Future<void>.delayed(Duration.zero);

      final restored = TaskDraftStorageService.instance.loadDraft();
      expect(restored.title, equals('Work in progress'));
      expect(restored.description, equals('Details here'));
      expect(restored.status, equals(TaskStatus.inProgress));
    });
  });

  group('TaskDraft.copyWith', () {
    test('preserves fields not specified', () {
      const draft = TaskDraft(
        title: 'Test',
        description: 'Desc',
        status: TaskStatus.inProgress,
      );

      final copy = draft.copyWith(title: 'Updated');
      expect(copy.description, equals('Desc'));
      expect(copy.status, equals(TaskStatus.inProgress));
    });

    test('can set dueDate to null via sentinel', () {
      final draft = TaskDraft(dueDate: DateTime(2025, 1, 1));
      final copy = draft.copyWith(dueDate: null);
      expect(copy.dueDate, isNull);
    });

    test('can set editingTaskKey to null via sentinel', () {
      const draft = TaskDraft(editingTaskKey: 9);
      final copy = draft.copyWith(editingTaskKey: null);
      expect(copy.editingTaskKey, isNull);
      expect(copy.isEditMode, isFalse);
    });
  });
}
