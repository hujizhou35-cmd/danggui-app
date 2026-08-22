import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/domain/models.dart';
import 'package:danggui/src/features/settings/recently_deleted_page.dart';
import 'package:danggui/src/services/trash/trash_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the localized Japanese empty and semantic states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final service = _FakeTrashService(<RecentlyDeletedItem>[]);

    await tester.pumpWidget(
      _TestApp(locale: const Locale('ja'), service: service),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近削除した項目'), findsWidgets);
    expect(find.text('最近削除した項目はありません'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('trash-empty-state')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('最近削除した項目はありません.*30日間保存されます')),
      findsOneWidget,
    );
    expect(service.purgeCalls, 1);
    semantics.dispose();
  });

  testWidgets('renders metadata and requires confirmation to delete forever', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = _item(id: 'task-1', remainingDays: 5);
    final service = _FakeTrashService(<RecentlyDeletedItem>[item]);

    await tester.pumpWidget(
      _TestApp(locale: const Locale('en'), service: service),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task to recover'), findsOneWidget);
    expect(find.textContaining('Task · Deleted'), findsOneWidget);
    expect(find.textContaining('August 22, 2026'), findsOneWidget);
    expect(find.text('5 days remaining'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('trash-delete-task-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('trash-delete-dialog')),
      findsOneWidget,
    );
    expect(service.permanentlyDeleted, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('trash-delete-cancel')));
    await tester.pumpAndSettle();
    expect(service.permanentlyDeleted, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('trash-delete-task-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('trash-delete-confirm')),
    );
    await tester.pumpAndSettle();

    expect(service.permanentlyDeleted, <String>['task-1']);
    expect(find.text('Item permanently deleted'), findsOneWidget);
  });

  testWidgets('restores an item and calls the integration refresh hook', (
    tester,
  ) async {
    final service = _FakeTrashService(<RecentlyDeletedItem>[
      _item(id: 'note-1', type: TrashEntityType.note),
    ]);
    var refreshCount = 0;

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('en'),
        service: service,
        onChanged: () async => refreshCount++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('trash-restore-note-1')),
    );
    await tester.pumpAndSettle();

    expect(service.restored, <String>['note-1']);
    expect(refreshCount, 1);
    expect(find.text('Item restored'), findsOneWidget);
  });
}

RecentlyDeletedItem _item({
  required String id,
  TrashEntityType type = TrashEntityType.task,
  int remainingDays = 12,
}) {
  return RecentlyDeletedItem(
    id: id,
    entityType: type,
    entityId: 'entity-$id',
    title: type == TrashEntityType.task ? 'Task to recover' : 'Note to recover',
    deletedAtUtc: DateTime.utc(2026, 8, 22, 10),
    purgeAfterUtc: DateTime.utc(2026, 9, 21, 10),
    remainingDays: remainingDays,
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.locale, required this.service, this.onChanged});

  final Locale locale;
  final TrashServiceApi service;
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RecentlyDeletedPage(service: service, onChanged: onChanged),
    );
  }
}

final class _FakeTrashService implements TrashServiceApi {
  _FakeTrashService(this.items);

  final List<RecentlyDeletedItem> items;
  final List<String> restored = <String>[];
  final List<String> permanentlyDeleted = <String>[];
  int purgeCalls = 0;

  @override
  Future<List<RecentlyDeletedItem>> loadItems() async =>
      List<RecentlyDeletedItem>.unmodifiable(items);

  @override
  Future<void> permanentlyDelete(String trashEntryId) async {
    permanentlyDeleted.add(trashEntryId);
  }

  @override
  Future<int> purgeExpired() async {
    purgeCalls++;
    return 0;
  }

  @override
  Future<void> restore(String trashEntryId) async {
    restored.add(trashEntryId);
  }

  @override
  Stream<List<RecentlyDeletedItem>> watchItems() =>
      Stream<List<RecentlyDeletedItem>>.value(
        List<RecentlyDeletedItem>.unmodifiable(items),
      );
}
