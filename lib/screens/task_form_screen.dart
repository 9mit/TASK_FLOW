import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../providers/draft_provider.dart';
import '../providers/task_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/status_badge.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(taskDraftProvider);
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);

    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _buttonAnimController.dispose();
    super.dispose();
  }

  // ─── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final draft = ref.read(taskDraftProvider);
    if (draft.dueDate == null) {
      _showSnackError('Please select a due date.');
      return;
    }

    await _buttonAnimController.forward().then(
      (_) => _buttonAnimController.reverse(),
    );

    bool success;
    if (draft.isEditMode) {
      success = await ref
          .read(taskOperationProvider.notifier)
          .updateTask(
            draft.editingTaskKey!,
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: draft.dueDate!,
            status: draft.status,
            blockedByKey: draft.blockedByKey,
          );
    } else {
      success = await ref
          .read(taskOperationProvider.notifier)
          .createTask(
            title: _titleController.text,
            description: _descriptionController.text,
            dueDate: draft.dueDate!,
            status: draft.status,
            blockedByKey: draft.blockedByKey,
          );
    }

    if (!mounted) return;

    if (success) {
      final wasEdit = draft.isEditMode;
      ref.read(taskDraftProvider.notifier).clear();
      ref.read(taskOperationProvider.notifier).reset();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                wasEdit ? Icons.edit_rounded : Icons.add_task_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(wasEdit ? AppStrings.taskUpdated : AppStrings.taskCreated),
            ],
          ),
        ),
      );
    } else {
      final err = ref.read(taskOperationProvider).errorMessage;
      ref.read(taskOperationProvider.notifier).reset();
      _showSnackError(err ?? 'An error occurred. Please try again.');
    }
  }

  void _showSnackError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  Future<void> _pickDate() async {
    final draft = ref.read(taskDraftProvider);
    final now = DateTime.now();
    final initial = draft.dueDate != null && draft.dueDate!.isAfter(now)
        ? draft.dueDate!
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primary,
            onPrimary: Colors.white,
            surface: AppTheme.surface,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(taskDraftProvider.notifier).setDueDate(picked);
    }
  }

  Future<void> _confirmAndDelete(int taskKey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppStrings.confirmDelete, style: AppTextStyles.titleLarge),
        content: Text(
          AppStrings.confirmDeleteBody,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(taskOperationProvider.notifier)
        .deleteTask(taskKey);
    if (!mounted) return;
    if (success) {
      ref.read(taskDraftProvider.notifier).clear();
      ref.read(taskOperationProvider.notifier).reset();
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.taskDeleted)));
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(taskDraftProvider.select((d) => d.isEditMode));
    final editingTaskKey = ref.watch(taskDraftProvider.select((d) => d.editingTaskKey));
    final dueDate = ref.watch(taskDraftProvider.select((d) => d.dueDate));
    final status = ref.watch(taskDraftProvider.select((d) => d.status));
    final blockedByKey = ref.watch(taskDraftProvider.select((d) => d.blockedByKey));
    
    final opState = ref.watch(taskOperationProvider);
    final isLoading = opState.isLoading;
    final dateFormat = DateFormat('EEE, MMM d, y');
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background.withValues(alpha: 0.75),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: Colors.transparent),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppTheme.textPrimary,
            onPressed: isLoading ? null : () => Navigator.pop(context),
          ),
          title: Text(
            isEditMode ? AppStrings.editTask : AppStrings.newTask,
          ),
          actions: [
            if (isEditMode)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                color: AppTheme.error,
                tooltip: 'Delete task',
                onPressed: isLoading
                    ? null
                    : () => _confirmAndDelete(editingTaskKey!),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.pagePadding),
            physics: const BouncingScrollPhysics(),
            children: [
              const _AutosaveNotice(),
              const SizedBox(height: 24),

              // ── Title ──────────────────────────────────────────────────
              const _FieldLabel(label: AppStrings.title, required: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 120,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: AppStrings.titleHint,
                  counterText: '',
                  prefixIcon: _FieldIcon(icon: Icons.title_rounded),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (v.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Description ────────────────────────────────────────────
              const _FieldLabel(label: AppStrings.description),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                enabled: !isLoading,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: AppStrings.descriptionHint,
                  counterText: '',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              // ── Due Date ───────────────────────────────────────────────
              const _FieldLabel(label: AppStrings.dueDate, required: true),
              const SizedBox(height: 8),
              _DatePickerTile(
                dueDate: dueDate,
                isLoading: isLoading,
                dateFormat: dateFormat,
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),

              // ── Status ─────────────────────────────────────────────────
              const _FieldLabel(label: AppStrings.status, required: true),
              const SizedBox(height: 8),
              _StatusSelector(
                selected: status,
                enabled: !isLoading,
                onChanged: (s) =>
                    ref.read(taskDraftProvider.notifier).setStatus(s),
              ),
              const SizedBox(height: 20),

              // ── Blocked By ─────────────────────────────────────────────
              const _FieldLabel(label: AppStrings.blockedBy),
              const SizedBox(height: 4),
              Text(
                AppStrings.dependencyHint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              _BlockedBySelector(
                currentTaskKey: editingTaskKey,
                selectedKey: blockedByKey,
                enabled: !isLoading,
                onChanged: (key) =>
                    ref.read(taskDraftProvider.notifier).setBlockedByKey(key),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),

        // ── Save Button ────────────────────────────────────────────────────
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.6),
                border: const Border(top: BorderSide(color: AppTheme.border, width: 1)),
              ),
              child: ScaleTransition(
                scale: _buttonScale,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? const _LoadingButton(key: ValueKey('loading'))
                      : _SaveButton(
                          key: const ValueKey('save'),
                          isEditMode: isEditMode,
                          onPressed: _submit,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Field Components ──────────────────────────────────────────────────────────

class _AutosaveNotice extends StatelessWidget {
  const _AutosaveNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              size: 18,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-saved draft', style: AppTextStyles.titleMedium),
                const SizedBox(height: 3),
                Text(
                  AppStrings.autosaveHint,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
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

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppTheme.error,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

class _FieldIcon extends StatelessWidget {
  final IconData icon;
  const _FieldIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 10),
      child: Icon(icon, size: 18, color: AppTheme.textTertiary),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime? dueDate;
  final bool isLoading;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _DatePickerTile({
    required this.dueDate,
    required this.isLoading,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = dueDate != null;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? AppTheme.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: hasDate ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: hasDate ? AppTheme.primary : AppTheme.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasDate ? dateFormat.format(dueDate!) : 'Select a due date',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: hasDate ? AppTheme.textPrimary : AppTheme.textTertiary,
                  fontWeight: hasDate ? FontWeight.w500 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Selector ──────────────────────────────────────────────────────────

class _StatusSelector extends StatelessWidget {
  final TaskStatus selected;
  final bool enabled;
  final ValueChanged<TaskStatus> onChanged;

  const _StatusSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: TaskStatus.values.asMap().entries.map((entry) {
          final idx = entry.key;
          final status = entry.value;
          final isSelected = status == selected;
          final isLast = idx == TaskStatus.values.length - 1;

          return Expanded(
            child: GestureDetector(
              onTap: enabled ? () => onChanged(status) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: isLast ? 0 : 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? status.backgroundColor.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? status.color.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? status.color.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? status.color.withValues(alpha: 0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        status.icon,
                        size: 16,
                        color: isSelected
                            ? status.color
                            : AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status.displayName,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected
                            ? status.color
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Blocked By Selector ──────────────────────────────────────────────────────

class _BlockedBySelector extends ConsumerWidget {
  final int? currentTaskKey;
  final int? selectedKey;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _BlockedBySelector({
    required this.currentTaskKey,
    required this.selectedKey,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(taskServiceProvider);
    final eligible = service.getEligibleBlockers(currentTaskKey);
    final selectedTask = selectedKey != null
        ? service.getTaskByKey(selectedKey!)
        : null;

    return GestureDetector(
      onTap: enabled
          ? () => _showPicker(context, eligible, selectedKey, onChanged)
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedKey != null
                  ? AppTheme.warning.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: selectedKey != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selectedKey != null
                    ? Icons.lock_outline_rounded
                    : Icons.link_off_rounded,
                size: 18,
                color: selectedKey != null
                    ? AppTheme.warning
                    : AppTheme.textTertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedKey != null
                          ? 'Blocked by:'
                          : AppStrings.noDependency,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    if (selectedTask != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedTask.title,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            status: selectedTask.status,
                            compact: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context,
    List<Task> eligible,
    int? selectedKey,
    ValueChanged<int?> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            minChildSize: 0.35,
            expand: false,
            builder: (_, scrollController) => _BlockerPickerSheet(
              eligible: eligible,
              selectedKey: selectedKey,
              scrollController: scrollController,
              onChanged: (key) {
                onChanged(key);
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockerPickerSheet extends StatefulWidget {
  final List<Task> eligible;
  final int? selectedKey;
  final ScrollController scrollController;
  final ValueChanged<int?> onChanged;

  const _BlockerPickerSheet({
    required this.eligible,
    required this.selectedKey,
    required this.scrollController,
    required this.onChanged,
  });

  @override
  State<_BlockerPickerSheet> createState() => _BlockerPickerSheetState();
}

class _BlockerPickerSheetState extends State<_BlockerPickerSheet> {
  String _search = '';

  List<Task> get _filtered {
    if (_search.isEmpty) return widget.eligible;
    return widget.eligible
        .where((t) => t.title.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            children: [
              Text('Select Dependency', style: AppTextStyles.headlineMedium),
              const Spacer(),
              if (widget.selectedKey != null)
                TextButton(
                  onPressed: () => widget.onChanged(null),
                  child: Text(
                    'Clear',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppTheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: AppTextStyles.bodyMedium,
            decoration: const InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppTheme.textTertiary,
                ),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        size: 36,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.eligible.isEmpty
                            ? 'No other tasks available'
                            : 'No matching tasks',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60, endIndent: 16),
                  itemBuilder: (ctx, i) {
                    final task = _filtered[i];
                    final taskKey = task.storageKey;
                    final isSelected =
                        taskKey != null && taskKey == widget.selectedKey;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: task.status.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          task.status.icon,
                          size: 16,
                          color: task.status.color,
                        ),
                      ),
                      title: Text(
                        task.title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        task.status.displayName,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: task.status.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            )
                          : null,
                      selected: isSelected,
                      selectedTileColor: AppTheme.primaryLight,
                      onTap: taskKey == null
                          ? null
                          : () => widget.onChanged(taskKey),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Bottom Buttons ───────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onPressed;

  const _SaveButton({
    super.key,
    required this.isEditMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEditMode ? Icons.check_rounded : Icons.add_task_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditMode ? 'Update Task' : AppStrings.saveTask,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  const _LoadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.border,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            AppStrings.saving,
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
