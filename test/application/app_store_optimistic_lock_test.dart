import 'package:danggui/src/application/app_state.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/services/notifications/local_time_zone.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;
  late AppStoreController controller;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
        appLocalTimeZoneResolverProvider.overrideWithValue(
          const _FixedTimeZoneResolver(),
        ),
      ],
    );
    await container.read(appStoreProvider.future);
    controller = container.read(appStoreProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('two task edits from one rowVersion accept only the first and roll back stale side effects', () async {
    final taskId = await controller.createTask(
      title: 'original task',
      body: 'original body',
    );
    final baseline = _task(container, taskId);

    await controller.updateTask(
      baseline.copyWith(title: 'first task', body: 'first body'),
    );
    final revisionCount = await _count(database, 'document_revisions');

    await expectLater(
      controller.updateTask(
        baseline.copyWith(
          title: 'stale task',
          body: 'stale body',
          reminderAt: DateTime.utc(2027, 1, 2, 3),
        ),
      ),
      throwsA(isA<StateConflictException>()),
    );

    await controller.refresh();
    final persisted = _task(container, taskId);
    expect(persisted.title, 'first task');
    expect(persisted.body, 'first body');
    expect(persisted.rowVersion, baseline.rowVersion + 1);
    expect(await _count(database, 'document_revisions'), revisionCount);
    expect(await _count(database, 'reminders'), 0);
    expect(await _count(database, 'platform_jobs'), 0);
    final search = await _searchRecord(database, SearchScope.task, taskId);
    expect(search.read<String>('title_norm'), 'first task');
    expect(search.read<String>('body_norm'), contains('first body'));
    expect(search.read<String>('body_norm'), isNot(contains('stale body')));
  });

  test('two note edits from one rowVersion accept only the first and roll back stale document and search writes', () async {
    final noteId = await controller.createNote(
      title: 'original note',
      body: 'original body',
    );
    final baseline = _note(container, noteId);

    await controller.updateNote(
      baseline.copyWith(title: 'first note', body: 'first body'),
    );
    final revisionCount = await _count(database, 'document_revisions');

    await expectLater(
      controller.updateNote(
        baseline.copyWith(title: 'stale note', body: 'stale body'),
      ),
      throwsA(isA<StateConflictException>()),
    );

    await controller.refresh();
    final persisted = _note(container, noteId);
    expect(persisted.title, 'first note');
    expect(persisted.body, 'first body');
    expect(persisted.rowVersion, baseline.rowVersion + 1);
    expect(await _count(database, 'document_revisions'), revisionCount);
    final search = await _searchRecord(database, SearchScope.note, noteId);
    expect(search.read<String>('title_norm'), 'first note');
    expect(search.read<String>('body_norm'), contains('first body'));
    expect(search.read<String>('body_norm'), isNot(contains('stale body')));
  });

  test('settings save rejects a stale AppSettingsModel rowVersion', () async {
    final baseline = container.read(appStoreProvider).requireValue.settings;

    await controller.saveSettings(
      _settingsWith(baseline, localeMode: LocaleMode.en),
    );
    await expectLater(
      controller.saveSettings(
        _settingsWith(baseline, localeMode: LocaleMode.ja),
      ),
      throwsA(isA<StateConflictException>()),
    );

    await controller.refresh();
    final persisted = container.read(appStoreProvider).requireValue.settings;
    expect(persisted.localeMode, LocaleMode.en);
    expect(persisted.rowVersion, baseline.rowVersion + 1);
  });
}

TaskViewModel _task(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .tasks
    .singleWhere((task) => task.id == id);

NoteViewModel _note(ProviderContainer container, String id) => container
    .read(appStoreProvider)
    .requireValue
    .notes
    .singleWhere((note) => note.id == id);

Future<int> _count(DangguiDatabase database, String table) async {
  final row = await database
      .customSelect('SELECT COUNT(*) AS count FROM $table')
      .getSingle();
  return row.read<int>('count');
}

Future<QueryRow> _searchRecord(
  DangguiDatabase database,
  SearchScope scope,
  String entityId,
) => database
    .customSelect(
      'SELECT title_norm, body_norm FROM search_records '
      'WHERE scope = ? AND entity_id = ?',
      variables: <Variable<Object>>[
        Variable.withString(scope.name),
        Variable.withString(entityId),
      ],
    )
    .getSingle();

AppSettingsModel _settingsWith(
  AppSettingsModel source, {
  required LocaleMode localeMode,
}) => AppSettingsModel(
  localeMode: localeMode,
  fontMode: source.fontMode,
  textScalePercent: source.textScalePercent,
  density: source.density,
  defaultSoundEnabled: source.defaultSoundEnabled,
  defaultVibrationEnabled: source.defaultVibrationEnabled,
  defaultSnoozeMinutes: source.defaultSnoozeMinutes,
  autoBackupEnabled: source.autoBackupEnabled,
  autoBackupHourLocal: source.autoBackupHourLocal,
  autoBackupMinuteLocal: source.autoBackupMinuteLocal,
  backupEncryptionEnabled: source.backupEncryptionEnabled,
  helpSeenVersion: source.helpSeenVersion,
  rowVersion: source.rowVersion,
);

final class _FixedTimeZoneResolver implements LocalTimeZoneResolver {
  const _FixedTimeZoneResolver();

  @override
  Future<String> currentIdentifier(DateTime localInstant) async => 'Etc/UTC';
}
