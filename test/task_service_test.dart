import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/models/task_status.dart';
import 'package:taskflow/services/task_service.dart';

TaskService get _service => TaskService.instance;

void main() {
  setUpAll(() async {
    Hive.init('task_service_test_${DateTime.now().millisecondsSinceEpoch}');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TaskStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskAdapter());
    }
    await _service.initialize();
    _service.setSimulatedDelay(Duration.zero);
  });

  tearDown(() async {
    await _service.clearAllTasks();
  });

  tearDownAll(() async {
    await _service.close();
    await Hive.deleteFromDisk();
    TaskService.dispose();
  });

  group('TaskService CRUD', () {
    test('createTask adds a task and returns it', () async {
      final task = await _service.createTask(
        title: 'Write tests',
        description: 'Cover all edge cases',
        dueDate: DateTime(2025, 12, 31),
        status: TaskStatus.todo,
      );

      expect(task.storageKey, isNotNull);
      expect(task.title, equals('Write tests'));
      expect(task.description, equals('Cover all edge cases'));
      expect(task.status, equals(TaskStatus.todo));
      expect(task.blockedByKey, isNull);
    });

    test('getAllTasks returns all created tasks', () async {
      await _service.createTask(
        title: 'Task A',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );
      await _service.createTask(
        title: 'Task B',
        description: '',
        dueDate: DateTime(2025, 10, 2),
        status: TaskStatus.inProgress,
      );

      expect(_service.getAllTasks().length, equals(2));
    });

    test('getAllTasks sorts inProgress before todo before done', () async {
      final now = DateTime(2025, 10, 1);
      await _service.createTask(
        title: 'Done task',
        description: '',
        dueDate: now,
        status: TaskStatus.done,
      );
      await _service.createTask(
        title: 'Todo task',
        description: '',
        dueDate: now,
        status: TaskStatus.todo,
      );
      await _service.createTask(
        title: 'IP task',
        description: '',
        dueDate: now,
        status: TaskStatus.inProgress,
      );

      final all = _service.getAllTasks();
      expect(all[0].status, equals(TaskStatus.inProgress));
      expect(all[1].status, equals(TaskStatus.todo));
      expect(all[2].status, equals(TaskStatus.done));
    });

    test('getTaskByKey returns correct task', () async {
      final created = await _service.createTask(
        title: 'Findable',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );

      final found = _service.getTaskByKey(created.storageKey!);
      expect(found, isNotNull);
      expect(found!.title, equals('Findable'));
    });

    test('getTaskByKey returns null for unknown key', () {
      final found = _service.getTaskByKey(999999);
      expect(found, isNull);
    });

    test('updateTask updates specified fields', () async {
      final created = await _service.createTask(
        title: 'Original',
        description: 'Old desc',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );

      final updated = await _service.updateTask(
        created.storageKey!,
        title: 'Updated',
        status: TaskStatus.done,
      );

      expect(updated.title, equals('Updated'));
      expect(updated.status, equals(TaskStatus.done));
      expect(updated.description, equals('Old desc'));
    });

    test('updateTask throws for unknown key', () async {
      expect(
        () => _service.updateTask(999999, title: 'x'),
        throwsArgumentError,
      );
    });

    test('deleteTask removes the task', () async {
      final created = await _service.createTask(
        title: 'To delete',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );
      final key = created.storageKey!;

      await _service.deleteTask(key);
      expect(_service.getTaskByKey(key), isNull);
    });

    test('deleteTask clears blockers from dependent tasks', () async {
      final blocker = await _service.createTask(
        title: 'Blocker',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );
      final dependent = await _service.createTask(
        title: 'Dependent',
        description: '',
        dueDate: DateTime(2025, 10, 2),
        status: TaskStatus.todo,
        blockedByKey: blocker.storageKey,
      );

      final blockerKey = blocker.storageKey!;
      final dependentKey = dependent.storageKey!;

      await _service.deleteTask(blockerKey);

      final updatedDependent = _service.getTaskByKey(dependentKey);
      expect(updatedDependent!.blockedByKey, isNull);
    });
  });

  group('TaskService blocking logic', () {
    test('isBlocked returns false when no dependency exists', () async {
      final task = await _service.createTask(
        title: 'Free',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );

      expect(_service.isBlocked(task), isFalse);
    });

    test('isBlocked returns true when blocker is not Done', () async {
      final blocker = await _service.createTask(
        title: 'Blocker',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );
      final blocked = await _service.createTask(
        title: 'Blocked',
        description: '',
        dueDate: DateTime(2025, 10, 2),
        status: TaskStatus.todo,
        blockedByKey: blocker.storageKey,
      );

      expect(_service.isBlocked(blocked), isTrue);
    });

    test('isBlocked returns false when blocker is Done', () async {
      final blocker = await _service.createTask(
        title: 'Done Blocker',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.done,
      );
      final blocked = await _service.createTask(
        title: 'Blocked',
        description: '',
        dueDate: DateTime(2025, 10, 2),
        status: TaskStatus.todo,
        blockedByKey: blocker.storageKey,
      );

      expect(_service.isBlocked(blocked), isFalse);
    });

    test(
      'isBlocked returns false after blocker is deleted and dependency clears',
      () async {
        final blocker = await _service.createTask(
          title: 'Transient blocker',
          description: '',
          dueDate: DateTime(2025, 10, 1),
          status: TaskStatus.todo,
        );
        final task = await _service.createTask(
          title: 'Orphaned',
          description: '',
          dueDate: DateTime(2025, 10, 2),
          status: TaskStatus.todo,
          blockedByKey: blocker.storageKey,
        );

        final blockerKey = blocker.storageKey!;
        final taskKey = task.storageKey!;

        await _service.deleteTask(blockerKey);

        final refreshed = _service.getTaskByKey(taskKey);
        expect(refreshed!.blockedByKey, isNull);
        expect(_service.isBlocked(refreshed), isFalse);
      },
    );
  });

  group('TaskService cycle detection', () {
    test('getEligibleBlockers excludes the task itself', () async {
      final task = await _service.createTask(
        title: 'Self',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );

      final eligible = _service.getEligibleBlockers(task.storageKey);
      expect(
        eligible.any((candidate) => candidate.storageKey == task.storageKey),
        isFalse,
      );
    });

    test(
      'getEligibleBlockers excludes tasks that would create a cycle',
      () async {
        final a = await _service.createTask(
          title: 'Task A',
          description: '',
          dueDate: DateTime(2025, 10, 1),
          status: TaskStatus.todo,
        );
        final b = await _service.createTask(
          title: 'Task B',
          description: '',
          dueDate: DateTime(2025, 10, 2),
          status: TaskStatus.todo,
          blockedByKey: a.storageKey,
        );
        final c = await _service.createTask(
          title: 'Task C',
          description: '',
          dueDate: DateTime(2025, 10, 3),
          status: TaskStatus.todo,
          blockedByKey: b.storageKey,
        );

        final eligible = _service.getEligibleBlockers(a.storageKey);
        expect(
          eligible.any((task) => task.storageKey == b.storageKey),
          isFalse,
        );
        expect(
          eligible.any((task) => task.storageKey == c.storageKey),
          isFalse,
        );
      },
    );

    test('getEligibleBlockers returns all tasks for a new task', () async {
      await _service.createTask(
        title: 'Existing',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );

      final eligible = _service.getEligibleBlockers(null);
      expect(eligible.length, equals(1));
    });

    test('updateTask rejects circular dependencies', () async {
      final a = await _service.createTask(
        title: 'Task A',
        description: '',
        dueDate: DateTime(2025, 10, 1),
        status: TaskStatus.todo,
      );
      final b = await _service.createTask(
        title: 'Task B',
        description: '',
        dueDate: DateTime(2025, 10, 2),
        status: TaskStatus.todo,
        blockedByKey: a.storageKey,
      );

      expect(
        () => _service.updateTask(a.storageKey!, blockedByKey: b.storageKey),
        throwsArgumentError,
      );
    });
  });
}
