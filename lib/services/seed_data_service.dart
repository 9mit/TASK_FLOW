import 'package:hive/hive.dart';

import '../models/task_status.dart';
import 'task_service.dart';

class SeedDataService {
  SeedDataService._();

  static const _seedBoxName = 'taskflow_meta_v2';
  static const _seedKey = 'seeded_v2';

  static Future<void> seedIfFirstRun() async {
    final metaBox = await Hive.openBox<dynamic>(_seedBoxName);
    if (metaBox.get(_seedKey, defaultValue: false) == true) {
      await metaBox.close();
      return;
    }

    final service = TaskService.instance;
    final now = DateTime.now();

    final designTask = await service.createTask(
      title: 'Finalize design system',
      description:
          'Lock the mobile type scale, spacing tokens, and component states.',
      dueDate: now.subtract(const Duration(days: 1)),
      status: TaskStatus.done,
      simulateDelay: false,
    );

    final apiTask = await service.createTask(
      title: 'Ship sync endpoints',
      description:
          'Implement mobile-safe CRUD endpoints and conflict resolution hooks.',
      dueDate: now.add(const Duration(days: 2)),
      status: TaskStatus.inProgress,
      blockedByKey: designTask.storageKey,
      simulateDelay: false,
    );

    await service.createTask(
      title: 'QA the dependency flow',
      description:
          'Test blocked-task visuals, save states, and release edge cases.',
      dueDate: now.add(const Duration(days: 4)),
      status: TaskStatus.todo,
      blockedByKey: apiTask.storageKey,
      simulateDelay: false,
    );

    await service.createTask(
      title: 'Prepare launch checklist',
      description:
          'Document release tasks, screenshots, and store listing approvals.',
      dueDate: now.add(const Duration(days: 6)),
      status: TaskStatus.todo,
      simulateDelay: false,
    );

    await service.createTask(
      title: 'Audit motion polish',
      description:
          'Review list transitions, loading states, and scroll performance.',
      dueDate: now.add(const Duration(hours: 18)),
      status: TaskStatus.inProgress,
      simulateDelay: false,
    );

    await metaBox.put(_seedKey, true);
    await metaBox.close();
  }
}
