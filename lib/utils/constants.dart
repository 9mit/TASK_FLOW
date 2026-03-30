class AppRoutes {
  AppRoutes._();

  static const String taskList = '/';
  static const String taskForm = '/task-form';
}

class AppStrings {
  AppStrings._();

  static const String appName = 'TaskFlow';
  static const String tasks = 'Tasks';
  static const String newTask = 'New Task';
  static const String editTask = 'Edit Task';
  static const String saveTask = 'Save Task';
  static const String saving = 'Saving...';
  static const String deleteTask = 'Delete Task';
  static const String noTasks = 'No tasks yet';
  static const String noTasksSubtitle =
      'Create your first task to start organizing the work ahead.';
  static const String noResults = 'No matching tasks';
  static const String noResultsSubtitle =
      'Try a different title search or switch the status filter.';
  static const String searchPlaceholder = 'Search task titles...';
  static const String blockedBy = 'Blocked By';
  static const String noDependency = 'No dependency';
  static const String taskDeleted = 'Task deleted';
  static const String taskCreated = 'Task created';
  static const String taskUpdated = 'Task updated';
  static const String confirmDelete = 'Delete this task?';
  static const String confirmDeleteBody =
      'This action cannot be undone. Dependent tasks will become unblocked.';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String title = 'Title';
  static const String titleHint = 'What needs to happen?';
  static const String description = 'Description';
  static const String descriptionHint =
      'Add notes, scope, or handoff details for this task.';
  static const String dueDate = 'Due Date';
  static const String status = 'Status';
  static const String blockedBadge = 'Blocked';
  static const String dueSoon = 'Due Soon';
  static const String overdue = 'Overdue';
  static const String all = 'All';
  static const String autosaveHint =
      'Draft changes are saved automatically until you submit.';
  static const String dependencyHint =
      'This task stays greyed out until its dependency is marked Done.';
}

class AppDimensions {
  AppDimensions._();

  static const double pagePadding = 16.0;
  static const double cardRadius = 20.0;
  static const double chipRadius = 20.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 16.0;
  static const double iconSize = 20.0;
  static const double avatarSize = 40.0;
  static const double fabSize = 56.0;
}
