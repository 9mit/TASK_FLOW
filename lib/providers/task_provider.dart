import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../services/task_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService.instance;
});

final taskListProvider =
    StateNotifierProvider<TaskListNotifier, AsyncValue<List<Task>>>((ref) {
      return TaskListNotifier(ref.read(taskServiceProvider));
    });

class TaskListNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  TaskListNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
    _subscription = _service.watchBox().listen((_) => _load());
  }

  final TaskService _service;
  StreamSubscription<BoxEvent>? _subscription;

  void _load() {
    try {
      state = AsyncValue.data(_service.getAllTasks());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final debouncedSearchQueryProvider = StateProvider<String>((ref) => '');
final activeFilterProvider = StateProvider<TaskStatus?>((ref) => null);

final filteredTaskListProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(taskListProvider);
  final query = ref.watch(debouncedSearchQueryProvider).trim().toLowerCase();
  final activeFilter = ref.watch(activeFilterProvider);

  return tasksAsync.whenData((tasks) {
    return tasks
        .where((task) {
          final matchesQuery =
              query.isEmpty || task.title.toLowerCase().contains(query);
          final matchesFilter =
              activeFilter == null || task.status == activeFilter;
          return matchesQuery && matchesFilter;
        })
        .toList(growable: false);
  });
});

final taskOperationProvider =
    StateNotifierProvider<TaskOperationNotifier, TaskOperationState>((ref) {
      return TaskOperationNotifier(ref.read(taskServiceProvider));
    });

enum OperationStatus { idle, loading, success, error }

class TaskOperationState {
  const TaskOperationState({
    this.status = OperationStatus.idle,
    this.errorMessage,
    this.result,
  });

  final OperationStatus status;
  final String? errorMessage;
  final Task? result;

  TaskOperationState copyWith({
    OperationStatus? status,
    Object? errorMessage = _sentinel,
    Object? result = _sentinel,
  }) {
    return TaskOperationState(
      status: status ?? this.status,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      result: result == _sentinel ? this.result : result as Task?,
    );
  }

  bool get isLoading => status == OperationStatus.loading;
  bool get isSuccess => status == OperationStatus.success;
  bool get hasError => status == OperationStatus.error;
}

class TaskOperationNotifier extends StateNotifier<TaskOperationState> {
  TaskOperationNotifier(this._service) : super(const TaskOperationState());

  final TaskService _service;

  Future<bool> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    int? blockedByKey,
  }) async {
    state = state.copyWith(
      status: OperationStatus.loading,
      errorMessage: null,
      result: null,
    );

    try {
      final task = await _service.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        status: status,
        blockedByKey: blockedByKey,
      );
      state = state.copyWith(
        status: OperationStatus.success,
        errorMessage: null,
        result: task,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: OperationStatus.error,
        errorMessage: error.toString(),
        result: null,
      );
      return false;
    }
  }

  Future<bool> updateTask(
    int key, {
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskStatus status,
    Object? blockedByKey = _sentinel,
  }) async {
    state = state.copyWith(
      status: OperationStatus.loading,
      errorMessage: null,
      result: null,
    );

    try {
      final task = await _service.updateTask(
        key,
        title: title,
        description: description,
        dueDate: dueDate,
        status: status,
        blockedByKey: blockedByKey,
      );
      state = state.copyWith(
        status: OperationStatus.success,
        errorMessage: null,
        result: task,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: OperationStatus.error,
        errorMessage: error.toString(),
        result: null,
      );
      return false;
    }
  }

  Future<bool> deleteTask(int key) async {
    state = state.copyWith(
      status: OperationStatus.loading,
      errorMessage: null,
      result: null,
    );

    try {
      await _service.deleteTask(key);
      state = state.copyWith(
        status: OperationStatus.success,
        errorMessage: null,
        result: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: OperationStatus.error,
        errorMessage: error.toString(),
        result: null,
      );
      return false;
    }
  }

  void reset() {
    state = const TaskOperationState();
  }
}

const _sentinel = Object();
