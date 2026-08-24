import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_store.dart';
import '../../core/app_version.dart';
import '../../core/theme/theme.dart';
import '../../domain/models.dart';
import '../../services/backup/automatic_backup_coordinator.dart';
import '../../services/backup/backup_service.dart';
import '../../services/export/portable_export_service.dart';
import '../../services/notifications/notification_coordinator.dart';
import '../../ui/components/components.dart';
import 'recently_deleted_page.dart';

typedef BackupPicker = Future<File?> Function();
typedef BackupInspector = Future<BackupInspection> Function(
  File source, {
  String? passphrase,
});
typedef BackupRestorer = Future<RestoreResult> Function(
  File source, {
  String? passphrase,
  RestoreMode mode,
});

const _coreBackupTables = <String>[
  'tasks',
  'notes',
  'folders',
  'document_blocks',
  'past_events',
  'reminders',
  'trash_entries',
];

final latestBackupRunProvider = FutureProvider.autoDispose<LatestBackupRun?>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final row = await database
      .customSelect(
        'SELECT kind, status, started_at_utc, completed_at_utc '
        "FROM backup_runs WHERE status IN ('succeeded', 'failed') "
        'ORDER BY COALESCE(completed_at_utc, started_at_utc) DESC LIMIT 1',
      )
      .getSingleOrNull();
  if (row == null) return null;
  return LatestBackupRun(
    kind: row.read<String>('kind'),
    status: row.read<String>('status'),
    startedAtUtc: DateTime.fromMicrosecondsSinceEpoch(
      row.read<int>('started_at_utc'),
      isUtc: true,
    ),
    completedAtUtc: row.readNullable<int>('completed_at_utc') == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(
            row.read<int>('completed_at_utc'),
            isUtc: true,
          ),
  );
});

final class LatestBackupRun {
  const LatestBackupRun({
    required this.kind,
    required this.status,
    required this.startedAtUtc,
    this.completedAtUtc,
  });

  final String kind;
  final String status;
  final DateTime startedAtUtc;
  final DateTime? completedAtUtc;
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    super.key,
    this.initialBackupTime,
    this.onBackupTimeChanged,
    this.onChooseBackupFolder,
    this.onCreateBackup,
    this.onRestoreBackup,
    this.onPickBackup,
    this.onInspectBackup,
    this.onRestoreBackupFile,
    this.onRefreshAfterRestore,
    this.onReconcileNotifications,
    this.onOpenRecentlyDeleted,
    this.loadLatestBackupStatus = true,
  });

  final TimeOfDay? initialBackupTime;
  final Future<void> Function(TimeOfDay value)? onBackupTimeChanged;
  final Future<void> Function()? onChooseBackupFolder;
  final Future<void> Function()? onCreateBackup;

  /// Legacy one-step seam retained for embedders. Normal app restore uses the
  /// inspect-and-choose flow exposed by the three callbacks below.
  final Future<void> Function()? onRestoreBackup;
  final BackupPicker? onPickBackup;
  final BackupInspector? onInspectBackup;
  final BackupRestorer? onRestoreBackupFile;

  /// Optional embedding/test seam. The app default refreshes the real store
  /// after restore, while an injected restorer can provide its own bounded
  /// refresh operation.
  final Future<void> Function()? onRefreshAfterRestore;
  final Future<void> Function()? onReconcileNotifications;
  final Future<void> Function()? onOpenRecentlyDeleted;

  /// Test seam for widget tests that do not exercise backup history. The app
  /// always uses the default and therefore reads the real SQLite audit table.
  final bool loadLatestBackupStatus;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TimeOfDay _backupTime;
  int? _pendingTextScale;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _backupTime =
        widget.initialBackupTime ?? const TimeOfDay(hour: 2, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = _SettingsCopy.of(context);
    final asyncState = ref.watch(appStoreProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const DangguiTopBar(),
              Expanded(
                child: asyncState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _SettingsError(
                    label: l10n.bootstrapError,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(appStoreProvider),
                  ),
                  data: (state) =>
                      _buildSettings(context, state.settings, l10n, copy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    AppSettingsModel settings,
    AppLocalizations l10n,
    _SettingsCopy copy,
  ) {
    if (widget.initialBackupTime == null &&
        !_saving &&
        (_backupTime.hour != settings.autoBackupHourLocal ||
            _backupTime.minute != settings.autoBackupMinuteLocal)) {
      _backupTime = TimeOfDay(
        hour: settings.autoBackupHourLocal,
        minute: settings.autoBackupMinuteLocal,
      );
    }
    final enabled = !_saving;
    final AsyncValue<LatestBackupRun?> latestBackup =
        widget.loadLatestBackupStatus
        ? ref.watch(latestBackupRunProvider)
        : const AsyncData<LatestBackupRun?>(null);
    final latestBackupLabel = latestBackup.when(
      data: (run) => run == null
          ? copy.noBackupRecord
          : _backupRunLabel(context, run, copy),
      loading: () => copy.backupStatusLoading,
      error: (error, stack) => copy.backupStatusUnavailable,
    );
    return ListView(
      key: const PageStorageKey<String>('settings-list'),
      padding: EdgeInsets.fromLTRB(
        context.dangguiTheme.pageHorizontalPadding,
        5,
        context.dangguiTheme.pageHorizontalPadding,
        32,
      ),
      children: <Widget>[
        _SettingsSection(
          title: l10n.appearance,
          children: <Widget>[
            SettingsTile(
              title: l10n.language,
              subtitle: copy.languageHint,
              trailing: _ValueChevron(
                value: _localeLabel(l10n, settings.localeMode),
              ),
              onTap: enabled ? () => _chooseLocale(settings, l10n) : null,
            ),
            SettingsTile(
              title: l10n.fontStyle,
              subtitle: copy.fontHint,
              trailing: _ValueChevron(
                value: settings.fontMode == FontMode.sans
                    ? l10n.sans
                    : l10n.serif,
              ),
              onTap: enabled ? () => _chooseFont(settings, l10n) : null,
            ),
            _TextScaleTile(
              title: l10n.textSize,
              subtitle: copy.textSizeHint,
              value: _pendingTextScale ?? settings.textScalePercent,
              enabled: enabled,
              onChanged: (value) => setState(() => _pendingTextScale = value),
              onChangeEnd: (value) async {
                await _save(settings.copyWith(textScalePercent: value));
                if (mounted) setState(() => _pendingTextScale = null);
              },
            ),
            SettingsTile(
              title: l10n.density,
              subtitle: copy.densityHint,
              showDivider: false,
              trailing: _ValueChevron(
                value: settings.density == DisplayDensity.loose
                    ? l10n.loose
                    : l10n.compact,
              ),
              onTap: enabled ? () => _chooseDensity(settings, l10n) : null,
            ),
          ],
        ),
        _SettingsSection(
          title: l10n.reminderSettings,
          children: <Widget>[
            SettingsTile(
              title: copy.notificationPermission,
              subtitle: copy.notificationPermissionHint,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: enabled ? _requestNotificationPermission : null,
            ),
            SettingsTile(
              title: l10n.sound,
              subtitle: copy.soundHint,
              trailing: DangguiSwitch(
                value: settings.defaultSoundEnabled,
                semanticLabel: l10n.sound,
                size: DangguiSwitchSize.compact,
                onChanged: enabled
                    ? (value) =>
                          _save(settings.copyWith(defaultSoundEnabled: value))
                    : null,
              ),
            ),
            SettingsTile(
              title: l10n.vibration,
              subtitle: Theme.of(context).platform == TargetPlatform.iOS
                  ? l10n.reminderVibrationSystemControlled
                  : copy.vibrationHint,
              trailing: Theme.of(context).platform == TargetPlatform.iOS
                  ? const Icon(Icons.phone_iphone_rounded)
                  : DangguiSwitch(
                      value: settings.defaultVibrationEnabled,
                      semanticLabel: l10n.vibration,
                      size: DangguiSwitchSize.compact,
                      onChanged: enabled
                          ? (value) => _save(
                              settings.copyWith(defaultVibrationEnabled: value),
                            )
                          : null,
                    ),
            ),
            SettingsTile(
              title: l10n.snooze,
              subtitle: copy.snoozeHint,
              showDivider: false,
              trailing: _ValueChevron(
                value: _snoozeLabel(l10n, settings.defaultSnoozeMinutes),
              ),
              onTap: enabled ? () => _chooseSnooze(settings, l10n) : null,
            ),
          ],
        ),
        _SettingsSection(
          title: l10n.dataAndBackup,
          children: <Widget>[
            SettingsTile(
              title: l10n.autoBackup,
              subtitle: copy.autoBackupHint,
              trailing: DangguiSwitch(
                value: settings.autoBackupEnabled,
                semanticLabel: l10n.autoBackup,
                size: DangguiSwitchSize.compact,
                onChanged: enabled
                    ? (value) =>
                          _save(settings.copyWith(autoBackupEnabled: value))
                    : null,
              ),
            ),
            SettingsTile(
              title: copy.backupTime,
              subtitle: copy.backupTimeHint,
              trailing: _ValueChevron(
                value: MaterialLocalizations.of(context)
                    .formatTimeOfDay(_backupTime, alwaysUse24HourFormat: true),
              ),
              onTap: enabled && settings.autoBackupEnabled
                  ? () => _chooseBackupTime(settings)
                  : null,
            ),
            Semantics(
              label: '${copy.lastBackupStatus}: $latestBackupLabel',
              readOnly: true,
              child: SettingsTile(
                title: copy.lastBackupStatus,
                subtitle: latestBackupLabel,
                trailing: Icon(
                  latestBackup.when(
                    data: (run) => switch (run?.status) {
                      'succeeded' => Icons.check_circle_outline_rounded,
                      'failed' => Icons.error_outline_rounded,
                      _ => Icons.history_rounded,
                    },
                    loading: () => Icons.more_horiz_rounded,
                    error: (error, stack) => Icons.help_outline_rounded,
                  ),
                  color: latestBackup.value?.status == 'failed'
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
            SettingsTile(
              title: copy.backupStorage,
              subtitle: copy.backupFolderHint,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: enabled ? _chooseBackupFolder : null,
            ),
            SettingsTile(
              title: l10n.backupEncryption,
              subtitle: copy.encryptionHint,
              trailing: DangguiSwitch(
                value: settings.backupEncryptionEnabled,
                semanticLabel: l10n.backupEncryption,
                size: DangguiSwitchSize.compact,
                onChanged: enabled
                    ? (value) => _changeEncryption(settings, value)
                    : null,
              ),
            ),
            SettingsTile(
              title: copy.createBackup,
              subtitle: copy.createBackupHint,
              trailing: const Icon(Icons.save_alt_rounded),
              onTap: enabled ? () => _createBackup(settings) : null,
            ),
            SettingsTile(
              title: l10n.exportAllData,
              subtitle: copy.exportAllDataHint,
              trailing: const Icon(Icons.archive_outlined),
              onTap: enabled ? _exportAllData : null,
            ),
            SettingsTile(
              title: l10n.restoreBackup,
              subtitle: l10n.restoreWarning,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: enabled ? _restoreBackup : null,
            ),
            SettingsTile(
              title: l10n.recentlyDeleted,
              subtitle: l10n.retentionHint,
              danger: true,
              showDivider: false,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: enabled ? _openRecentlyDeleted : null,
            ),
          ],
        ),
        _SettingsSection(
          title: copy.supportAndPrivacy,
          children: <Widget>[
            SettingsTile(
              title: l10n.privacy,
              subtitle: l10n.localOnlySummary,
              trailing: const Icon(Icons.lock_outline_rounded),
            ),
            SettingsTile(
              title: l10n.helpTitle,
              subtitle: copy.helpHint,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/settings/help'),
            ),
            SettingsTile(
              title: copy.openSourceLicenses,
              subtitle: copy.openSourceLicensesHint,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appName,
                applicationVersion: appVersionName,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/brand/danggui-app-icon.png',
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
            ),
            SettingsTile(
              title: l10n.about,
              subtitle: l10n.versionLabel(appVersionName),
              trailing: const Icon(Icons.eco_outlined),
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _chooseLocale(
    AppSettingsModel settings,
    AppLocalizations l10n,
  ) async {
    await _showChoice<LocaleMode>(
      context,
      title: l10n.language,
      selected: settings.localeMode,
      choices: <_Choice<LocaleMode>>[
        _Choice(LocaleMode.system, l10n.followSystem),
        _Choice(LocaleMode.zhHans, l10n.simplifiedChinese),
        _Choice(LocaleMode.en, l10n.english),
        _Choice(LocaleMode.ja, l10n.japanese),
        _Choice(LocaleMode.ru, l10n.russian),
      ],
      onSelected: (value) async {
        if (value != settings.localeMode) {
          await _save(settings.copyWith(localeMode: value));
        }
      },
    );
  }

  String _backupRunLabel(
    BuildContext context,
    LatestBackupRun run,
    _SettingsCopy copy,
  ) {
    final instant = (run.completedAtUtc ?? run.startedAtUtc).toLocal();
    final material = MaterialLocalizations.of(context);
    final dateTime =
        '${material.formatFullDate(instant)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(instant), alwaysUse24HourFormat: true)}';
    final status = run.status == 'succeeded'
        ? copy.backupSucceeded
        : copy.backupFailed;
    final kind = run.kind == 'daily'
        ? copy.dailyBackupKind
        : copy.manualBackupKind;
    return '$status · $kind · $dateTime';
  }

  Future<void> _chooseFont(
    AppSettingsModel settings,
    AppLocalizations l10n,
  ) async {
    await _showChoice<FontMode>(
      context,
      title: l10n.fontStyle,
      selected: settings.fontMode,
      choices: <_Choice<FontMode>>[
        _Choice(FontMode.sans, l10n.sans),
        _Choice(FontMode.serif, l10n.serif),
      ],
      onSelected: (value) async {
        if (value != settings.fontMode) {
          await _save(settings.copyWith(fontMode: value));
        }
      },
    );
  }

  Future<void> _chooseDensity(
    AppSettingsModel settings,
    AppLocalizations l10n,
  ) async {
    await _showChoice<DisplayDensity>(
      context,
      title: l10n.density,
      selected: settings.density,
      choices: <_Choice<DisplayDensity>>[
        _Choice(DisplayDensity.loose, l10n.loose),
        _Choice(DisplayDensity.compact, l10n.compact),
      ],
      onSelected: (value) async {
        if (value != settings.density) {
          await _save(settings.copyWith(density: value));
        }
      },
    );
  }

  Future<void> _chooseSnooze(
    AppSettingsModel settings,
    AppLocalizations l10n,
  ) async {
    await _showChoice<int>(
      context,
      title: l10n.snooze,
      selected: settings.defaultSnoozeMinutes,
      choices: <_Choice<int>>[
        _Choice(10, l10n.minutes10),
        _Choice(30, l10n.minutes30),
        _Choice(60, l10n.minutes60),
      ],
      onSelected: (value) async {
        if (value != settings.defaultSnoozeMinutes) {
          await _save(settings.copyWith(defaultSnoozeMinutes: value));
        }
      },
    );
  }

  Future<void> _chooseBackupTime(AppSettingsModel settings) async {
    final value = await showTimePicker(
      context: context,
      initialTime: _backupTime,
    );
    if (value == null || !mounted) return;
    setState(() => _backupTime = value);
    await _save(
      settings.copyWith(
        autoBackupHourLocal: value.hour,
        autoBackupMinuteLocal: value.minute,
      ),
    );
    if (!mounted) return;
    try {
      await widget.onBackupTimeChanged?.call(value);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _chooseBackupFolder() async {
    final operation = widget.onChooseBackupFolder;
    if (operation != null) {
      await _runExternal(operation);
      return;
    }
    final copy = _SettingsCopy.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).backupFolder),
        content: Text(copy.backupDestinationInfo),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup(AppSettingsModel settings) async {
    final operation = widget.onCreateBackup;
    if (operation != null) {
      await _runExternal(
        operation,
        successMessage: AppLocalizations.of(context).backupCreated,
      );
      return;
    }

    String? passphrase;
    if (settings.backupEncryptionEnabled) {
      try {
        final store = ref.read(automaticBackupPassphraseStoreProvider);
        passphrase = await store.read();
        if (passphrase == null) {
          passphrase = await _askForPassphrase(confirm: true);
          if (passphrase == null || !mounted) return;
          await store.write(passphrase);
        }
      } catch (error) {
        if (mounted) _showMessage(error.toString());
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final backup = await ref
          .read(backupServiceProvider)
          .create(passphrase: passphrase);
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(backup.file.path)],
          subject: _SettingsCopy.of(context).backupShareSubject,
          sharePositionOrigin: origin,
        ),
      );
      if (mounted) {
        _showMessage(AppLocalizations.of(context).backupCreated);
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      ref.invalidate(latestBackupRunProvider);
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportAllData() async {
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(portableExportServiceProvider)
          .export(PortableExportRequest.full());
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(result.file.path)],
          subject: AppLocalizations.of(context).exportAllData,
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeEncryption(
    AppSettingsModel settings,
    bool enabled,
  ) async {
    String? passphrase;
    if (enabled) {
      final copy = _SettingsCopy.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).backupEncryption),
          content: Text(copy.encryptionWarning),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppLocalizations.of(context).confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      passphrase = await _askForPassphrase(confirm: true);
      if (passphrase == null || !mounted) return;
    }

    setState(() => _saving = true);
    final store = ref.read(automaticBackupPassphraseStoreProvider);
    try {
      if (enabled) {
        await store.write(passphrase!);
      }
      await ref
          .read(appStoreProvider.notifier)
          .saveSettings(settings.copyWith(backupEncryptionEnabled: enabled));
      if (!enabled) await store.clear();
    } catch (error) {
      if (enabled) {
        try {
          await store.clear();
        } on Object {
          // Keep the original storage/settings error visible to the user.
        }
      }
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestNotificationPermission() async {
    var granted = false;
    var exactSchedulingAvailable = true;
    NotificationCoordinator? notifications;
    try {
      final coordinator = ref.read(notificationCoordinatorProvider);
      notifications = coordinator;
      granted = await coordinator.requestPermissions();
    } on Object {
      granted = false;
    }
    if (granted && notifications != null) {
      try {
        exactSchedulingAvailable = await notifications
            .requestExactAlarmPermission();
      } on Object {
        // Ordinary notification access remains granted even if the platform
        // cannot open or query Android's separate exact-alarm settings page.
        exactSchedulingAvailable = false;
      }
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final copy = _SettingsCopy.of(context);
    _showMessage(
      !granted
          ? l10n.permissionDenied
          : exactSchedulingAvailable
          ? copy.permissionGranted
          : l10n.reminderStatusPrecisionLimited,
    );
  }

  Future<void> _restoreBackup() async {
    final legacyOperation = widget.onRestoreBackup;
    if (legacyOperation != null &&
        widget.onPickBackup == null &&
        widget.onInspectBackup == null &&
        widget.onRestoreBackupFile == null) {
      await _runExternal(legacyOperation);
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(backupServiceProvider);
      final source = await (widget.onPickBackup ?? service.pickBackup).call();
      if (source == null || !mounted) return;

      String? passphrase;
      late BackupInspection inspection;
      while (mounted) {
        try {
          inspection = await (widget.onInspectBackup ?? service.inspect).call(
            source,
            passphrase: passphrase,
          );
          break;
        } on FormatException catch (error) {
          final message = error.message.toString();
          final needsPassphrase =
              message.contains('requires a passphrase') ||
              message.contains('Passphrase is wrong');
          if (!needsPassphrase) rethrow;
          if (!mounted) return;
          final passphraseError = message.contains('wrong')
              ? _SettingsCopy.of(context).restorePasswordOrDamageError
              : null;
          passphrase = await _askForPassphrase(
            confirm: false,
            initialError: passphraseError,
          );
          if (passphrase == null || !mounted) return;
        }
      }
      if (!mounted) return;

      final mode = await _chooseRestoreMode(inspection);
      if (mode == null || !mounted) return;
      if (mode == RestoreMode.replace) {
        final confirmed = await _confirmReplaceRestore();
        if (!confirmed || !mounted) return;
      }

      await (widget.onRestoreBackupFile ?? service.restore).call(
        source,
        passphrase: passphrase,
        mode: mode,
      );
      if (!mounted) return;

      // BackupService invalidates the database-backed providers after a real
      // restore. Reading the notifier obtains that rebuilt instance; refresh
      // is also useful for injectable test/embedding restorers that do not
      // invalidate providers themselves.
      await (widget.onRefreshAfterRestore ??
              ref.read(appStoreProvider.notifier).refresh)
          .call();
      await (widget.onReconcileNotifications ??
              ref.read(notificationCoordinatorProvider).reconcile)
          .call();
      if (mounted) _showMessage(_SettingsCopy.of(context).restoreCompleted);
    } catch (error) {
      if (mounted) {
        final failure = _classifyRestoreFailure(error);
        if (kDebugMode) {
          debugPrint(
            'Backup restore failed [${failure.name}]: ${error.runtimeType}',
          );
        }
        _showMessage(_SettingsCopy.of(context).restoreError(failure));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<RestoreMode?> _chooseRestoreMode(BackupInspection inspection) {
    final copy = _SettingsCopy.of(context);
    final createdAt = DateTime.tryParse(
      inspection.manifest['createdAtUtc']?.toString() ?? '',
    )?.toLocal();
    final material = MaterialLocalizations.of(context);
    final createdLabel = createdAt == null
        ? copy.unknownValue
        : '${material.formatFullDate(createdAt)} '
              '${material.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt), alwaysUse24HourFormat: true)}';
    final appVersion =
        inspection.manifest['appVersion']?.toString() ?? copy.unknownValue;
    final schemaVersion =
        inspection.manifest['databaseSchemaVersion']?.toString() ??
        copy.unknownValue;
    final hash = inspection.archiveSha256;
    final hashSummary = hash.length <= 24
        ? hash
        : '${hash.substring(0, 16)}…${hash.substring(hash.length - 8)}';

    return showDialog<RestoreMode>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(copy.inspectBackupTitle),
        content: SingleChildScrollView(
          child: Semantics(
            label: copy.inspectBackupSemantics,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _InspectionRow(label: copy.createdAtLabel, value: createdLabel),
                _InspectionRow(label: copy.appVersionLabel, value: appVersion),
                _InspectionRow(
                  label: copy.schemaVersionLabel,
                  value: schemaVersion,
                ),
                _InspectionRow(
                  label: copy.encryptionStateLabel,
                  value: inspection.encrypted
                      ? copy.encryptedLabel
                      : copy.notEncryptedLabel,
                ),
                _InspectionRow(
                  label: copy.archiveHashLabel,
                  value: hashSummary,
                  semanticValue: hash,
                ),
                const SizedBox(height: 12),
                Text(
                  copy.recordCountsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final key in _coreBackupTables)
                  _InspectionRow(
                    label: copy.recordCountLabel(key),
                    value: '${inspection.recordCounts[key] ?? 0}',
                  ),
                const SizedBox(height: 14),
                Text(copy.chooseRestoreModeHint),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          OutlinedButton(
            key: const ValueKey<String>('restore-mode-merge'),
            onPressed: () => Navigator.pop(context, RestoreMode.merge),
            child: Text(copy.mergeRestoreAction),
          ),
          FilledButton(
            key: const ValueKey<String>('restore-mode-replace'),
            onPressed: () => Navigator.pop(context, RestoreMode.replace),
            child: Text(copy.replaceRestoreAction),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmReplaceRestore() async {
    final l10n = AppLocalizations.of(context);
    final copy = _SettingsCopy.of(context);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            title: Text(copy.replaceWarningTitle),
            content: Text(copy.replaceWarningBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const ValueKey<String>('confirm-replace-restore'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(copy.confirmReplaceAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _askForPassphrase({
    required bool confirm,
    String? initialError,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PassphraseDialog(
        copy: _SettingsCopy.of(context),
        confirmPassphrase: confirm,
        initialError: initialError,
      ),
    );
  }

  Future<void> _openRecentlyDeleted() async {
    final operation = widget.onOpenRecentlyDeleted;
    if (operation != null) {
      await _runExternal(operation);
      return;
    }
    if (mounted) await context.push<void>(RecentlyDeletedPage.routePath);
  }

  Future<void> _runExternal(
    Future<void> Function()? operation, {
    String? successMessage,
  }) async {
    if (operation == null) {
      _showMessage(AppLocalizations.of(context).featureComingSoon);
      return;
    }
    setState(() => _saving = true);
    try {
      await operation();
      if (mounted && successMessage != null) _showMessage(successMessage);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save(AppSettingsModel settings) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(appStoreProvider.notifier).saveSettings(settings);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _localeLabel(AppLocalizations l10n, LocaleMode mode) =>
      switch (mode) {
        LocaleMode.system => l10n.followSystem,
        LocaleMode.zhHans => l10n.simplifiedChinese,
        LocaleMode.en => l10n.english,
        LocaleMode.ja => l10n.japanese,
        LocaleMode.ru => l10n.russian,
      };

  static String _snoozeLabel(AppLocalizations l10n, int value) =>
      switch (value) {
        30 => l10n.minutes30,
        60 => l10n.minutes60,
        _ => l10n.minutes10,
      };
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({
    required this.copy,
    required this.confirmPassphrase,
    this.initialError,
  });

  final _SettingsCopy copy;
  final bool confirmPassphrase;
  final String? initialError;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();
  late String? _error = widget.initialError;
  var _obscureText = true;

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.copy.passphraseTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.copy.passphraseHint),
            const SizedBox(height: 16),
            TextField(
              controller: _passphrase,
              autofocus: true,
              obscureText: _obscureText,
              textInputAction: widget.confirmPassphrase
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: widget.confirmPassphrase ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.copy.passphraseLabel,
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: _obscureText
                      ? widget.copy.showPassphrase
                      : widget.copy.hidePassphrase,
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (widget.confirmPassphrase) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: _confirmation,
                obscureText: _obscureText,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: widget.copy.confirmPassphraseLabel,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.confirm)),
      ],
    );
  }

  void _submit() {
    final value = _passphrase.text;
    String? error;
    if (value.length < 8) {
      error = widget.copy.passphraseTooShort;
    } else if (widget.confirmPassphrase && value != _confirmation.text) {
      error = widget.copy.passphraseMismatch;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, value);
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 11),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          SettingsGroup(children: children),
        ],
      ),
    );
  }
}

class _ValueChevron extends StatelessWidget {
  const _ValueChevron({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 104),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 3),
        const Icon(Icons.chevron_right_rounded),
      ],
    );
  }
}

class _TextScaleTile extends StatelessWidget {
  const _TextScaleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final String subtitle;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.lineDark.withAlpha(122)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text('$value%', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: 90,
              max: 120,
              divisions: 6,
              label: '$value%',
              onChanged: enabled ? (next) => onChanged(next.round()) : null,
              onChangeEnd: enabled ? (next) => onChangeEnd(next.round()) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionRow extends StatelessWidget {
  const _InspectionRow({
    required this.label,
    required this.value,
    this.semanticValue,
  });

  final String label;
  final String value;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        label: label,
        value: semanticValue ?? value,
        readOnly: true,
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: Text(value, textAlign: TextAlign.end)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({
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

final class _Choice<T> {
  const _Choice(this.value, this.label);

  final T value;
  final String label;
}

Future<void> _showChoice<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<_Choice<T>> choices,
  required Future<void> Function(T value) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.dangguiTheme.lineDark,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final choice in choices)
            Semantics(
              selected: choice.value == selected,
              button: true,
              child: InkWell(
                key: ValueKey<T>(choice.value),
                onTap: () async {
                  Navigator.pop(context);
                  await onSelected(choice.value);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          choice.value == selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: choice.value == selected
                              ? context.dangguiTheme.sage
                              : context.dangguiTheme.muted,
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(choice.label)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

extension _SettingsModelCopy on AppSettingsModel {
  AppSettingsModel copyWith({
    LocaleMode? localeMode,
    FontMode? fontMode,
    int? textScalePercent,
    DisplayDensity? density,
    bool? defaultSoundEnabled,
    bool? defaultVibrationEnabled,
    int? defaultSnoozeMinutes,
    bool? autoBackupEnabled,
    int? autoBackupHourLocal,
    int? autoBackupMinuteLocal,
    bool? backupEncryptionEnabled,
    int? helpSeenVersion,
    int? rowVersion,
  }) {
    return AppSettingsModel(
      localeMode: localeMode ?? this.localeMode,
      fontMode: fontMode ?? this.fontMode,
      textScalePercent: textScalePercent ?? this.textScalePercent,
      density: density ?? this.density,
      defaultSoundEnabled: defaultSoundEnabled ?? this.defaultSoundEnabled,
      defaultVibrationEnabled:
          defaultVibrationEnabled ?? this.defaultVibrationEnabled,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupHourLocal: autoBackupHourLocal ?? this.autoBackupHourLocal,
      autoBackupMinuteLocal:
          autoBackupMinuteLocal ?? this.autoBackupMinuteLocal,
      backupEncryptionEnabled:
          backupEncryptionEnabled ?? this.backupEncryptionEnabled,
      helpSeenVersion: helpSeenVersion ?? this.helpSeenVersion,
      rowVersion: rowVersion ?? this.rowVersion,
    );
  }
}

enum _RestoreFailure { password, damaged, incompatible, fileAccess, unexpected }

_RestoreFailure _classifyRestoreFailure(Object error) {
  if (error is FileSystemException) return _RestoreFailure.fileAccess;
  if (error is! FormatException) return _RestoreFailure.unexpected;

  final message = error.message.toString().toLowerCase();
  if (message.contains('passphrase') || message.contains('password')) {
    return _RestoreFailure.password;
  }
  if (message.contains('different app') ||
      message.contains('unsupported') ||
      message.contains('version') ||
      message.contains('profile') ||
      message.contains('manifest') ||
      message.contains('schema does not match')) {
    return _RestoreFailure.incompatible;
  }
  return _RestoreFailure.damaged;
}

final class _SettingsCopy {
  const _SettingsCopy({
    required this.languageHint,
    required this.fontHint,
    required this.textSizeHint,
    required this.densityHint,
    required this.notificationPermission,
    required this.notificationPermissionHint,
    required this.permissionGranted,
    required this.soundHint,
    required this.vibrationHint,
    required this.snoozeHint,
    required this.autoBackupHint,
    required this.backupTime,
    required this.backupTimeHint,
    required this.lastBackupStatus,
    required this.noBackupRecord,
    required this.backupStatusLoading,
    required this.backupStatusUnavailable,
    required this.backupSucceeded,
    required this.backupFailed,
    required this.dailyBackupKind,
    required this.manualBackupKind,
    required this.backupStorage,
    required this.backupFolderHint,
    required this.backupDestinationInfo,
    required this.backupShareSubject,
    required this.encryptionHint,
    required this.encryptionWarning,
    required this.createBackup,
    required this.createBackupHint,
    required this.exportAllDataHint,
    required this.passphraseTitle,
    required this.passphraseHint,
    required this.passphraseLabel,
    required this.confirmPassphraseLabel,
    required this.showPassphrase,
    required this.hidePassphrase,
    required this.passphraseTooShort,
    required this.passphraseMismatch,
    required this.passphraseIncorrect,
    required this.restorePasswordOrDamageError,
    required this.restoreDamagedError,
    required this.restoreIncompatibleError,
    required this.restoreFileAccessError,
    required this.restoreUnexpectedError,
    required this.restoreCompleted,
    required this.inspectBackupTitle,
    required this.inspectBackupSemantics,
    required this.unknownValue,
    required this.createdAtLabel,
    required this.appVersionLabel,
    required this.schemaVersionLabel,
    required this.encryptionStateLabel,
    required this.encryptedLabel,
    required this.notEncryptedLabel,
    required this.archiveHashLabel,
    required this.recordCountsTitle,
    required this.recordCountLabels,
    required this.chooseRestoreModeHint,
    required this.mergeRestoreAction,
    required this.replaceRestoreAction,
    required this.replaceWarningTitle,
    required this.replaceWarningBody,
    required this.confirmReplaceAction,
    required this.supportAndPrivacy,
    required this.helpHint,
    required this.openSourceLicenses,
    required this.openSourceLicensesHint,
  });

  final String languageHint;
  final String fontHint;
  final String textSizeHint;
  final String densityHint;
  final String notificationPermission;
  final String notificationPermissionHint;
  final String permissionGranted;
  final String soundHint;
  final String vibrationHint;
  final String snoozeHint;
  final String autoBackupHint;
  final String backupTime;
  final String backupTimeHint;
  final String lastBackupStatus;
  final String noBackupRecord;
  final String backupStatusLoading;
  final String backupStatusUnavailable;
  final String backupSucceeded;
  final String backupFailed;
  final String dailyBackupKind;
  final String manualBackupKind;
  final String backupStorage;
  final String backupFolderHint;
  final String backupDestinationInfo;
  final String backupShareSubject;
  final String encryptionHint;
  final String encryptionWarning;
  final String createBackup;
  final String createBackupHint;
  final String exportAllDataHint;
  final String passphraseTitle;
  final String passphraseHint;
  final String passphraseLabel;
  final String confirmPassphraseLabel;
  final String showPassphrase;
  final String hidePassphrase;
  final String passphraseTooShort;
  final String passphraseMismatch;
  final String passphraseIncorrect;
  final String restorePasswordOrDamageError;
  final String restoreDamagedError;
  final String restoreIncompatibleError;
  final String restoreFileAccessError;
  final String restoreUnexpectedError;
  final String restoreCompleted;
  final String inspectBackupTitle;
  final String inspectBackupSemantics;
  final String unknownValue;
  final String createdAtLabel;
  final String appVersionLabel;
  final String schemaVersionLabel;
  final String encryptionStateLabel;
  final String encryptedLabel;
  final String notEncryptedLabel;
  final String archiveHashLabel;
  final String recordCountsTitle;
  final Map<String, String> recordCountLabels;
  final String chooseRestoreModeHint;
  final String mergeRestoreAction;
  final String replaceRestoreAction;
  final String replaceWarningTitle;
  final String replaceWarningBody;
  final String confirmReplaceAction;
  final String supportAndPrivacy;
  final String helpHint;
  final String openSourceLicenses;
  final String openSourceLicensesHint;

  String recordCountLabel(String table) => recordCountLabels[table] ?? table;

  String restoreError(_RestoreFailure failure) => switch (failure) {
    _RestoreFailure.password => restorePasswordOrDamageError,
    _RestoreFailure.damaged => restoreDamagedError,
    _RestoreFailure.incompatible => restoreIncompatibleError,
    _RestoreFailure.fileAccess => restoreFileAccessError,
    _RestoreFailure.unexpected => restoreUnexpectedError,
  };

  static _SettingsCopy of(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => _en,
      'ja' => _ja,
      'ru' => _ru,
      _ => _zh,
    };
  }

  static const _zh = _SettingsCopy(
    languageHint: '立即切换界面语言，不翻译个人内容',
    fontHint: '设置标题与正文的显示风格',
    textSizeHint: '同时调整事项、过往、笔记与帮助',
    densityHint: '调整事项卡片的留白',
    notificationPermission: '通知权限',
    notificationPermissionHint: '用于本地通知与精确提醒；精确权限可拒绝',
    permissionGranted: '通知权限已开启',
    soundHint: '新提醒默认播放声音',
    vibrationHint: '可与声音独立设置',
    snoozeHint: '通知操作的默认稍后提醒时长',
    autoBackupHint: '每天最佳努力执行一次，系统可能延迟',
    backupTime: '每日备份时间',
    backupTimeHint: '应用下次运行时会补做错过的备份',
    lastBackupStatus: '最近一次备份',
    noBackupRecord: '尚无备份记录',
    backupStatusLoading: '正在读取备份记录…',
    backupStatusUnavailable: '暂时无法读取备份记录',
    backupSucceeded: '成功',
    backupFailed: '失败',
    dailyBackupKind: '每日自动',
    manualBackupKind: '手动',
    backupStorage: '备份存放位置',
    backupFolderHint: '每日备份保存在应用内；手动备份可另存到文件',
    backupDestinationInfo: '每日备份保存在应用的本地支持目录，保留最近 30 份；卸载或清除应用数据可能同时删除它们。点击“立即创建备份”后会打开系统分享面板，可选择“存储到文件”或其他本地位置。应用不会上传备份。',
    backupShareSubject: '当归本地备份',
    encryptionHint: '默认关闭；忘记密码后无法恢复',
    encryptionWarning: '加密密码不会上传或找回。启用前请确认你能安全保存密码。',
    createBackup: '立即创建备份',
    createBackupHint: '创建并校验完整 .dgbak 文件',
    exportAllDataHint: '导出可阅读的 Markdown、JSON 与校验 Manifest ZIP',
    passphraseTitle: '备份密码',
    passphraseHint: '至少 8 个字符。密码仅安全保存在本设备，用于每日自动备份；不会上传，也无法找回。',
    passphraseLabel: '输入密码',
    confirmPassphraseLabel: '再次输入密码',
    showPassphrase: '显示密码',
    hidePassphrase: '隐藏密码',
    passphraseTooShort: '密码至少需要 8 个字符',
    passphraseMismatch: '两次输入的密码不一致',
    passphraseIncorrect: '密码不正确，请重试',
    restorePasswordOrDamageError: '密码不正确，或加密备份已损坏。请检查密码和文件。',
    restoreDamagedError: '备份文件已损坏或内容不完整，无法恢复。',
    restoreIncompatibleError: '该备份不属于当归，或由不兼容的版本创建。',
    restoreFileAccessError: '无法读取或写入备份文件。请检查文件是否仍可用及存储空间。',
    restoreUnexpectedError: '备份恢复失败。当前数据未被标记为恢复成功，请稍后重试。',
    restoreCompleted: '备份已恢复',
    inspectBackupTitle: '检查备份',
    inspectBackupSemantics: '已验证的备份信息',
    unknownValue: '未知',
    createdAtLabel: '创建时间',
    appVersionLabel: '应用版本',
    schemaVersionLabel: '数据库版本',
    encryptionStateLabel: '加密状态',
    encryptedLabel: '已加密',
    notEncryptedLabel: '未加密',
    archiveHashLabel: 'SHA-256 摘要',
    recordCountsTitle: '核心记录数',
    recordCountLabels: <String, String>{
      'tasks': '事项',
      'notes': '笔记',
      'folders': '文件夹',
      'document_blocks': '内容块',
      'past_events': '过往来源',
      'reminders': '提醒',
      'trash_entries': '最近删除',
    },
    chooseRestoreModeHint: '合并恢复会保留现有内容并导入备份；覆盖恢复会将当前数据集整体替换。',
    mergeRestoreAction: '合并恢复',
    replaceRestoreAction: '覆盖恢复',
    replaceWarningTitle: '确定覆盖当前数据？',
    replaceWarningBody: '这会用备份中的完整数据集替换当前所有本地内容。恢复前会自动创建安全副本，但请确保你已了解此操作的影响。',
    confirmReplaceAction: '覆盖并恢复',
    supportAndPrivacy: '帮助与隐私',
    helpHint: '离线查看每项操作、权限和故障排查',
    openSourceLicenses: '开源软件许可',
    openSourceLicensesHint: '查看 Flutter 与第三方依赖的许可文本',
  );

  static const _en = _SettingsCopy(
    languageHint:
        'Changes the interface now; personal content is not translated',
    fontHint: 'Choose the display style for headings and body text',
    textSizeHint: 'Applies to Tasks, Past, Notes, and Help',
    densityHint: 'Adjust spacing inside task cards',
    notificationPermission: 'Notification permission',
    notificationPermissionHint: 'For local notifications and exact timing',
    permissionGranted: 'Notifications are enabled',
    soundHint: 'Play sound for new reminders by default',
    vibrationHint: 'Can be configured independently from sound',
    snoozeHint: 'Default delay for the notification action',
    autoBackupHint: 'Best effort once a day; the system may delay it',
    backupTime: 'Daily backup time',
    backupTimeHint: 'A missed backup is caught up next time the app runs',
    lastBackupStatus: 'Latest backup',
    noBackupRecord: 'No backup has been recorded yet',
    backupStatusLoading: 'Reading backup history…',
    backupStatusUnavailable: 'Backup history is temporarily unavailable',
    backupSucceeded: 'Succeeded',
    backupFailed: 'Failed',
    dailyBackupKind: 'Daily automatic',
    manualBackupKind: 'Manual',
    backupStorage: 'Backup storage',
    backupFolderHint:
        'Daily copies stay in-app; manual copies can be saved to Files',
    backupDestinationInfo: 'Daily copies stay in the app support directory and the latest 30 are retained; uninstalling or clearing app data may remove them. Create a manual backup to open the system share sheet and choose Save to Files or another local destination. The app never uploads backups.',
    backupShareSubject: 'Danggui local backup',
    encryptionHint: 'Off by default; a forgotten password cannot be recovered',
    encryptionWarning: 'The encryption password is never uploaded or recoverable. Store it safely before enabling encryption.',
    createBackup: 'Create backup now',
    createBackupHint: 'Create and verify a complete .dgbak file',
    exportAllDataHint: 'Export a readable Markdown + JSON ZIP with checksums',
    passphraseTitle: 'Backup password',
    passphraseHint: 'Use at least 8 characters. It is stored securely on this device for daily backups, never uploaded, and cannot be recovered.',
    passphraseLabel: 'Enter password',
    confirmPassphraseLabel: 'Enter password again',
    showPassphrase: 'Show password',
    hidePassphrase: 'Hide password',
    passphraseTooShort: 'Use at least 8 characters',
    passphraseMismatch: 'The passwords do not match',
    passphraseIncorrect: 'Incorrect password. Try again.',
    restorePasswordOrDamageError: 'The password is incorrect, or the encrypted backup is damaged. Check both and try again.',
    restoreDamagedError:
        'This backup is damaged or incomplete and cannot be restored.',
    restoreIncompatibleError: 'This backup belongs to another app or was created by an incompatible version.',
    restoreFileAccessError: 'The backup could not be read or written. Check that the file is available and storage has enough space.',
    restoreUnexpectedError: 'Restore failed. Your data was not marked as restored; please try again.',
    restoreCompleted: 'Backup restored',
    inspectBackupTitle: 'Inspect backup',
    inspectBackupSemantics: 'Verified backup information',
    unknownValue: 'Unknown',
    createdAtLabel: 'Created',
    appVersionLabel: 'App version',
    schemaVersionLabel: 'Database schema',
    encryptionStateLabel: 'Encryption',
    encryptedLabel: 'Encrypted',
    notEncryptedLabel: 'Not encrypted',
    archiveHashLabel: 'SHA-256 summary',
    recordCountsTitle: 'Core record counts',
    recordCountLabels: <String, String>{
      'tasks': 'Tasks',
      'notes': 'Notes',
      'folders': 'Folders',
      'document_blocks': 'Content blocks',
      'past_events': 'Past provenance',
      'reminders': 'Reminders',
      'trash_entries': 'Recently deleted',
    },
    chooseRestoreModeHint: 'Merge keeps current content and imports this backup. Replace swaps the entire current dataset for the backup.',
    mergeRestoreAction: 'Merge restore',
    replaceRestoreAction: 'Replace restore',
    replaceWarningTitle: 'Replace all current data?',
    replaceWarningBody: 'This replaces every local item with the complete dataset from the backup. A safety copy is created first, but continue only if you understand the impact.',
    confirmReplaceAction: 'Replace and restore',
    supportAndPrivacy: 'Help & privacy',
    helpHint: 'Offline instructions, permissions, and troubleshooting',
    openSourceLicenses: 'Open-source licenses',
    openSourceLicensesHint: 'Licenses for Flutter and third-party packages',
  );

  static const _ja = _SettingsCopy(
    languageHint: '表示言語をすぐ変更します。個人の内容は翻訳しません',
    fontHint: '見出しと本文の表示スタイルを選択',
    textSizeHint: '事項・過往・ノート・ヘルプに適用',
    densityHint: '事項カードの余白を調整',
    notificationPermission: '通知の権限',
    notificationPermissionHint: 'ローカル通知と正確な時刻指定に使用',
    permissionGranted: '通知が有効です',
    soundHint: '新しい通知で音を鳴らす',
    vibrationHint: '音とは別に設定できます',
    snoozeHint: '通知操作の既定の延期時間',
    autoBackupHint: '1日1回を目安に実行。OSにより遅れる場合があります',
    backupTime: '毎日のバックアップ時刻',
    backupTimeHint: '実行できなかった分は次回起動時に補います',
    lastBackupStatus: '最新のバックアップ',
    noBackupRecord: 'バックアップ履歴はまだありません',
    backupStatusLoading: 'バックアップ履歴を読み込み中…',
    backupStatusUnavailable: 'バックアップ履歴を読み込めません',
    backupSucceeded: '成功',
    backupFailed: '失敗',
    dailyBackupKind: '毎日自動',
    manualBackupKind: '手動',
    backupStorage: 'バックアップの保存先',
    backupFolderHint: '毎日のコピーはアプリ内、手動コピーはファイルに保存',
    backupDestinationInfo: '毎日のコピーはアプリのサポート領域に保存し、最新 30 件を保持します。アプリの削除やデータ消去で失われる場合があります。手動バックアップでシステム共有画面を開き、「ファイルに保存」などを選べます。アプリからアップロードはしません。',
    backupShareSubject: '当帰のローカルバックアップ',
    encryptionHint: '既定はオフ。パスワードを忘れると復元できません',
    encryptionWarning: '暗号化パスワードは送信も再発行もできません。安全に保管してから有効にしてください。',
    createBackup: '今すぐバックアップ',
    createBackupHint: '完全な .dgbak ファイルを作成して検証',
    exportAllDataHint: 'Markdown・JSON・検証情報を ZIP で書き出します',
    passphraseTitle: 'バックアップのパスワード',
    passphraseHint: '8文字以上。毎日の自動バックアップ用にこの端末に安全に保存します。送信も再発行もできません。',
    passphraseLabel: 'パスワードを入力',
    confirmPassphraseLabel: 'もう一度入力',
    showPassphrase: 'パスワードを表示',
    hidePassphrase: 'パスワードを隠す',
    passphraseTooShort: '8文字以上で入力してください',
    passphraseMismatch: 'パスワードが一致しません',
    passphraseIncorrect: 'パスワードが違います。再入力してください。',
    restorePasswordOrDamageError: 'パスワードが違うか、暗号化バックアップが破損しています。両方を確認してください。',
    restoreDamagedError: 'バックアップが破損または不完全なため、復元できません。',
    restoreIncompatibleError: 'このバックアップは別のアプリ用か、互換性のないバージョンで作成されています。',
    restoreFileAccessError: 'バックアップを読み書きできません。ファイルと空き容量を確認してください。',
    restoreUnexpectedError: '復元に失敗しました。復元成功とは処理されていません。再試行してください。',
    restoreCompleted: 'バックアップを復元しました',
    inspectBackupTitle: 'バックアップを検査',
    inspectBackupSemantics: '検証済みのバックアップ情報',
    unknownValue: '不明',
    createdAtLabel: '作成日時',
    appVersionLabel: 'アプリのバージョン',
    schemaVersionLabel: 'データベース版',
    encryptionStateLabel: '暗号化',
    encryptedLabel: '暗号化済み',
    notEncryptedLabel: '暗号化なし',
    archiveHashLabel: 'SHA-256 要約',
    recordCountsTitle: '主要レコード数',
    recordCountLabels: <String, String>{
      'tasks': '事項',
      'notes': 'ノート',
      'folders': 'フォルダ',
      'document_blocks': 'コンテンツブロック',
      'past_events': '過往の出典',
      'reminders': '通知',
      'trash_entries': '最近削除した項目',
    },
    chooseRestoreModeHint: '「統合」は現在の内容を残して読み込みます。「置換」は現在のデータ全体をバックアップで置き換えます。',
    mergeRestoreAction: '統合して復元',
    replaceRestoreAction: '置換して復元',
    replaceWarningTitle: '現在のデータをすべて置換しますか？',
    replaceWarningBody:
        '現在の端末内データ全体をバックアップの内容で置き換えます。事前に安全用コピーを作成しますが、影響を理解した上で続行してください。',
    confirmReplaceAction: '置換して復元',
    supportAndPrivacy: 'ヘルプとプライバシー',
    helpHint: '操作、権限、問題解決をオフラインで確認',
    openSourceLicenses: 'オープンソースライセンス',
    openSourceLicensesHint: 'Flutter と外部パッケージのライセンス',
  );

  static const _ru = _SettingsCopy(
    languageHint:
        'Язык интерфейса меняется сразу; личные записи не переводятся',
    fontHint: 'Стиль заголовков и основного текста',
    textSizeHint: 'Для дел, прошлого, заметок и справки',
    densityHint: 'Интервалы внутри карточек дел',
    notificationPermission: 'Разрешение на уведомления',
    notificationPermissionHint: 'Для локальных уведомлений и точного времени',
    permissionGranted: 'Уведомления разрешены',
    soundHint: 'Звук для новых напоминаний по умолчанию',
    vibrationHint: 'Настраивается независимо от звука',
    snoozeHint: 'Задержка действия «Напомнить позже»',
    autoBackupHint: 'Примерно раз в день; система может отложить запуск',
    backupTime: 'Время ежедневной копии',
    backupTimeHint: 'Пропущенная копия создаётся при следующем запуске',
    lastBackupStatus: 'Последняя копия',
    noBackupRecord: 'Копии ещё не создавались',
    backupStatusLoading: 'Чтение истории копий…',
    backupStatusUnavailable: 'История копий временно недоступна',
    backupSucceeded: 'Успешно',
    backupFailed: 'Ошибка',
    dailyBackupKind: 'Ежедневная авто',
    manualBackupKind: 'Вручную',
    backupStorage: 'Хранение копий',
    backupFolderHint:
        'Ежедневные копии внутри приложения; ручные можно сохранить в файлы',
    backupDestinationInfo: 'Ежедневные копии хранятся в локальной области приложения; остаются последние 30. Удаление или очистка данных приложения может удалить их. Ручная копия откроет системное меню, где можно выбрать сохранение в файлы. Приложение не загружает копии в сеть.',
    backupShareSubject: 'Локальная копия Danggui',
    encryptionHint: 'По умолчанию выключено; забытый пароль не восстановить',
    encryptionWarning: 'Пароль шифрования не отправляется и не восстанавливается. Надёжно сохраните его перед включением.',
    createBackup: 'Создать копию сейчас',
    createBackupHint: 'Создать и проверить полный файл .dgbak',
    exportAllDataHint:
        'Экспорт Markdown + JSON ZIP с manifest и контрольными суммами',
    passphraseTitle: 'Пароль резервной копии',
    passphraseHint: 'Не менее 8 символов. Пароль безопасно хранится на этом устройстве для ежедневных копий, не загружается и не восстанавливается.',
    passphraseLabel: 'Введите пароль',
    confirmPassphraseLabel: 'Введите пароль ещё раз',
    showPassphrase: 'Показать пароль',
    hidePassphrase: 'Скрыть пароль',
    passphraseTooShort: 'Нужно не менее 8 символов',
    passphraseMismatch: 'Пароли не совпадают',
    passphraseIncorrect: 'Неверный пароль. Повторите ввод.',
    restorePasswordOrDamageError: 'Пароль неверен или зашифрованная копия повреждена. Проверьте пароль и файл.',
    restoreDamagedError: 'Резервная копия повреждена или неполна, поэтому её нельзя восстановить.',
    restoreIncompatibleError:
        'Копия создана другим приложением или несовместимой версией.',
    restoreFileAccessError: 'Не удалось прочитать или записать копию. Проверьте файл и свободное место.',
    restoreUnexpectedError: 'Восстановление не выполнено. Данные не отмечены как восстановленные; повторите позже.',
    restoreCompleted: 'Резервная копия восстановлена',
    inspectBackupTitle: 'Проверка копии',
    inspectBackupSemantics: 'Проверенные сведения о резервной копии',
    unknownValue: 'Неизвестно',
    createdAtLabel: 'Создана',
    appVersionLabel: 'Версия приложения',
    schemaVersionLabel: 'Схема базы',
    encryptionStateLabel: 'Шифрование',
    encryptedLabel: 'Зашифрована',
    notEncryptedLabel: 'Без шифрования',
    archiveHashLabel: 'Сводка SHA-256',
    recordCountsTitle: 'Количество основных записей',
    recordCountLabels: <String, String>{
      'tasks': 'Дела',
      'notes': 'Заметки',
      'folders': 'Папки',
      'document_blocks': 'Блоки содержимого',
      'past_events': 'Источники прошлого',
      'reminders': 'Напоминания',
      'trash_entries': 'Недавно удалённые',
    },
    chooseRestoreModeHint: 'Слияние сохранит текущие данные и импортирует копию. Замена полностью подменит текущий набор данных.',
    mergeRestoreAction: 'Слить и восстановить',
    replaceRestoreAction: 'Заменить и восстановить',
    replaceWarningTitle: 'Заменить все текущие данные?',
    replaceWarningBody: 'Все локальные записи будут заменены полным набором из копии. Сначала будет создана страховочная копия, но продолжайте, только если понимаете последствия.',
    confirmReplaceAction: 'Заменить и восстановить',
    supportAndPrivacy: 'Помощь и конфиденциальность',
    helpHint: 'Инструкции, разрешения и решение проблем без сети',
    openSourceLicenses: 'Лицензии открытого ПО',
    openSourceLicensesHint: 'Лицензии Flutter и сторонних пакетов',
  );
}
