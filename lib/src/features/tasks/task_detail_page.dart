import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_state.dart';
import '../../application/app_store.dart';
import '../../core/theme/theme.dart';
import '../../services/notifications/notification_coordinator.dart';
import '../../ui/components/components.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    this.autosaveDelay = const Duration(milliseconds: 650),
    this.autosaveRetryDelay = const Duration(seconds: 2),
    this.onPersist,
  });

  final String taskId;
  final Duration autosaveDelay;
  final Duration autosaveRetryDelay;
  final Future<void> Function(TaskViewModel task)? onPersist;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _planController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyUndoController = UndoHistoryController();
  late final AppStoreController _store;
  late final NotificationCoordinator _notifications;
  DateTime? _dueDate;
  DateTime? _reminderAt;
  bool _sound = true;
  bool _vibration = true;
  bool _allowPop = false;
  String? _loadedId;
  TaskViewModel? _taskTemplate;
  DateTime? _persistedReminderAt;
  Timer? _autosaveTimer;
  _TaskSaveDraft? _pendingDraft;
  Future<bool>? _saveOperation;
  Object? _lastObservedSignature;
  var _nextRevision = 0;
  var _persistedRevision = 0;
  var _showSaveErrors = false;
  var _controllersReady = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(appStoreProvider.notifier);
    _notifications = ref.read(notificationCoordinatorProvider);
    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_onDraftChanged);
    _planController.addListener(_onDraftChanged);
    _bodyController.addListener(_onDraftChanged);
    _bodyUndoController.addListener(_refreshUndoButtons);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingDraft != null) {
      unawaited(_startSaveLoop());
    }
    _titleController.removeListener(_onDraftChanged);
    _planController.removeListener(_onDraftChanged);
    _bodyController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _planController.dispose();
    _bodyController.dispose();
    _bodyUndoController
      ..removeListener(_refreshUndoButtons)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _autosaveTimer?.cancel();
      unawaited(_startSaveLoop());
    }
  }

  void _refreshUndoButtons() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(appStoreProvider);
    final task = asyncState.value?.tasks.cast<TaskViewModel?>().firstWhere(
      (item) => item?.id == widget.taskId,
      orElse: () => null,
    );
    if (task != null) {
      if (_loadedId != task.id) {
        _hydrate(task);
      } else {
        _taskTemplate = task;
      }
    }
    if (asyncState.isLoading && task == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (task == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PaperBackground(
          child: SafeArea(
            child: Column(
              children: <Widget>[
                DangguiTopBar(
                  leading: DangguiIconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    semanticLabel: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: _saveAndClose,
                  ),
                  actions: <Widget>[
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleMenu(value, task),
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'copy', child: Text(l10n.copy)),
                        PopupMenuItem(
                          value: 'export',
                          child: Text(l10n.export),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ],
                      child: DangguiIconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        semanticLabel: MaterialLocalizations.of(context)
                            .showMenuTooltip,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 92),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextField(
                          controller: _titleController,
                          minLines: 1,
                          maxLines: 3,
                          style: Theme.of(context).textTheme.titleLarge,
                          decoration: InputDecoration(
                            hintText: l10n.taskTitleHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SmartField(
                          label: l10n.dueDate,
                          value: _dueDate == null
                              ? l10n.noDate
                              : DateFormat.yMMMd(
                                  Localizations.localeOf(context)
                                      .toLanguageTag(),
                                ).format(_dueDate!),
                          onTap: _pickDueDate,
                          onClear: _dueDate == null
                              ? null
                              : () {
                                  setState(() => _dueDate = null);
                                  _onDraftChanged();
                                },
                        ),
                        _SmartField(
                          label: l10n.reminder,
                          value: _reminderAt == null
                              ? l10n.noReminder
                              : DateFormat.yMMMd(
                                  Localizations.localeOf(context)
                                      .toLanguageTag(),
                                ).add_Hm().format(_reminderAt!),
                          onTap: _pickReminder,
                          onClear: _reminderAt == null
                              ? null
                              : () {
                                  setState(() => _reminderAt = null);
                                  _onDraftChanged();
                                },
                        ),
                        if (_reminderAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _ReminderOption(
                                    label: l10n.sound,
                                    value: _sound,
                                    onChanged: (value) {
                                      setState(() => _sound = value);
                                      _onDraftChanged();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _ReminderOption(
                                    label: l10n.vibration,
                                    value: _vibration,
                                    onChanged: (value) {
                                      setState(() => _vibration = value);
                                      _onDraftChanged();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.plan,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        TextField(
                          controller: _planController,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(hintText: l10n.planHint),
                        ),
                        const Divider(height: 28),
                        TextField(
                          controller: _bodyController,
                          undoController: _bodyUndoController,
                          minLines: 12,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(hintText: l10n.bodyHint),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: EditorToolbar(
            items: <EditorToolbarItem>[
              EditorToolbarItem(
                icon: const Icon(Icons.format_list_bulleted_rounded),
                semanticLabel: l10n.bulletedList,
                onPressed: () => _insertPrefix('• '),
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.format_list_numbered_rounded),
                semanticLabel: l10n.numberedList,
                onPressed: () => _insertPrefix('1. '),
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.check_box_outlined),
                semanticLabel: l10n.checklist,
                onPressed: _toggleChecklist,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.undo_rounded),
                semanticLabel: l10n.undo,
                onPressed: _bodyUndoController.value.canUndo
                    ? _bodyUndoController.undo
                    : null,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.redo_rounded),
                semanticLabel: l10n.redo,
                onPressed: _bodyUndoController.value.canRedo
                    ? _bodyUndoController.redo
                    : null,
              ),
              EditorToolbarItem(
                icon: const Icon(Icons.save_outlined),
                semanticLabel: l10n.save,
                onPressed: () => _flushSave(interactive: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
    );
    if (value != null) {
      setState(() => _dueDate = value);
      _onDraftChanged();
    }
  }

  Future<void> _pickReminder() async {
    final isFirstReminder = _reminderAt == null;
    var selectedDate = _reminderAt ?? _dueDate ?? DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(_reminderAt ?? DateTime.now());
    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return ReminderDialog(
            title: l10n.reminder,
            dateLabel: DateFormat.yMMMd(
              Localizations.localeOf(context).toLanguageTag(),
            ).format(selectedDate),
            dateSemanticLabel: l10n.dueDate,
            selectedTime: initialTime,
            cancelLabel: l10n.cancel,
            confirmLabel: l10n.confirm,
            hourSemanticLabel: l10n.reminderHour,
            minuteSemanticLabel: l10n.reminderMinute,
            onDatePressed: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                lastDate: DateTime.now().add(const Duration(days: 7300)),
              );
              if (value != null) setDialogState(() => selectedDate = value);
            },
            onCancel: () => Navigator.pop(dialogContext),
            onConfirm: (time) => Navigator.pop(
              dialogContext,
              DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                time.hour,
                time.minute,
              ),
            ),
          );
        },
      ),
    );
    if (result != null) {
      final settings = ref.read(appStoreProvider).value?.settings;
      setState(() {
        _reminderAt = result;
        if (isFirstReminder && settings != null) {
          _sound = settings.defaultSoundEnabled;
          _vibration = settings.defaultVibrationEnabled;
        }
      });
      _onDraftChanged();
      if (result.isBefore(DateTime.now()) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).reminderExpired)),
        );
      }
    }
  }

  void _hydrate(TaskViewModel task) {
    _autosaveTimer?.cancel();
    _controllersReady = false;
    _loadedId = task.id;
    _taskTemplate = task;
    _titleController.text = task.title;
    _planController.text = task.plan;
    _bodyController.text = task.body;
    _dueDate = task.dueDate;
    _reminderAt = task.reminderAt;
    _sound = task.soundEnabled;
    _vibration = task.vibrationEnabled;
    _persistedReminderAt = task.reminderAt;
    _pendingDraft = null;
    _nextRevision = 0;
    _persistedRevision = 0;
    _lastObservedSignature = _draftSignature();
    _controllersReady = true;
  }

  Object _draftSignature() => (
    _titleController.text,
    _planController.text,
    _bodyController.text,
    _dueDate?.microsecondsSinceEpoch,
    _reminderAt?.microsecondsSinceEpoch,
    _sound,
    _vibration,
  );

  void _onDraftChanged() {
    if (!_controllersReady || _taskTemplate == null) return;
    final signature = _draftSignature();
    if (signature == _lastObservedSignature) return;
    _lastObservedSignature = signature;
    final revision = ++_nextRevision;
    _pendingDraft = _TaskSaveDraft(
      revision: revision,
      task: _taskTemplate!.copyWith(
        title: _titleController.text,
        dueDate: _dueDate,
        reminderAt: _reminderAt,
        plan: _planController.text,
        body: _bodyController.text,
        soundEnabled: _sound,
        vibrationEnabled: _vibration,
      ),
    );
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(widget.autosaveDelay, () {
      unawaited(_startSaveLoop());
    });
  }

  Future<bool> _flushSave({required bool interactive}) {
    _autosaveTimer?.cancel();
    if (interactive) _showSaveErrors = true;
    return _startSaveLoop();
  }

  Future<bool> _startSaveLoop() {
    final currentOperation = _saveOperation;
    if (currentOperation != null) return currentOperation;
    final operation = _runSaveLoop();
    _saveOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_saveOperation, operation)) {
          _saveOperation = null;
          _showSaveErrors = false;
        }
      }),
    );
    return operation;
  }

  Future<bool> _runSaveLoop() async {
    while (true) {
      final draft = _pendingDraft;
      if (draft == null || draft.revision <= _persistedRevision) return true;
      if (draft.task.title.trim().isEmpty) {
        if (_showSaveErrors && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).taskTitleHint)),
          );
        }
        return false;
      }
      try {
        await _persistDraft(draft);
      } on Object catch (error) {
        if (_showSaveErrors && mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
        if (mounted) {
          _autosaveTimer?.cancel();
          _autosaveTimer = Timer(widget.autosaveRetryDelay, () {
            unawaited(_startSaveLoop());
          });
        }
        return false;
      }
      _persistedRevision = draft.revision;
      _persistedReminderAt = draft.task.reminderAt;
      if (identical(_pendingDraft, draft)) _pendingDraft = null;
    }
  }

  Future<void> _persistDraft(_TaskSaveDraft draft) async {
    final task = draft.task;
    final isFirstFutureReminder =
        _persistedReminderAt == null &&
        task.reminderAt != null &&
        task.reminderAt!.isAfter(DateTime.now());
    final notifications = isFirstFutureReminder ? _notifications : null;
    bool? permissionGranted;
    if (isFirstFutureReminder) {
      try {
        permissionGranted = await notifications!
            .ensurePermissionsForFutureReminder();
      } on Object {
        // A platform permission failure must never discard the editor data.
        permissionGranted = false;
      }
    }
    final persist = widget.onPersist;
    if (persist == null) {
      await _store.updateTask(task);
    } else {
      await persist(task);
    }
    if (isFirstFutureReminder && permissionGranted != null) {
      await notifications!.applyPermissionResultForTask(
        task.id,
        granted: permissionGranted,
      );
      await _store.refresh();
      if (!permissionGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).permissionDenied),
          ),
        );
      }
    }
  }

  Future<void> _saveAndClose() async {
    if (!await _flushSave(interactive: true)) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  void _insertPrefix(String prefix) {
    final selection = _bodyController.selection;
    final offset = selection.isValid
        ? selection.start
        : _bodyController.text.length;
    final text = _bodyController.text;
    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  void _toggleChecklist() {
    final selection = _bodyController.selection;
    final offset = selection.isValid
        ? selection.start
        : _bodyController.text.length;
    final text = _bodyController.text;
    final lineStart = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    final checked = text.startsWith('☒ ', lineStart);
    final unchecked = text.startsWith('☐ ', lineStart);
    if (checked || unchecked) {
      _bodyController.value = _bodyController.value.replaced(
        TextRange(start: lineStart, end: lineStart + 2),
        checked ? '☐ ' : '☒ ',
      );
      return;
    }
    _insertPrefix('☐ ');
  }

  Future<void> _handleMenu(String value, TaskViewModel task) async {
    final text =
        '${_titleController.text}\n\n${_planController.text}\n\n${_bodyController.text}';
    switch (value) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
      case 'export':
        await SharePlus.instance.share(
          ShareParams(subject: _titleController.text, text: text),
        );
      case 'delete':
        _autosaveTimer?.cancel();
        _pendingDraft = null;
        await ref.read(appStoreProvider.notifier).deleteTask(task.id);
        if (mounted) {
          setState(() => _allowPop = true);
          context.pop();
        }
    }
  }
}

final class _TaskSaveDraft {
  const _TaskSaveDraft({required this.revision, required this.task});

  final int revision;
  final TaskViewModel task;
}

class _ReminderOption extends StatelessWidget {
  const _ReminderOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        DangguiSwitch(
          value: value,
          semanticLabel: label,
          size: DangguiSwitchSize.compact,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SmartField extends StatelessWidget {
  const _SmartField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 54, maxWidth: 112),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(value)),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                )
              else
                Icon(Icons.chevron_right_rounded, color: tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}
