import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

final databaseFileProvider = FutureProvider<File>((ref) async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, 'danggui', 'danggui.sqlite'));
});

final databaseProvider = FutureProvider<DangguiDatabase>((ref) async {
  final file = await ref.watch(databaseFileProvider.future);
  final database = DangguiDatabase.open(file);
  ref.onDispose(database.close);
  final quickCheck = await database.quickCheck();
  if (quickCheck.length != 1 || quickCheck.single.toLowerCase() != 'ok') {
    throw StateError('SQLite quick_check failed: ${quickCheck.join(', ')}');
  }
  final foreignKeys = await database.foreignKeyCheck();
  if (foreignKeys.isNotEmpty) {
    throw StateError('SQLite foreign_key_check failed: $foreignKeys');
  }
  return database;
});
