import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../providers/task_provider.dart';
import '../providers/draft_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'highlighted_text.dart';
import '../screens/task_form_screen.dart'; // Needed for push to Edit

class SearchFilterBar extends ConsumerStatefulWidget {
  const SearchFilterBar({super.key});

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textEditingController = TextEditingController();
  Timer? _debounce;
  String _localQuery = '';

  @override
  void initState() {
    super.initState();
    _localQuery = ref.read(searchQueryProvider);
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, TextEditingController controller) {
    setState(() {
      _localQuery = query;
    });
    ref.read(searchQueryProvider.notifier).state = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      ref.read(debouncedSearchQueryProvider.notifier).state = query;
    });
  }

  void _clearSearch(TextEditingController controller) {
    controller.clear();
    _onSearchChanged('', controller);
  }

  List<Task> _getAutocompleteOptions(String query, List<Task> allTasks) {
    if (query.trim().isEmpty) {
      return const [];
    }
    final lowerQuery = query.toLowerCase();
    return allTasks
        .where((t) =>
            t.title.toLowerCase().contains(lowerQuery) ||
            t.description.toLowerCase().contains(lowerQuery))
        .take(5) // Limit to 5 suggestions
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(activeFilterProvider);
    final allTasksAsync = ref.watch(taskListProvider);

    return Column(
      children: <Widget>[
        SizedBox(
          height: 52,
          child: RawAutocomplete<Task>(
            focusNode: _focusNode,
            textEditingController: _textEditingController,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (allTasksAsync.value == null) return const [];
              return _getAutocompleteOptions(
                  textEditingValue.text, allTasksAsync.value!);
            },
            displayStringForOption: (Task option) => option.title,
            fieldViewBuilder: (
              BuildContext context,
              TextEditingController fieldTextEditingController,
              FocusNode fieldFocusNode,
              VoidCallback onFieldSubmitted,
            ) {
              // Sync init state
              if (fieldTextEditingController.text != _localQuery && _localQuery.isNotEmpty && fieldTextEditingController.text.isEmpty) {
                fieldTextEditingController.text = _localQuery;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _focusNode.hasFocus
                      ? AppTheme.surfaceVariant.withValues(alpha: 0.8)
                      : AppTheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AppTheme.primary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
                    width: _focusNode.hasFocus ? 1.5 : 1,
                  ),
                  boxShadow: _focusNode.hasFocus
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: TextField(
                  controller: fieldTextEditingController,
                  focusNode: fieldFocusNode,
                  onChanged: (val) => _onSearchChanged(val, fieldTextEditingController),
                  onSubmitted: (_) => onFieldSubmitted(),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchPlaceholder,
                    hintStyle: AppTextStyles.bodyLarge.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _focusNode.hasFocus
                            ? AppTheme.primary
                            : AppTheme.textTertiary,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    suffixIcon: _localQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _clearSearch(fieldTextEditingController),
                            child: const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 14,
                    ),
                  ),
                ),
              );
            },
            optionsViewBuilder: (
              BuildContext context,
              AutocompleteOnSelected<Task> onSelected,
              Iterable<Task> options,
            ) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width - 32,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                                // Open edit screen when selecting from autocomplete
                                _openEditFromSearch(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: option.status.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: HighlightedText(
                                        text: option.title,
                                        highlight: _localQuery,
                                        baseStyle: AppTextStyles.bodyMedium.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_right_rounded,
                                      size: 16,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              _FilterChip(
                label: AppStrings.all,
                isSelected: activeFilter == null,
                color: AppTheme.primary,
                onTap: () =>
                    ref.read(activeFilterProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              ...TaskStatus.values.map(
                (status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: status.displayName,
                    isSelected: activeFilter == status,
                    color: status.color,
                    icon: status.icon,
                    onTap: () {
                      ref.read(activeFilterProvider.notifier).state =
                          activeFilter == status ? null : status;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditFromSearch(Task option) {
    if (option.storageKey == null) return;
    
    final draftNotifier = ref.read(taskDraftProvider.notifier);
    draftNotifier.initEdit(
      taskKey: option.storageKey!,
      title: option.title,
      description: option.description,
      dueDate: option.dueDate,
      status: option.status,
      blockedByKey: option.blockedByKey,
    );

    // Provide a cinematic slide transition for editing from search
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const TaskFormScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, animation, __, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );
        },
      )
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withValues(alpha: 0.15) 
              : AppTheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected 
                ? color.withValues(alpha: 0.5) 
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  )
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? color : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
