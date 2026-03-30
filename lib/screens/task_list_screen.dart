import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/draft_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/search_filter_bar.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/task_card.dart';
import '../widgets/task_summary_banner.dart';
import 'task_form_screen.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredTasksAsync = ref.watch(filteredTaskListProvider);
    final allTasksAsync = ref.watch(taskListProvider);
    final activeSearch = ref.watch(debouncedSearchQueryProvider);
    final activeFilter = ref.watch(activeFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: <Widget>[
        // Faux-Mesh Background
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppTheme.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    AppTheme.secondary.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: <Widget>[
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppTheme.background.withValues(alpha: 0.8),
                surfaceTintColor: Colors.transparent,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                titleSpacing: 20,
                title: Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[AppTheme.primary, AppTheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          AppStrings.appName,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.5,
                          ),
                        ),
                        allTasksAsync.maybeWhen(
                          data: (tasks) => Text(
                            'Managing ${tasks.length} active tasks',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.sort_rounded, size: 22),
                    color: AppTheme.textPrimary,
                    onPressed: () => _showSortSheet(context),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(140),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: const Column(
                      children: <Widget>[
                        SearchFilterBar(),
                      ],
                    ),
                  ),
                ),
              ),
          if (activeSearch.isEmpty && activeFilter == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16),
                child: TaskSummaryBanner(),
              ),
            ),
          filteredTasksAsync.maybeWhen(
            data: (tasks) => tasks.isEmpty
                ? const SliverToBoxAdapter(child: SizedBox.shrink())
                : SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        activeSearch.isNotEmpty || activeFilter != null
                            ? '${tasks.length} result${tasks.length == 1 ? '' : 's'}'
                            : 'All Tasks',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ),
            orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          filteredTasksAsync.when(
            loading: () => const SliverFillRemaining(
              child: ShimmerLoading(),
            ),
            error: (error, _) =>
                SliverFillRemaining(child: _ErrorView(error: error.toString())),
            data: (tasks) {
              if (tasks.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyView(
                    isFiltered: activeSearch.isNotEmpty || activeFilter != null,
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final task = tasks[index];
                    final taskKey = task.storageKey;

                    return TaskCard(
                      key: ValueKey(taskKey),
                      task: task,
                      searchQuery: activeSearch,
                      onTap: () => _openEdit(context, ref, task),
                      onDelete: taskKey == null
                          ? null
                          : () => _deleteTask(context, ref, taskKey),
                    );
                  }, childCount: tasks.length),
                ),
              );
            },
          ),
        ], // slivers
      ), // CustomScrollView
        ], // children
      ), // Stack
      floatingActionButton: _AnimatedFab(
        onPressed: () => _openCreate(context, ref),
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    final draft = ref.read(taskDraftProvider);
    if (draft.isEditMode || draft.isEmpty) {
      ref.read(taskDraftProvider.notifier).initNew();
    }

    Navigator.of(context).push(_slideRoute(const TaskFormScreen()));
  }

  void _openEdit(BuildContext context, WidgetRef ref, Task task) {
    final taskKey = task.storageKey;
    if (taskKey == null) {
      return;
    }

    final draft = ref.read(taskDraftProvider);
    if (draft.editingTaskKey != taskKey) {
      ref
          .read(taskDraftProvider.notifier)
          .initEdit(
            taskKey: taskKey,
            title: task.title,
            description: task.description,
            dueDate: task.dueDate,
            status: task.status,
            blockedByKey: task.blockedByKey,
          );
    }

    Navigator.of(context).push(_slideRoute(const TaskFormScreen()));
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    int taskKey,
  ) async {
    final success = await ref
        .read(taskOperationProvider.notifier)
        .deleteTask(taskKey);
    if (!success || !context.mounted) {
      return;
    }

    ref.read(taskOperationProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: <Widget>[
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(AppStrings.taskDeleted)),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => const _SortSheet(),
    );
  }

  PageRouteBuilder<void> _slideRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, animation, __, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}

class _AnimatedFab extends StatelessWidget {
  const _AnimatedFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          AppStrings.newTask,
          style: AppTextStyles.labelLarge.copyWith(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.task_alt_rounded,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? AppStrings.noResults : AppStrings.noTasks,
              style: AppTextStyles.headlineMedium.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? AppStrings.noResultsSubtitle
                  : AppStrings.noTasksSubtitle,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}



class _SortSheet extends StatelessWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Sorting', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Tasks are ordered by status priority, then by the nearest due date.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          _SortOption(
            label: 'Status + Due Date',
            subtitle: 'In Progress -> To-Do -> Done, then earliest first',
            icon: Icons.sort_rounded,
            isSelected: true,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Blocked tasks stay muted until their dependency reaches Done.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppTheme.secondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryLight
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppTheme.primary : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
