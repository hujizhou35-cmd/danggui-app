import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../core/theme/theme.dart';
import '../../domain/models.dart';
import '../../ui/components/components.dart';
import 'task_creation_sheet.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  final _searchController = TextEditingController();
  var _searchVisible = false;
  var _sortByDate = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(appStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              DangguiTopBar(
                content: _searchVisible
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l10n.searchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                        onChanged: (value) {
                          setState(() {});
                          ref
                              .read(appStoreProvider.notifier)
                              .setSearchQuery(value);
                        },
                      )
                    : null,
                actions: <Widget>[
                  DangguiIconButton(
                    icon: Icon(
                      _searchVisible
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                    ),
                    semanticLabel: l10n.search,
                    selected: _searchVisible,
                    onPressed: () {
                      setState(() {
                        _searchVisible = !_searchVisible;
                        if (!_searchVisible) {
                          _searchController.clear();
                          ref
                              .read(appStoreProvider.notifier)
                              .setSearchQuery('');
                        }
                      });
                    },
                  ),
                  PopupMenuButton<bool>(
                    tooltip: l10n.sort,
                    onSelected: (value) => setState(() => _sortByDate = value),
                    itemBuilder: (context) => <PopupMenuEntry<bool>>[
                      PopupMenuItem<bool>(
                        value: false,
                        child: Text(l10n.manualSort),
                      ),
                      PopupMenuItem<bool>(
                        value: true,
                        child: Text(l10n.dateSort),
                      ),
                    ],
                    child: DangguiIconButton(
                      icon: const Icon(Icons.swap_vert_rounded),
                      semanticLabel: l10n.sort,
                      selected: _sortByDate,
                    ),
                  ),
                  DangguiIconButton(
                    icon: const Icon(Icons.add_rounded),
                    semanticLabel: l10n.addTask,
                    onPressed: () => _showQuickAdd(context),
                  ),
                ],
              ),
              Expanded(
                child: asyncState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _ErrorState(
                    label: l10n.bootstrapError,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(appStoreProvider),
                  ),
                  data: (state) {
                    final tasks = _filteredTasks(context, state.tasks);
                    if (tasks.isEmpty) {
                      return _EmptyTasks(
                        title: l10n.noTasks,
                        hint: l10n.noTasksHint,
                        buttonLabel: l10n.addTask,
                        onPressed: () => _showQuickAdd(context),
                      );
                    }
                    if (!_sortByDate && _searchController.text.trim().isEmpty) {
                      return RefreshIndicator(
                        onRefresh: ref.read(appStoreProvider.notifier).refresh,
                        child: ReorderableListView.builder(
                          key: const PageStorageKey<String>(
                            'tasks-reorderable-list',
                          ),
                          padding: EdgeInsets.fromLTRB(
                            context.dangguiTheme.pageHorizontalPadding,
                            5,
                            context.dangguiTheme.pageHorizontalPadding,
                            22,
                          ),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) => Padding(
                            key: ValueKey<String>('reorder-${tasks[index].id}'),
                            padding: EdgeInsets.only(
                              bottom: context.dangguiTheme.cardGap,
                            ),
                            child: _buildTaskCard(context, tasks[index], index),
                          ),
                          onReorderItem: (oldIndex, newIndex) async {
                            final reordered = tasks.toList(growable: true);
                            final moved = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, moved);
                            await ref
                                .read(appStoreProvider.notifier)
                                .reorderTasks(
                                  reordered
                                      .map((task) => task.id)
                                      .toList(growable: false),
                                );
                          },
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: ref.read(appStoreProvider.notifier).refresh,
                      child: ListView.separated(
                        key: const PageStorageKey<String>('tasks-list'),
                        padding: EdgeInsets.fromLTRB(
                          context.dangguiTheme.pageHorizontalPadding,
                          5,
                          context.dangguiTheme.pageHorizontalPadding,
                          22,
                        ),
                        itemCount: tasks.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: context.dangguiTheme.cardGap),
                        itemBuilder: (context, index) {
                          return _buildTaskCard(context, tasks[index], index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskViewModel task, int index) {
    final l10n = AppLocalizations.of(context);
    return TaskCard(
      key: ValueKey<String>(task.id),
      title: task.title,
      alternate: index.isOdd,
      status: task.status == TaskStatus.completionPending
          ? TaskCardStatus.completionPending
          : TaskCardStatus.active,
      schedule: _schedule(context, task),
      switchSemanticLabel:
          '${task.title} ${task.status == TaskStatus.active ? l10n.on : l10n.off}',
      addToPastLabel: l10n.addToPast,
      deleteLabel: l10n.delete,
      onTap: () => context.push('/tasks/${task.id}'),
      onStatusChanged: (active) =>
          ref.read(appStoreProvider.notifier).setTaskActive(task.id, active),
      onAddToPast: () =>
          ref.read(appStoreProvider.notifier).addTaskToPast(task.id),
      onDelete: () => _deleteTask(task),
    );
  }

  List<TaskViewModel> _filteredTasks(
    BuildContext context,
    List<TaskViewModel> source,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final shortDate = DateFormat.yMd(localeTag);
    final cardDate = DateFormat.MMMd(localeTag);
    final result = source
        .where((task) {
          if (query.isEmpty) return true;
          final dueDate = task.dueDate;
          final dateMatches =
              dueDate != null &&
              <String>{
                _isoDate(dueDate)!,
                shortDate.format(dueDate),
                cardDate.format(dueDate),
              }.any((value) => value.toLowerCase().contains(query));
          return task.title.toLowerCase().contains(query) ||
              task.plan.toLowerCase().contains(query) ||
              task.body.toLowerCase().contains(query) ||
              dateMatches;
        })
        .toList(growable: false);
    if (_sortByDate) {
      return result.toList()..sort((a, b) {
        final aDate = a.dueDate;
        final bDate = b.dueDate;
        if (aDate == null && bDate == null) {
          return a.manualRank.compareTo(b.manualRank);
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final compared = aDate.compareTo(bDate);
        return compared == 0 ? a.manualRank.compareTo(b.manualRank) : compared;
      });
    }
    return result;
  }

  TaskCardSchedule _schedule(BuildContext context, TaskViewModel task) {
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    final dateFormat = DateFormat.MMMd(tag);
    final taskDate = task.dueDate == null
        ? null
        : dateFormat.format(task.dueDate!);
    final reminder = task.reminderAt;
    final reminderDate = reminder == null ? null : dateFormat.format(reminder);
    final reminderTime = reminder == null
        ? null
        : DateFormat.Hm(tag).format(reminder);
    final sameDay =
        task.dueDate != null &&
        reminder != null &&
        DateUtils.isSameDay(task.dueDate, reminder);
    final language = locale.languageCode;
    return TaskCardSchedule(
      taskDateLabel: taskDate,
      reminderDateLabel: reminderDate,
      reminderTimeLabel: reminderTime,
      reminderIsOnTaskDate: sameDay,
      reminderSuffix: AppLocalizations.of(context).reminder,
      openingParenthesis: language == 'zh' || language == 'ja' ? '（' : ' (',
      closingParenthesis: language == 'zh' || language == 'ja' ? '）' : ')',
    );
  }

  Future<void> _showQuickAdd(BuildContext context) async {
    final result = await showTaskCreationSheet(context);
    if (result == null || !context.mounted) return;
    try {
      final id = await ref
          .read(appStoreProvider.notifier)
          .createTask(
            title: result.title,
            body: result.body,
            dueDate: result.dueDate,
          );
      if (result.openDetails && context.mounted) {
        await settleTaskCreationKeyboard(context: context);
        if (!context.mounted) return;
        await context.push('/tasks/$id');
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).taskTitleHint)),
        );
      }
    }
  }

  Future<void> _deleteTask(TaskViewModel task) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(appStoreProvider.notifier).deleteTask(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deletedTask),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () =>
              ref.read(appStoreProvider.notifier).restoreTask(task.id),
        ),
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({
    required this.title,
    required this.hint,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String hint;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.eco_outlined, size: 54, color: tokens.sage),
            const SizedBox(height: 15),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

String? _isoDate(DateTime? value) {
  if (value == null) return null;
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
