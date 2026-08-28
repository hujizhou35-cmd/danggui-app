import 'dart:io';

import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/data/database_schema_verifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('pristine generated schema is accepted', () async {
    final database = DangguiDatabase.open(
      await _temporaryDatabaseFile('pristine'),
    );
    addTearDown(database.close);

    await expectLater(DangguiSchemaVerifier.verify(database), completes);
  });

  test('unexpected trigger is rejected', () async {
    final database = DangguiDatabase.open(
      await _temporaryDatabaseFile('trigger'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').getSingle();
    await database.customStatement(
      'CREATE TRIGGER malicious_platform_delete '
      'AFTER DELETE ON platform_jobs BEGIN DELETE FROM tasks; END',
    );

    await expectLater(
      DangguiSchemaVerifier.verify(database),
      throwsA(isA<FormatException>()),
    );
  });

  test('missing generated index is rejected', () async {
    final database = DangguiDatabase.open(
      await _temporaryDatabaseFile('index'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').getSingle();
    await database.customStatement('DROP INDEX idx_tasks_due_date');

    await expectLater(
      DangguiSchemaVerifier.verify(database),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<File> _temporaryDatabaseFile(String suffix) async {
  final directory = await Directory.systemTemp.createTemp(
    'danggui-schema-$suffix-',
  );
  addTearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  return File(p.join(directory.path, 'danggui.sqlite'));
}
