import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'highlighted_text.dart';
import 'status_badge.dart';

class TaskCard extends ConsumerStatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.searchQuery,
    required this.onTap,
    required this.onDelete,
  });

  final Task task;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  void _onHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    if (!ref.read(taskServiceProvider).isBlocked(widget.task)) {
      widget.onTap();
    }
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(taskServiceProvider);
    final isBlocked = service.isBlocked(widget.task);
    final blocker = service.getBlocker(widget.task);
    final isDone = widget.task.status == TaskStatus.done;
    final dateLabel = DateFormat('MMM d, y').format(widget.task.dueDate);

    final scale = _isPressed ? 0.98 : 1.0;
    final shadow = isBlocked
        ? const <BoxShadow>[]
        : (_isHovered ? AppTheme.cardHoverShadow : AppTheme.cardShadow);

    return Dismissible(
      key: ValueKey(widget.task.storageKey ?? widget.task.title),
      direction: widget.onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: const _DeleteBackground(),
      confirmDismiss: widget.onDelete == null ? null : (_) => _confirmDelete(context),
      onDismissed: (_) => widget.onDelete?.call(),
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        cursor: isBlocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: isBlocked ? null : _onTapDown,
          onTapUp: isBlocked ? null : _onTapUp,
          onTapCancel: isBlocked ? null : _onTapCancel,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: shadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isBlocked
                          ? AppTheme.blockedBackground.withValues(alpha: 0.6)
                          : (_isHovered
                              ? AppTheme.surfaceVariant.withValues(alpha: 0.95)
                              : AppTheme.surface.withValues(alpha: 0.85)),
                      border: Border.all(
                        color: isBlocked
                            ? AppTheme.blockedBorder
                            : (_isHovered
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.06)),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        // Status color accent bar
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 5,
                            decoration: BoxDecoration(
                              color: isBlocked
                                  ? AppTheme.textDisabled.withValues(alpha: 0.4)
                                  : widget.task.status.color,
                              boxShadow: [
                                if (!isBlocked && !_isHovered)
                                  BoxShadow(
                                    color: widget.task.status.color.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 0,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(
                                    child: HighlightedText(
                                      text: widget.task.title,
                                      highlight: widget.searchQuery,
                                      baseStyle: AppTextStyles.titleMedium.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isBlocked
                                            ? AppTheme.textDisabled
                                            : AppTheme.textPrimary,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  StatusBadge(status: widget.task.status, compact: true),
                                ],
                              ),
                              if (widget.task.description.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 12),
                                Text(
                                  widget.task.description,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isBlocked
                                        ? AppTheme.textDisabled
                                        : AppTheme.textSecondary.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (isBlocked && blocker != null) ...<Widget>[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.lock_person_rounded,
                                        size: 15,
                                        color: AppTheme.textDisabled,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Waiting on ${blocker.title}',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: AppTheme.textDisabled,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _dueDateColor(widget.task, isBlocked).withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 13,
                                          color: _dueDateColor(widget.task, isBlocked),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          dateLabel,
                                          style: AppTextStyles.labelMedium.copyWith(
                                            color: _dueDateColor(widget.task, isBlocked),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.task.isOverdue && !isBlocked) ...<Widget>[
                                    const SizedBox(width: 10),
                                    const _PillBadge(
                                      label: AppStrings.overdue,
                                      color: AppTheme.error,
                                    ),
                                  ] else if (widget.task.isDueSoon && !isBlocked) ...<Widget>[
                                    const SizedBox(width: 10),
                                    const _PillBadge(
                                      label: AppStrings.dueSoon,
                                      color: AppTheme.warning,
                                    ),
                                  ],
                                  const Spacer(),
                                  if (isBlocked)
                                    const _BlockedBadge()
                                  else
                                    Icon(
                                      Icons.east_rounded,
                                      size: 16,
                                      color: AppTheme.textDisabled.withValues(alpha: 0.5),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _dueDateColor(Task task, bool isBlocked) {
    if (isBlocked) {
      return AppTheme.textDisabled;
    }
    if (task.isOverdue) {
      return AppTheme.error;
    }
    if (task.isDueSoon) {
      return AppTheme.warning;
    }
    return AppTheme.textTertiary;
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        title: Text(AppStrings.confirmDelete, style: AppTextStyles.titleLarge),
        content: Text(
          AppStrings.confirmDeleteBody,
          style: AppTextStyles.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppStrings.cancel, style: AppTextStyles.labelLarge),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3), width: 1),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            'Delete',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppTheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _BlockedBadge extends StatelessWidget {
  const _BlockedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.lock_rounded,
            size: 12,
            color: AppTheme.textDisabled,
          ),
          const SizedBox(width: 4),
          Text(
            AppStrings.blockedBadge,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppTheme.textDisabled,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
