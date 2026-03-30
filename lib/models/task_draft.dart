import 'task_status.dart';

class TaskDraft {
  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskStatus status;
  final int? blockedByKey;
  final int? editingTaskKey;

  const TaskDraft({
    this.title = '',
    this.description = '',
    this.dueDate,
    this.status = TaskStatus.todo,
    this.blockedByKey,
    this.editingTaskKey,
  });

  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      dueDate == null &&
      status == TaskStatus.todo &&
      blockedByKey == null &&
      editingTaskKey == null;

  bool get isEditMode => editingTaskKey != null;

  bool get hasDependency => blockedByKey != null;

  TaskDraft copyWith({
    String? title,
    String? description,
    Object? dueDate = _sentinel,
    TaskStatus? status,
    Object? blockedByKey = _sentinel,
    Object? editingTaskKey = _sentinel,
  }) {
    return TaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate == _sentinel ? this.dueDate : dueDate as DateTime?,
      status: status ?? this.status,
      blockedByKey: blockedByKey == _sentinel
          ? this.blockedByKey
          : blockedByKey as int?,
      editingTaskKey: editingTaskKey == _sentinel
          ? this.editingTaskKey
          : editingTaskKey as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'status': status.index,
      'blockedByKey': blockedByKey,
      'editingTaskKey': editingTaskKey,
    };
  }

  factory TaskDraft.fromJson(Map<String, dynamic> json) {
    final dueDateMillis = json['dueDate'];
    final statusIndex = json['status'];

    return TaskDraft(
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      dueDate: dueDateMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(dueDateMillis)
          : null,
      status:
          statusIndex is int &&
              statusIndex >= 0 &&
              statusIndex < TaskStatus.values.length
          ? TaskStatus.values[statusIndex]
          : TaskStatus.todo,
      blockedByKey: json['blockedByKey'] as int?,
      editingTaskKey: json['editingTaskKey'] as int?,
    );
  }

  @override
  String toString() {
    return 'TaskDraft(title: $title, status: ${status.displayName}, '
        'editingTaskKey: $editingTaskKey)';
  }
}

const _sentinel = Object();
