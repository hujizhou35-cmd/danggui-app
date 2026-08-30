import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data_protection.dart';
import 'database.dart';
import 'database_file_recovery.dart';

final dataProtectionPlatformProvider = Provider<DataProtectionPlatform>(
  (ref) => const MethodChannelDataProtectionPlatform(),
);

final databaseTemporaryDirectoryReaderProvider =
    Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

final databaseApplicationSupportDirectoryReaderProvider =
    Provider<Future<Directory> Function()>(
      (ref) => getApplicationSupportDirectory,
    );

final databaseFileProvider = FutureProvider<File>((ref) async {
  return prepareDatabaseFileForOpen(
    protectionPlatform: ref.watch(dataProtectionPlatformProvider),
    readTemporaryDirectory: ref.watch(databaseTemporaryDirectoryReaderProvider),
    readApplicationSupportDirectory: ref.watch(
      databaseApplicationSupportDirectoryReaderProvider,
    ),
  );
});

Future<File> prepareDatabaseFileForOpen({
  required DataProtectionPlatform protectionPlatform,
  required Future<Directory> Function() readTemporaryDirectory,
  required Future<Directory> Function() readApplicationSupportDirectory,
}) async {
  // Temporary plaintext belongs to the app but not to the protected
  // Application Support tree. Clean it before a persisted protection failure
  // can abort startup and leave a previous staging copy behind indefinitely.
  await DatabaseFileRecovery.purgeStalePlaintextArtifacts(
    await readTemporaryDirectory(),
  );
  final protection = await protectionPlatform.ensureAvailable();
  if (!protection.isAvailable) {
    throw DataProtectionUnavailableException(protection.errorCode ?? 'unknown');
  }
  final directory = await readApplicationSupportDirectory();
  return File(p.join(directory.path, 'danggui', 'danggui.sqlite'));
}

final databaseProvider = FutureProvider<DangguiDatabase>((ref) async {
  final file = await ref.watch(databaseFileProvider.future);
  await DatabaseFileRecovery.recoverIfNeeded(file);
  final database = DangguiDatabase.open(file);
  try {
    // Once per provider lifetime, before repositories can issue writes. This
    // intentionally uses full integrity_check: quick_check can report `ok`
    // for a non-unique entry hidden behind a corrupted UNIQUE index schema.
    await validateDatabaseForStartup(database);
  } on Object {
    try {
      await database.close();
    } on Object {
      // Closing a rejected database must not replace its validation failure.
    }
    rethrow;
  }
  ref.onDispose(database.close);
  return database;
});

Future<void> validateDatabaseForStartup(DangguiDatabase database) async {
  final integrity = await database.integrityCheck();
  if (integrity.length != 1 || integrity.single.toLowerCase() != 'ok') {
    throw StateError('SQLite integrity_check failed.');
  }
  final foreignKeys = await database.foreignKeyCheck();
  if (foreignKeys.isNotEmpty) {
    throw StateError('SQLite foreign_key_check failed.');
  }
}
