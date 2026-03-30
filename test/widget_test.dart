import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/models/task_status.dart';
import 'package:taskflow/providers/draft_provider.dart';
import 'package:taskflow/screens/task_form_screen.dart';
import 'package:taskflow/screens/task_list_screen.dart';
import 'package:taskflow/widgets/task_card.dart';
import 'package:taskflow/services/task_draft_storage_service.dart';
import 'package:taskflow/services/task_service.dart';
import 'package:taskflow/utils/constants.dart';

Future<void> _initializeServices() async {
  // Use a unique path for every run to avoid lock issues
  final hivePath = 'widget_test_data_${DateTime.now().millisecondsSinceEpoch}';
  
  Hive.init(hivePath);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TaskStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskAdapter());
  }

  await TaskService.instance.initialize();
  TaskService.instance.setSimulatedDelay(Duration.zero);
  
  await TaskDraftStorageService.instance.initialize();
}

Widget _wrapInApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: child,
      debugShowCheckedModeBanner: false,
    ),
  );
}

Widget _wrapWithContainer(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: child),
  );
}

void main() {
  setUpAll(_initializeServices);

  tearDown(() async {
    final tasks = TaskService.instance.getAllTasks();
    for (final task in tasks) {
      final taskKey = task.storageKey;
      if (taskKey != null) {
        await TaskService.instance.deleteTask(taskKey);
      }
    }
    await TaskDraftStorageService.instance.clearDraft();
  });

  tearDownAll(() async {
    await TaskService.instance.close();
    await TaskDraftStorageService.instance.close();
    await Hive.deleteFromDisk();
  });

  group('TaskListScreen', () {
    testWidgets('shows empty state when no tasks exist', (tester) async {
      await tester.pumpWidget(_wrapInApp(const TaskListScreen()));
      await tester.pump();

      expect(find.text(AppStrings.noTasks), findsOneWidget);
    });

    testWidgets('shows app name in header', (tester) async {
      await tester.pumpWidget(_wrapInApp(const TaskListScreen()));
      await tester.pump();

      expect(find.text(AppStrings.appName), findsOneWidget);
    });

    testWidgets('shows add task FAB', (tester) async {
      await tester.pumpWidget(_wrapInApp(const TaskListScreen()));
      await tester.pump();

      expect(find.text(AppStrings.newTask), findsOneWidget);
    });

    testWidgets('shows task card when tasks exist', (tester) async {
      await tester.runAsync(() async {
        await TaskService.instance.createTask(
          title: 'Widget Test Task',
          description: 'Testing the UI',
          dueDate: DateTime(2025, 12, 31),
          status: TaskStatus.todo,
        );
      });

      await tester.pumpWidget(_wrapInApp(const TaskListScreen()));
      await tester.pump(); // Start building
      await tester.pump(); // Finish build or microtasks

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('Widget Test Task'), findsOneWidget);
    });

    testWidgets('search filters tasks by title', (tester) async {
      await TaskService.instance.createTask(
        title: 'Alpha Task',
        description: '',
        dueDate: DateTime(2025, 12, 31),
        status: TaskStatus.todo,
      );
      await TaskService.instance.createTask(
        title: 'Beta Task',
        description: '',
        dueDate: DateTime(2025, 12, 31),
        status: TaskStatus.todo,
      );

      await tester.pumpWidget(_wrapInApp(const TaskListScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Alpha');
      await tester.pump(const Duration(milliseconds: 400)); // Wait for debounce
      await tester.pump();

      expect(find.text('Alpha Task'), findsOneWidget);
      expect(find.text('Beta Task'), findsNothing);
    });
  });

  group('TaskFormScreen', () {
    testWidgets('shows New Task title in create mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(taskDraftProvider.notifier).initNew();

      await tester.pumpWidget(
        _wrapWithContainer(container, const TaskFormScreen()),
      );
      await tester.pump();

      expect(find.text(AppStrings.newTask), findsOneWidget);
      expect(find.text('Auto-saved draft'), findsOneWidget);
    });

    testWidgets('shows Edit Task title in edit mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(taskDraftProvider.notifier)
          .initEdit(
            taskKey: 1,
            title: 'Existing Task',
            description: 'Desc',
            dueDate: DateTime(2025, 10, 1),
            status: TaskStatus.todo,
          );

      await tester.pumpWidget(
        _wrapWithContainer(container, const TaskFormScreen()),
      );
      await tester.pump();

      expect(find.text(AppStrings.editTask), findsOneWidget);
    });

    testWidgets('validation shows error for empty title', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(taskDraftProvider.notifier).initNew();

      await tester.pumpWidget(
        _wrapWithContainer(container, const TaskFormScreen()),
      );
      await tester.pump();

      await tester.tap(find.text(AppStrings.saveTask));
      await tester.pump();

      expect(find.text('Title is required'), findsOneWidget);
    });

    testWidgets('all three status options are shown', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(taskDraftProvider.notifier).initNew();

      await tester.pumpWidget(
        _wrapWithContainer(container, const TaskFormScreen()),
      );
      await tester.pump();

      expect(find.text('To-Do'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
