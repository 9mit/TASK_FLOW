import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../models/task_status.dart';

const _taskBoxName = 'tasks_v2';

class TaskService {
  TaskService._();

  static TaskService? _instance;

  static TaskService get instance => _instance ??= TaskService._();

  Box<Task>? _box;
  Duration _simulatedDelay = Duration.zero;

  Future<void> initialize() async {
    _box = await Hive.openBox<Task>(_taskBoxName);
  }

  Box<Task> get _taskBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('TaskService not initialized. Call initialize() first.');
    }
    return _box!;
  }

  void setSimulatedDelay(Duration delay) {
    _simulatedDelay = delay;
  }

  List<Task> getAllTasks() {
    final tasks = _taskBox.values.toList();
    tasks.sort((first, second) {
      final statusCompare = first.status.sortOrder.compareTo(
        second.status.sortOrder,
      );
      if (statusCompare != 0) {
        return statusCompare;
      }

      final dueDateCompare = first.dueDate.compareTo(second.dueDate);
      if (dueDateCompare != 0) {
        return dueDateCompare;
      }

      return first.title.toLowerCase().compareTo(second.title.toLowerCase());
    });
    return tasks;
  }

  Task? getTaskByKey(int key) => _taskBox.get(key);

  Future<Task> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    int? blockedByKey,
    bool simulateDelay = true,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Task title cannot be empty.');
    }

    _validateDependency(blockedByKey: blockedByKey);

    if (simulateDelay) {
      await _simulateDelay();
    }

    final task = Task(
      title: trimmedTitle,
      description: description.trim(),
      dueDate: dueDate,
      status: status,
      blockedByKey: blockedByKey,
    );

    await _taskBox.add(task);
    return task;
  }

  Future<Task> updateTask(
    int key, {
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    Object? blockedByKey = _sentinel,
    bool simulateDelay = true,
  }) async {
    final existing = getTaskByKey(key);
    if (existing == null) {
      throw ArgumentError('Task with key "$key" was not found.');
    }

    final trimmedTitle = title?.trim();
    if (title != null && trimmedTitle!.isEmpty) {
      throw ArgumentError('Task title cannot be empty.');
    }

    final resolvedBlockedByKey = blockedByKey == _sentinel
        ? existing.blockedByKey
        : blockedByKey as int?;

    _validateDependency(taskKey: key, blockedByKey: resolvedBlockedByKey);

    if (simulateDelay) {
      await _simulateDelay();
    }

    final updated = existing.copyWith(
      title: trimmedTitle,
      description: description?.trim(),
      dueDate: dueDate,
      status: status,
      blockedByKey: resolvedBlockedByKey,
    );

    await _taskBox.put(key, updated);
    return _taskBox.get(key)!;
  }

  Future<void> deleteTask(int key) async {
    await _taskBox.delete(key);

    final impactedTasks = _taskBox.values
        .where((task) => task.blockedByKey == key)
        .toList(growable: false);

    for (final task in impactedTasks) {
      final taskKey = task.storageKey;
      if (taskKey == null) {
        continue;
      }

      await _taskBox.put(taskKey, task.copyWith(blockedByKey: null));
    }
  }

  bool isBlocked(Task task) {
    final blockerKey = task.blockedByKey;
    if (blockerKey == null) {
      return false;
    }

    final blocker = getTaskByKey(blockerKey);
    if (blocker == null) {
      return false;
    }

    return blocker.status != TaskStatus.done;
  }

  Task? getBlocker(Task task) {
    final blockerKey = task.blockedByKey;
    if (blockerKey == null) {
      return null;
    }
    return getTaskByKey(blockerKey);
  }

  List<Task> getEligibleBlockers(int? taskKey) {
    return getAllTasks()
        .where((task) {
          final candidateKey = task.storageKey;
          if (candidateKey == null) {
            return false;
          }

          if (taskKey != null && candidateKey == taskKey) {
            return false;
          }

          return taskKey == null || !_wouldCreateCycle(taskKey, candidateKey);
        })
        .toList(growable: false);
  }

  Stream<BoxEvent> watchBox() => _taskBox.watch();

  Future<void> clearAllTasks() async {
    await _taskBox.clear();
  }

  static void dispose() {
    _instance = null;
  }

  Future<void> close() async {
    if (_box?.isOpen == true) {
      await _box!.close();
    }
  }

  void _validateDependency({int? taskKey, required int? blockedByKey}) {
    if (blockedByKey == null) {
      return;
    }

    if (taskKey != null && blockedByKey == taskKey) {
      throw ArgumentError('A task cannot be blocked by itself.');
    }

    final blocker = getTaskByKey(blockedByKey);
    if (blocker == null) {
      throw ArgumentError('The selected blocker task no longer exists.');
    }

    if (taskKey != null && _wouldCreateCycle(taskKey, blockedByKey)) {
      throw ArgumentError('This dependency would create a circular reference.');
    }
  }

  bool _wouldCreateCycle(int targetKey, int candidateKey) {
    final visited = <int>{};
    var currentKey = candidateKey;

    while (!visited.contains(currentKey)) {
      if (currentKey == targetKey) {
        return true;
      }

      visited.add(currentKey);
      final currentTask = getTaskByKey(currentKey);
      final nextKey = currentTask?.blockedByKey;
      if (nextKey == null) {
        return false;
      }

      currentKey = nextKey;
    }

    return false;
  }

  Future<void> _simulateDelay() async {
    if (_simulatedDelay == Duration.zero) {
      return;
    }

    await Future<void>.delayed(_simulatedDelay);
  }
}

const _sentinel = Object();
