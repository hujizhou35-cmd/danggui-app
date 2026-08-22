import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../domain/models.dart';
import '../../services/trash/trash_service.dart';
import '../../ui/components/components.dart';

class RecentlyDeletedPage extends ConsumerStatefulWidget {
  const RecentlyDeletedPage({super.key, this.service, this.onChanged});

  static const routeName = 'recently-deleted';
  static const routePath = '/settings/recently-deleted';

  /// Optional injection point for tests and embedding outside the main scope.
  final TrashServiceApi? service;

  /// Lets the settings integration refresh its in-memory app state after a
  /// restore or purge without coupling this page to AppStoreController.
  final Future<void> Function()? onChanged;

  @override
  ConsumerState<RecentlyDeletedPage> createState() =>
      _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends ConsumerState<RecentlyDeletedPage> {
  late final TrashServiceApi _service;
  late Stream<List<RecentlyDeletedItem>> _items;
  final Set<String> _busyEntries = <String>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ref.read(trashServiceProvider);
    _items = _watchAfterCleanup();
  }

  Stream<List<RecentlyDeletedItem>> _watchAfterCleanup() async* {
    final removed = await _service.purgeExpired();
    if (removed > 0) await widget.onChanged?.call();
    yield* _service.watchItems();
  }

  Future<void> _retry() async {
    setState(() => _items = _watchAfterCleanup());
  }

  @override
  Widget build(BuildContext context) {
    final copy = _TrashCopy.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              DangguiTopBar(
                leading: DangguiIconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  semanticLabel: copy.back,
                  tooltip: copy.back,
                  onPressed: () => Navigator.maybePop(context),
                ),
                content: Semantics(
                  header: true,
                  child: Text(
                    copy.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: StreamBuilder<List<RecentlyDeletedItem>>(
                          stream: _items,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return _TrashError(copy: copy, onRetry: _retry);
                            }
                            if (!snapshot.hasData) {
                              return Center(
                                child: Semantics(
                                  label: copy.loading,
                                  child: const CircularProgressIndicator(),
                                ),
                              );
                            }
                            final items = snapshot.requireData;
                            if (items.isEmpty) {
                              return _TrashEmpty(copy: copy, onRefresh: _retry);
                            }
                            return Semantics(
                              container: true,
                              label: copy.listSummary(items.length),
                              child: RefreshIndicator(
                                onRefresh: _retry,
                                child: ListView.separated(
                                  key: const PageStorageKey<String>(
                                    'recently-deleted-list',
                                  ),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    context.dangguiTheme.pageHorizontalPadding,
                                    8,
                                    context.dangguiTheme.pageHorizontalPadding,
                                    32,
                                  ),
                                  itemCount: items.length + 1,
                                  separatorBuilder: (context, index) =>
                                      SizedBox(
                                        height: context.dangguiTheme.cardGap,
                                      ),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _RetentionNotice(copy: copy);
                                    }
                                    final item = items[index - 1];
                                    return _TrashCard(
                                      key: ValueKey<String>(
                                        'trash-card-${item.id}',
                                      ),
                                      item: item,
                                      copy: copy,
                                      busy: _busyEntries.contains(item.id),
                                      onRestore: () => _restore(item),
                                      onDelete: () => _confirmDelete(item),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restore(RecentlyDeletedItem item) async {
    if (_busyEntries.contains(item.id)) return;
    final copy = _TrashCopy.of(context);
    setState(() => _busyEntries.add(item.id));
    try {
      await _service.restore(item.id);
      await widget.onChanged?.call();
      if (mounted) _showMessage(copy.restored);
    } on Object {
      if (mounted) _showMessage(copy.operationFailed);
    } finally {
      if (mounted) setState(() => _busyEntries.remove(item.id));
    }
  }

  Future<void> _confirmDelete(RecentlyDeletedItem item) async {
    if (_busyEntries.contains(item.id)) return;
    final copy = _TrashCopy.of(context);
    final title = item.title.trim().isEmpty ? copy.untitled : item.title.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('trash-delete-dialog'),
        title: Text(copy.confirmTitle),
        content: Text(copy.confirmBody(title)),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('trash-delete-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            key: const ValueKey<String>('trash-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: context.dangguiTheme.terra,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyEntries.add(item.id));
    try {
      await _service.permanentlyDelete(item.id);
      await widget.onChanged?.call();
      if (mounted) _showMessage(copy.permanentlyDeleted);
    } on Object {
      if (mounted) _showMessage(copy.operationFailed);
    } finally {
      if (mounted) setState(() => _busyEntries.remove(item.id));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RetentionNotice extends StatelessWidget {
  const _RetentionNotice({required this.copy});

  final _TrashCopy copy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return Semantics(
      container: true,
      label: copy.retentionHint,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.sageSoft.withAlpha(132),
            border: Border.all(color: tokens.sage.withAlpha(70)),
            borderRadius: tokens.controlRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline_rounded, size: 19, color: tokens.sage),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    copy.retentionHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    super.key,
    required this.item,
    required this.copy,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final RecentlyDeletedItem item;
  final _TrashCopy copy;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final localDeletedAt = item.deletedAtUtc.toLocal();
    final material = MaterialLocalizations.of(context);
    final deletedDate = material.formatFullDate(localDeletedAt);
    final deletedTime = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDeletedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final title = item.title.trim().isEmpty ? copy.untitled : item.title.trim();
    final type = item.entityType == TrashEntityType.task
        ? copy.task
        : copy.note;
    final summary = copy.itemSummary(
      type: type,
      title: title,
      deletedAt: '$deletedDate $deletedTime',
      remainingDays: item.remainingDays,
    );

    return SketchCard(
      semanticLabel: summary,
      alternate: item.entityType == TrashEntityType.note,
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 13),
      constraints: const BoxConstraints(minHeight: 112),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.entityType == TrashEntityType.task
                        ? tokens.sageSoft
                        : tokens.terraSoft,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 42,
                    child: Icon(
                      item.entityType == TrashEntityType.task
                          ? Icons.check_circle_outline_rounded
                          : Icons.sticky_note_2_outlined,
                      size: 22,
                      color: item.entityType == TrashEntityType.task
                          ? tokens.sage
                          : tokens.terra,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$type · ${copy.deletedAt} $deletedDate $deletedTime',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: tokens.muted),
                    ),
                    const SizedBox(height: 7),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: item.remainingDays <= 3
                            ? tokens.terraSoft
                            : tokens.paper3,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          copy.remaining(item.remainingDays),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: item.remainingDays <= 3
                                    ? tokens.terra
                                    : tokens.muted,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (busy) ...<Widget>[
                const SizedBox(width: 10),
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          );

          if (constraints.maxWidth < 500) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                details,
                const SizedBox(height: 10),
                Divider(height: 1, color: tokens.line),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton.icon(
                        key: ValueKey<String>('trash-restore-${item.id}'),
                        onPressed: busy ? null : onRestore,
                        icon: const Icon(Icons.restore_rounded, size: 19),
                        label: Text(copy.restore),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        key: ValueKey<String>('trash-delete-${item.id}'),
                        onPressed: busy ? null : onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.terra,
                        ),
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 19,
                        ),
                        label: Text(copy.deleteForever),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: details),
              const SizedBox(width: 14),
              SizedBox(
                width: 154,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: ValueKey<String>('trash-restore-${item.id}'),
                      onPressed: busy ? null : onRestore,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(copy.restore),
                    ),
                    TextButton.icon(
                      key: ValueKey<String>('trash-delete-${item.id}'),
                      onPressed: busy ? null : onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.terra,
                      ),
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: Text(copy.deleteForever),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TrashEmpty extends StatelessWidget {
  const _TrashEmpty({required this.copy, required this.onRefresh});

  final _TrashCopy copy;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey<String>('trash-empty-state'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * .2),
          Semantics(
            container: true,
            label: '${copy.emptyTitle}. ${copy.emptyBody}',
            child: ExcludeSemantics(
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.delete_sweep_outlined,
                    size: 54,
                    color: tokens.muted2,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    copy.emptyTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.emptyBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrashError extends StatelessWidget {
  const _TrashError({required this.copy, required this.onRetry});

  final _TrashCopy copy;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: copy.loadError,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(copy.loadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const ValueKey<String>('trash-retry'),
                onPressed: onRetry,
                child: Text(copy.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TrashCopy {
  const _TrashCopy({
    required this.language,
    required this.title,
    required this.back,
    required this.loading,
    required this.retentionHint,
    required this.emptyTitle,
    required this.emptyBody,
    required this.task,
    required this.note,
    required this.untitled,
    required this.deletedAt,
    required this.restore,
    required this.deleteForever,
    required this.confirmTitle,
    required this.confirmBodyPattern,
    required this.cancel,
    required this.confirmDelete,
    required this.restored,
    required this.permanentlyDeleted,
    required this.operationFailed,
    required this.loadError,
    required this.retry,
  });

  final String language;
  final String title;
  final String back;
  final String loading;
  final String retentionHint;
  final String emptyTitle;
  final String emptyBody;
  final String task;
  final String note;
  final String untitled;
  final String deletedAt;
  final String restore;
  final String deleteForever;
  final String confirmTitle;
  final String confirmBodyPattern;
  final String cancel;
  final String confirmDelete;
  final String restored;
  final String permanentlyDeleted;
  final String operationFailed;
  final String loadError;
  final String retry;

  String confirmBody(String itemTitle) =>
      confirmBodyPattern.replaceFirst('{title}', itemTitle);

  String remaining(int days) => switch (language) {
    'en' => days == 1 ? '1 day remaining' : '$days days remaining',
    'ja' => '残り$days日',
    'ru' => 'Осталось дней: $days',
    _ => '剩余 $days 天',
  };

  String listSummary(int count) => switch (language) {
    'en' => '$count recently deleted items',
    'ja' => '最近削除した項目は$count件',
    'ru' => 'Недавно удалено: $count',
    _ => '最近删除共 $count 项',
  };

  String itemSummary({
    required String type,
    required String title,
    required String deletedAt,
    required int remainingDays,
  }) =>
      '$type, $title, ${this.deletedAt} $deletedAt, '
      '${remaining(remainingDays)}';

  static _TrashCopy of(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'en' => _en,
      'ja' => _ja,
      'ru' => _ru,
      _ => _zh,
    };
  }

  static const _zh = _TrashCopy(
    language: 'zh',
    title: '最近删除',
    back: '返回',
    loading: '正在读取最近删除',
    retentionHint: '删除的事项和笔记保留 30 天，到期后会从本机自动永久删除。',
    emptyTitle: '最近删除是空的',
    emptyBody: '从这里删除的内容会在此保留 30 天。',
    task: '事项',
    note: '笔记',
    untitled: '无标题',
    deletedAt: '删除于',
    restore: '恢复',
    deleteForever: '永久删除',
    confirmTitle: '永久删除？',
    confirmBodyPattern: '“{title}”及其正文将从本机永久删除，此操作无法撤销。',
    cancel: '取消',
    confirmDelete: '确认删除',
    restored: '已恢复',
    permanentlyDeleted: '已永久删除',
    operationFailed: '操作失败，请重试。',
    loadError: '无法读取最近删除。',
    retry: '重试',
  );

  static const _en = _TrashCopy(
    language: 'en',
    title: 'Recently deleted',
    back: 'Back',
    loading: 'Loading recently deleted items',
    retentionHint: 'Deleted tasks and notes stay here for 30 days, then are permanently removed from this device.',
    emptyTitle: 'Recently deleted is empty',
    emptyBody: 'Tasks and notes you delete will remain here for 30 days.',
    task: 'Task',
    note: 'Note',
    untitled: 'Untitled',
    deletedAt: 'Deleted',
    restore: 'Restore',
    deleteForever: 'Delete forever',
    confirmTitle: 'Delete forever?',
    confirmBodyPattern: '“{title}” and its content will be permanently removed from this device. This cannot be undone.',
    cancel: 'Cancel',
    confirmDelete: 'Delete',
    restored: 'Item restored',
    permanentlyDeleted: 'Item permanently deleted',
    operationFailed: 'The operation failed. Please try again.',
    loadError: 'Recently deleted items could not be loaded.',
    retry: 'Retry',
  );

  static const _ja = _TrashCopy(
    language: 'ja',
    title: '最近削除した項目',
    back: '戻る',
    loading: '最近削除した項目を読み込み中',
    retentionHint: '削除した事項とノートは30日間保存され、期限後にこの端末から完全に削除されます。',
    emptyTitle: '最近削除した項目はありません',
    emptyBody: '削除した事項とノートはここに30日間保存されます。',
    task: '事項',
    note: 'ノート',
    untitled: '無題',
    deletedAt: '削除日時',
    restore: '復元',
    deleteForever: '完全に削除',
    confirmTitle: '完全に削除しますか？',
    confirmBodyPattern: '「{title}」とその内容をこの端末から完全に削除します。この操作は取り消せません。',
    cancel: 'キャンセル',
    confirmDelete: '削除',
    restored: '復元しました',
    permanentlyDeleted: '完全に削除しました',
    operationFailed: '操作に失敗しました。もう一度お試しください。',
    loadError: '最近削除した項目を読み込めません。',
    retry: '再試行',
  );

  static const _ru = _TrashCopy(
    language: 'ru',
    title: 'Недавно удалённые',
    back: 'Назад',
    loading: 'Загрузка недавно удалённых элементов',
    retentionHint: 'Удалённые дела и заметки хранятся 30 дней, затем навсегда удаляются с этого устройства.',
    emptyTitle: 'Недавно удалённых элементов нет',
    emptyBody: 'Удалённые дела и заметки будут храниться здесь 30 дней.',
    task: 'Дело',
    note: 'Заметка',
    untitled: 'Без названия',
    deletedAt: 'Удалено',
    restore: 'Восстановить',
    deleteForever: 'Удалить навсегда',
    confirmTitle: 'Удалить навсегда?',
    confirmBodyPattern: '«{title}» и его содержимое будут навсегда удалены с этого устройства. Отменить это нельзя.',
    cancel: 'Отмена',
    confirmDelete: 'Удалить',
    restored: 'Элемент восстановлен',
    permanentlyDeleted: 'Элемент удалён навсегда',
    operationFailed: 'Не удалось выполнить операцию. Повторите попытку.',
    loadError: 'Не удалось загрузить недавно удалённые элементы.',
    retry: 'Повторить',
  );
}
