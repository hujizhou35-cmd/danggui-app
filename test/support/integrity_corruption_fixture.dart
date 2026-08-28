import 'dart:io';

import 'package:danggui/src/data/database.dart';

/// Creates a real SQLite inconsistency deliberately omitted by quick_check.
///
/// The index is built as non-unique over duplicate rows, then only its
/// sqlite_schema declaration is changed to UNIQUE. On the next connection,
/// quick_check reports `ok` while integrity_check reports the duplicate index
/// entry. This mirrors the class of corruption restore validation must catch.
Future<void> corruptDatabaseSoQuickPassesButIntegrityFails(File file) async {
  final database = DangguiDatabase.open(file);
  try {
    await database.customStatement(
      'CREATE TABLE integrity_probe (value TEXT NOT NULL)',
    );
    await database.customStatement(
      'CREATE INDEX idx_integrity_probe_value ON integrity_probe(value)',
    );
    await database.customStatement(
      "INSERT INTO integrity_probe(value) VALUES ('duplicate'), ('duplicate')",
    );
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await database.customStatement('PRAGMA writable_schema = ON');
    try {
      await database.customStatement(
        "UPDATE sqlite_schema SET sql = "
        "'CREATE UNIQUE INDEX idx_integrity_probe_value "
        "ON integrity_probe(value)' "
        "WHERE name = 'idx_integrity_probe_value'",
      );
    } finally {
      await database.customStatement('PRAGMA writable_schema = OFF');
    }
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  } finally {
    await database.close();
  }
}
