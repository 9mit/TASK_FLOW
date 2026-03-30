import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'task_status.g.dart';

@HiveType(typeId: 1)
enum TaskStatus {
  @HiveField(0)
  todo,

  @HiveField(1)
  inProgress,

  @HiveField(2)
  done,
}

extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To-Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:
        return const Color(0xFF2563EB);
      case TaskStatus.inProgress:
        return const Color(0xFFD97706);
      case TaskStatus.done:
        return const Color(0xFF16A34A);
    }
  }

  Color get backgroundColor {
    switch (this) {
      case TaskStatus.todo:
        return const Color(0xFFEFF6FF);
      case TaskStatus.inProgress:
        return const Color(0xFFFFF7ED);
      case TaskStatus.done:
        return const Color(0xFFF0FDF4);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked_rounded;
      case TaskStatus.inProgress:
        return Icons.timelapse_rounded;
      case TaskStatus.done:
        return Icons.check_circle_rounded;
    }
  }

  int get sortOrder {
    switch (this) {
      case TaskStatus.inProgress:
        return 0;
      case TaskStatus.todo:
        return 1;
      case TaskStatus.done:
        return 2;
    }
  }
}
