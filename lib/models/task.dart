import 'package:hive/hive.dart';

import 'task_status.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  DateTime dueDate;

  @HiveField(3)
  TaskStatus status;

  @HiveField(4)
  int? blockedByKey;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.blockedByKey,
  });

  int? get storageKey {
    final k = key;
    if (k == null) return null;
    if (k is int) return k;
    if (k is String) return int.tryParse(k);
    return null;
  }

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    Object? blockedByKey = _sentinel,
  }) {
    return Task(
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      blockedByKey: blockedByKey == _sentinel
          ? this.blockedByKey
          : blockedByKey as int?,
    );
  }

  bool get isOverdue =>
      dueDate.isBefore(DateTime.now()) && status != TaskStatus.done;

  bool get isDueSoon {
    final difference = dueDate.difference(DateTime.now());
    return difference.inHours >= 0 &&
        difference.inHours <= 24 &&
        status != TaskStatus.done;
  }

  @override
  String toString() =>
      'Task(key: $storageKey, title: $title, status: ${status.displayName})';
}

const _sentinel = Object();
