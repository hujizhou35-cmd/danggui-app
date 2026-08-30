import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/database_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/integrity_corruption_fixture.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'danggui-database-durability-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'file database enables WAL, foreign keys, and FULL durability',
    () async {
      final database = DangguiDatabase.open(
        File(p.join(directory.path, 'durable.sqlite')),
      );
      try {
        final journal = await database
            .customSelect('PRAGMA journal_mode')
            .getSingle();
        final synchronous = await database
            .customSelect('PRAGMA synchronous')
            .getSingle();
        final foreignKeys = await database
            .customSelect('PRAGMA foreign_keys')
            .getSingle();

        expect(journal.data.values.single.toString().toLowerCase(), 'wal');
        expect(synchronous.data.values.single, 2);
        expect(foreignKeys.data.values.single, 1);
      } finally {
        await database.close();
      }
    },
  );

  test('future schema is rejected instead of silently downgraded', () async {
    final file = File(p.join(directory.path, 'future.sqlite'));
    final original = DangguiDatabase.open(file);
    await original.customSelect('SELECT 1').get();
    await original.customStatement('PRAGMA user_version = 2');
    await original.close();

    final reopened = DangguiDatabase.open(file);
    try {
      await expectLater(
        reopened.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
    } finally {
      await reopened.close();
    }
  });

  test(
    'startup full integrity rejects corruption hidden from quick_check',
    () async {
      final file = File(p.join(directory.path, 'quick-only-corrupt.sqlite'));
      final original = DangguiDatabase.open(file);
      await original.customSelect('SELECT 1').get();
      await original.close();
      await corruptDatabaseSoQuickPassesButIntegrityFails(file);

      final reopened = DangguiDatabase.open(file);
      addTearDown(reopened.close);
      expect(await reopened.quickCheck(), const <String>['ok']);

      await expectLater(
        validateDatabaseForStartup(reopened),
        throwsA(isA<StateError>()),
      );
    },
  );
}
