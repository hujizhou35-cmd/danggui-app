import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Serializes native reminder projection changes with destructive database
/// replacement.
///
/// SQLite transactions protect rows inside one database, but a replace restore
/// closes that database and atomically swaps its file. Without this process
/// gate, a reminder reconciliation can resume after the close and install an
/// alarm from the losing database generation. The gate deliberately covers
/// only in-process work; native generation activation supplies the durable
/// cross-process fence.
final class PlatformMutationGate {
  Future<void> _tail = Future<void>.value();

  Future<T> protect<T>(Future<T> Function() operation) {
    final predecessor = _tail;
    final release = Completer<void>();
    _tail = release.future;

    return () async {
      await predecessor;
      try {
        return await operation();
      } finally {
        if (!release.isCompleted) release.complete();
      }
    }();
  }
}

final platformMutationGateProvider = Provider<PlatformMutationGate>(
  (ref) => PlatformMutationGate(),
);
