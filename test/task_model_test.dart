import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/models/task_status.dart';

void main() {
  group('Task model', () {
    late Task baseTask;

    setUp(() {
      baseTask = Task(
        title: 'Fix login bug',
        description: 'The login screen crashes on iOS 16',
        dueDate: DateTime(2025, 6, 15),
        status: TaskStatus.inProgress,
      );
    });

    test('copyWith preserves unchanged fields', () {
      final copy = baseTask.copyWith(title: 'Updated title');
      expect(copy.description, equals(baseTask.description));
      expect(copy.dueDate, equals(baseTask.dueDate));
      expect(copy.status, equals(baseTask.status));
      expect(copy.blockedByKey, isNull);
    });

    test('copyWith updates specified fields', () {
      final copy = baseTask.copyWith(
        title: 'New title',
        status: TaskStatus.done,
      );
      expect(copy.title, equals('New title'));
      expect(copy.status, equals(TaskStatus.done));
      expect(copy.description, equals(baseTask.description));
    });

    test('copyWith can set blockedByKey to null explicitly', () {
      final withBlocker = baseTask.copyWith(blockedByKey: 42);
      expect(withBlocker.blockedByKey, equals(42));

      final cleared = withBlocker.copyWith(blockedByKey: null);
      expect(cleared.blockedByKey, isNull);
    });

    test('copyWith preserves existing blockedByKey when omitted', () {
      final withBlocker = baseTask.copyWith(blockedByKey: 42);
      final copy = withBlocker.copyWith(title: 'Something else');
      expect(copy.blockedByKey, equals(42));
    });

    test('isOverdue is true when dueDate is in the past and not Done', () {
      final overdue = baseTask.copyWith(
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        status: TaskStatus.todo,
      );
      expect(overdue.isOverdue, isTrue);
    });

    test('isOverdue is false when status is Done', () {
      final done = baseTask.copyWith(
        dueDate: DateTime.now().subtract(const Duration(days: 10)),
        status: TaskStatus.done,
      );
      expect(done.isOverdue, isFalse);
    });

    test('isDueSoon is true when dueDate is within 24 hours', () {
      final soon = baseTask.copyWith(
        dueDate: DateTime.now().add(const Duration(hours: 12)),
        status: TaskStatus.todo,
      );
      expect(soon.isDueSoon, isTrue);
    });

    test('isDueSoon is false when dueDate is more than 24 hours away', () {
      final notSoon = baseTask.copyWith(
        dueDate: DateTime.now().add(const Duration(days: 3)),
        status: TaskStatus.todo,
      );
      expect(notSoon.isDueSoon, isFalse);
    });

    test('isDueSoon is false when task is Done', () {
      final done = baseTask.copyWith(
        dueDate: DateTime.now().add(const Duration(hours: 2)),
        status: TaskStatus.done,
      );
      expect(done.isDueSoon, isFalse);
    });
  });

  group('TaskStatus extension', () {
    test('displayName returns human-readable strings', () {
      expect(TaskStatus.todo.displayName, equals('To-Do'));
      expect(TaskStatus.inProgress.displayName, equals('In Progress'));
      expect(TaskStatus.done.displayName, equals('Done'));
    });

    test('sortOrder places inProgress first', () {
      expect(
        TaskStatus.inProgress.sortOrder,
        lessThan(TaskStatus.todo.sortOrder),
      );
      expect(TaskStatus.todo.sortOrder, lessThan(TaskStatus.done.sortOrder));
    });

    test('each status has a unique sort order', () {
      final orders = TaskStatus.values
          .map((status) => status.sortOrder)
          .toSet();
      expect(orders.length, equals(TaskStatus.values.length));
    });

    test('every status exposes color, backgroundColor, and icon', () {
      for (final status in TaskStatus.values) {
        expect(status.color, isNotNull);
        expect(status.backgroundColor, isNotNull);
        expect(status.icon, isNotNull);
      }
    });
  });
}
