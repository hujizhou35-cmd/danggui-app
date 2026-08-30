import 'dart:convert';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/device_alarm_generation_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v1.1.4 state without a marker uses the stable legacy generation',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final datasetId = await _datasetId(database);
      await _insertOldReplaceAudit(database, 'old-restore-without-marker');

      final store = DeviceAlarmGenerationStore(database);

      expect(await store.readCurrent(), 'legacy:$datasetId');
      expect(await store.readCurrent(), 'legacy:$datasetId');
    },
  );

  test(
    'only a succeeded replace audit with a matching UUID marker is used',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final datasetId = await _datasetId(database);
      await _insertOldReplaceAudit(
        database,
        'not-a-uuid',
        summary: const <String, Object?>{'alarmGeneration': 'not-a-uuid'},
      );
      await _insertOldReplaceAudit(
        database,
        '11111111-1111-4111-8111-111111111111',
        status: 'failed',
        summary: const <String, Object?>{
          'alarmGeneration': '11111111-1111-4111-8111-111111111111',
        },
      );
      await _insertOldReplaceAudit(
        database,
        '22222222-2222-4222-8222-222222222222',
        summary: const <String, Object?>{
          'alarmGeneration': '33333333-3333-4333-8333-333333333333',
        },
      );

      expect(
        await DeviceAlarmGenerationStore(database).readCurrent(),
        'legacy:$datasetId',
      );
    },
  );

  test(
    'replacement creation rotates and persists one current generation',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DeviceAlarmGenerationStore(database);
      const first = '44444444-4444-4444-8444-444444444444';
      const second = '55555555-5555-4555-8555-555555555555';

      await store.createForReplacement(
        operationId: first,
        sourceName: 'first.dgbak',
        sourceSha256: List<String>.filled(64, 'a').join(),
        sourceSchemaVersion: 1,
        encrypted: false,
        safetyCopyName: 'first.sqlite',
        completedAtUtc: 1,
      );
      expect(await store.readCurrent(), first);

      await store.createForReplacement(
        operationId: second,
        sourceName: 'second.dgbak',
        sourceSha256: List<String>.filled(64, 'b').join(),
        sourceSchemaVersion: 1,
        encrypted: true,
        safetyCopyName: 'second.sqlite',
        completedAtUtc: 2,
      );

      expect(await store.readCurrent(), second);
      final rows = await database
          .customSelect(
            "SELECT id, summary_json FROM restore_runs WHERE mode = 'replace' "
            "AND status = 'succeeded' ORDER BY rowid",
          )
          .get();
      expect(rows, hasLength(2));
      expect(rows.first.read<String>('summary_json'), isNot(contains(first)));
      expect(rows.last.read<String>('summary_json'), contains(second));
    },
  );

  test('existing uppercase UUID marker reads as canonical lowercase', () async {
    final database = DangguiDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const uppercase = 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF';
    const canonical = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
    await _insertOldReplaceAudit(
      database,
      uppercase,
      summary: const <String, Object?>{'alarmGeneration': uppercase},
    );

    expect(await DeviceAlarmGenerationStore(database).readCurrent(), canonical);
  });

  test(
    'replacement creation canonicalizes the row and marker together',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      const uppercase = 'ABCDEFAB-CDEF-4ABC-8DEF-ABCDEFABCDEF';
      const canonical = 'abcdefab-cdef-4abc-8def-abcdefabcdef';
      final store = DeviceAlarmGenerationStore(database);

      expect(
        await store.createForReplacement(
          operationId: uppercase,
          sourceName: 'uppercase.dgbak',
          sourceSha256: List<String>.filled(64, 'e').join(),
          sourceSchemaVersion: 1,
          encrypted: false,
          safetyCopyName: 'uppercase.sqlite',
          completedAtUtc: 5,
        ),
        canonical,
      );

      final row = await database
          .customSelect('SELECT id, summary_json FROM restore_runs')
          .getSingle();
      expect(row.read<String>('id'), canonical);
      expect(row.read<String>('summary_json'), contains(canonical));
      expect(row.read<String>('summary_json'), isNot(contains(uppercase)));
      expect(await store.readCurrent(), canonical);
    },
  );

  test(
    'portable snapshot stripping removes the device generation marker',
    () async {
      final database = DangguiDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = DeviceAlarmGenerationStore(database);
      const generation = '66666666-6666-4666-8666-666666666666';
      await store.createForReplacement(
        operationId: generation,
        sourceName: 'source.dgbak',
        sourceSha256: List<String>.filled(64, 'c').join(),
        sourceSchemaVersion: 1,
        encrypted: false,
        safetyCopyName: 'safety.sqlite',
        completedAtUtc: 3,
      );

      await store.stripFromPortableSnapshot();

      expect(await store.readCurrent(), startsWith('legacy:'));
      final summary = await database
          .customSelect('SELECT summary_json FROM restore_runs')
          .getSingle();
      expect(
        summary.read<String>('summary_json'),
        isNot(contains(DeviceAlarmGenerationStore.markerKey)),
      );
    },
  );

  test('portable stripping fails closed on an opaque audit summary', () async {
    final database = DangguiDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = DeviceAlarmGenerationStore(database);
    const generation = '77777777-7777-4777-8777-777777777777';
    await store.createForReplacement(
      operationId: generation,
      sourceName: 'source.dgbak',
      sourceSha256: List<String>.filled(64, 'd').join(),
      sourceSchemaVersion: 1,
      encrypted: false,
      safetyCopyName: 'safety.sqlite',
      completedAtUtc: 4,
    );
    await database.customStatement(
      'UPDATE restore_runs SET summary_json = ? WHERE id = ?',
      <Object?>['{"alarmGeneration":"$generation"', generation],
    );

    await expectLater(
      store.stripFromPortableSnapshot(),
      throwsA(isA<FormatException>()),
    );
    final summary = await database
        .customSelect(
          'SELECT summary_json FROM restore_runs WHERE id = ?',
          variables: [Variable.withString(generation)],
        )
        .getSingle();
    expect(summary.read<String>('summary_json'), contains(generation));
  });
}

Future<String> _datasetId(DangguiDatabase database) async {
  final row = await database
      .customSelect('SELECT dataset_id FROM app_meta WHERE id = 1')
      .getSingle();
  return row.read<String>('dataset_id');
}

Future<void> _insertOldReplaceAudit(
  DangguiDatabase database,
  String id, {
  String status = 'succeeded',
  Map<String, Object?> summary = const <String, Object?>{},
}) {
  return database.customStatement(
    'INSERT INTO restore_runs '
    '(id, source_name, source_sha256, mode, source_schema_version, '
    'pre_restore_backup_run_id, status, summary_json, started_at_utc, '
    'completed_at_utc, error_code) '
    'VALUES (?, ?, NULL, ?, 1, NULL, ?, ?, 0, 0, NULL)',
    <Object?>[id, 'legacy.dgbak', 'replace', status, jsonEncode(summary)],
  );
}
