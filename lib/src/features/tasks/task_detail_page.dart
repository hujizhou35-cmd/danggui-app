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
import '../../domain/models.dart';
import '../../services/notifications/notification_coordinator.dart';
import '../../services/notifications/notification_settings_launcher.dart';
import '../../ui/components/components.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({
    super.key,
    required this.taskId,
    this.autosaveDelay = const Duration(milliseconds: 650),
    this.autosaveRetryDelay = const Duration(seconds: 2),
    this.onPersist,
    this.now,
  });

  final String taskId;
  final Duration autosaveDelay;
  final Duration autosaveRetryDelay;
  final Future<void> Function(TaskViewModel task)? onPersist;
  final DateTime Function()? now;

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
  bool _closing = false;
  String? _loadedId;
  TaskViewModel? _taskTemplate;
  DateTime? _persistedReminderAt;
  Timer? _autosaveTimer;
  _TaskSaveDraft? _pendingDraft;
  Future<bool>? _saveOperation;
  Object? _lastObservedSignature;
  bool _reminderFieldsDirty = false;
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
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshReminderPermissionState());
      return;
    }
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
        _mergeExternalTask(task);
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
        resizeToAvoidBottomInset: false,
        body: EditorPageFrame(
          topBar: DangguiTopBar(
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
                  PopupMenuItem(value: 'export', child: Text(l10n.export)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
                child: DangguiIconButton(
                  icon: const Icon(Icons.more_horiz_rounded),
                  semanticLabel: MaterialLocalizations.of(context)
                      .showMenuTooltip,
                ),
              ),
            ],
          ),
          editor: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  key: const Key('task-title-field'),
                  controller: _titleController,
                  minLines: 1,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(hintText: l10n.taskTitleHint),
                ),
                const SizedBox(height: 16),
                _SmartField(
                  key: const Key('task-due-date-field'),
                  label: l10n.dueDate,
                  value: _dueDate == null
                      ? l10n.noDate
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
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
                  key: const Key('task-reminder-field'),
                  label: l10n.reminder,
                  value: _reminderAt == null
                      ? l10n.noReminder
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).add_Hm().format(_reminderAt!),
                  onTap: _pickReminder,
                  onClear: _reminderAt == null
                      ? null
                      : () {
                          _reminderFieldsDirty = true;
                          setState(() => _reminderAt = null);
                          _onDraftChanged();
                        },
                ),
                if (_reminderAt != null)
                  _ReminderStatusRow(
                    key: const Key('task-reminder-status'),
                    label: _reminderStatusLabel(task, l10n),
                    showSettingsAction: _isPermissionRestricted(task),
                    settingsLabel: l10n.openNotificationSettings,
                    onOpenSettings: _openNotificationSettings,
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
                              _reminderFieldsDirty = true;
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
                              _reminderFieldsDirty = true;
                              setState(() => _vibration = value);
                              _onDraftChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(l10n.plan, style: Theme.of(context).textTheme.labelMedium),
                TextField(
                  key: const Key('task-plan-field'),
                  controller: _planController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: l10n.planHint),
                ),
                const Divider(height: 28),
                TextField(
                  key: const Key('task-body-field'),
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
          toolbar: EditorToolbar(
            key: const Key('task-editor-toolbar'),
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
    final now = _now();
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
    final now = _now();
    final suggested = nextReminderTime(now);
    final existing = _reminderAt;
    var selectedDate = existing ?? _dueDate ?? suggested;
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).isBefore(today)) {
      selectedDate = suggested;
    }
    final initialTime = TimeOfDay.fromDateTime(
      existing != null && existing.isAfter(now) ? existing : suggested,
    );
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
              final pickerNow = _now();
              final firstDate = DateTime(
                pickerNow.year,
                pickerNow.month,
                pickerNow.day,
              );
              final value = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: firstDate,
                lastDate: firstDate.add(const Duration(days: 7300)),
              );
              if (value != null) setDialogState(() => selectedDate = value);
            },
            onCancel: () => Navigator.pop(dialogContext),
            onConfirm: (time) {
              final value = DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                time.hour,
                time.minute,
              );
              if (!value.isAfter(_now())) {
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(l10n.reminderExpired)));
                return;
              }
              Navigator.pop(dialogContext, value);
            },
          );
        },
      ),
    );
    if (result != null) {
      final settings = ref.read(appStoreProvider).value?.settings;
      _reminderFieldsDirty = true;
      setState(() {
        _reminderAt = result;
        if (isFirstReminder && settings != null) {
          _sound = settings.defaultSoundEnabled;
          _vibration = settings.defaultVibrationEnabled;
        }
      });
      _onDraftChanged();
    }
  }

  Future<void> _refreshReminderPermissionState() async {
    try {
      await _notifications.reconcile();
      await _store.refresh();
    } on Object {
      // Returning from system settings must never interrupt draft editing.
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await ref.read(notificationSettingsLauncherProvider).open();
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).permissionDenied)),
      );
    }
  }

  bool _isPermissionRestricted(TaskViewModel task) =>
      task.reminderStatus == ReminderStatus.permissionDenied ||
      task.reminderPauseReason == ReminderPauseReason.permissionDenied;

  String _reminderStatusLabel(TaskViewModel task, AppLocalizations l10n) {
    if (task.status == TaskStatus.completionPending ||
        task.reminderPauseReason == ReminderPauseReason.taskClosed) {
      return l10n.reminderStatusTaskClosed;
    }
    if (task.reminderStatus == ReminderStatus.expired ||
        (_reminderAt != null && !_reminderAt!.isAfter(_now()))) {
      return l10n.reminderExpired;
    }
    if (_isPermissionRestricted(task)) {
      return l10n.reminderStatusPermissionDenied;
    }
    if (task.reminderStatus == ReminderStatus.paused) {
      return l10n.reminderStatusPaused;
    }
    return l10n.reminderScheduled;
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
    _reminderFieldsDirty = false;
    _pendingDraft = null;
    _nextRevision = 0;
    _persistedRevision = 0;
    _lastObservedSignature = _draftSignature();
    _controllersReady = true;
  }

  void _mergeExternalTask(TaskViewModel task) {
    _taskTemplate = task;
    if (_reminderFieldsDirty) return;

    _reminderAt = task.reminderAt;
    _sound = task.soundEnabled;
    _vibration = task.vibrationEnabled;
    _persistedReminderAt = task.reminderAt;
    final pending = _pendingDraft;
    if (pending != null) {
      _pendingDraft = _TaskSaveDraft(
        revision: pending.revision,
        reminderFieldsDirty: false,
        task: pending.task.copyWith(
          reminderAt: task.reminderAt,
          soundEnabled: task.soundEnabled,
          vibrationEnabled: task.vibrationEnabled,
        ),
      );
    }
    _lastObservedSignature = _draftSignature();
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
      reminderFieldsDirty: _reminderFieldsDirty,
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
      if (identical(_pendingDraft, draft)) {
        if (draft.reminderFieldsDirty) _reminderFieldsDirty = false;
        _pendingDraft = null;
      }
    }
  }

  Future<void> _persistDraft(_TaskSaveDraft draft) async {
    final task = draft.task;
    final now = _now();
    final activatesFutureReminder =
        task.reminderAt != null &&
        task.reminderAt!.isAfter(now) &&
        (_persistedReminderAt == null || !_persistedReminderAt!.isAfter(now));
    final notifications = activatesFutureReminder ? _notifications : null;
    bool? permissionGranted;
    if (activatesFutureReminder) {
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
      await _store.updateTask(task, updateReminder: draft.reminderFieldsDirty);
    } else {
      await persist(task);
    }
    if (activatesFutureReminder && permissionGranted != null) {
      try {
        await notifications!.applyPermissionResultForTask(
          task.id,
          granted: permissionGranted,
        );
      } on Object {
        // The task transaction above already committed. A platform/plugin
        // error leaves a durable notification job for startup/foreground
        // recovery and must not keep the editor in an unsaved retry loop.
      }
      try {
        // applyPermissionResult commits before its platform reconciliation.
        // Refresh independently so a later plugin error cannot leave the UI
        // showing stale permission state.
        await _store.refresh();
      } on Object {
        // The ordinary AppStore/lifecycle recovery path will retry this read.
      }
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
    if (_closing) return;
    _closing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!await _flushSave(interactive: true)) {
      _closing = false;
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

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
  const _TaskSaveDraft({
    required this.revision,
    required this.task,
    required this.reminderFieldsDirty,
  });

  final int revision;
  final TaskViewModel task;
  final bool reminderFieldsDirty;
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

class _ReminderStatusRow extends StatelessWidget {
  const _ReminderStatusRow({
    super.key,
    required this.label,
    required this.showSettingsAction,
    required this.settingsLabel,
    required this.onOpenSettings,
  });

  final String label;
  final bool showSettingsAction;
  final String settingsLabel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final textStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: tokens.muted);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stackSettingsAction =
              showSettingsAction &&
              (constraints.maxWidth < 360 || textScale > 1.4);
          final status = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: tokens.muted,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(label, style: textStyle)),
            ],
          );
          final settingsAction = TextButton(
            key: const Key('task-reminder-open-settings'),
            onPressed: onOpenSettings,
            child: Text(settingsLabel),
          );

          if (stackSettingsAction) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                status,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: settingsAction,
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: status),
              if (showSettingsAction) settingsAction,
            ],
          );
        },
      ),
    );
  }
}

class _SmartField extends StatelessWidget {
  const _SmartField({
    super.key,
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

/// The next five-minute boundary, guaranteed to be later than [now].
DateTime nextReminderTime(DateTime now) {
  final flooredMinute = now.minute - now.minute % 5;
  final boundary = now.isUtc
      ? DateTime.utc(now.year, now.month, now.day, now.hour, flooredMinute)
      : DateTime(now.year, now.month, now.day, now.hour, flooredMinute);
  return boundary.add(const Duration(minutes: 5));
}
