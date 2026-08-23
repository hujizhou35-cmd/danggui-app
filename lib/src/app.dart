import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'application/app_store.dart';
import 'core/theme/theme.dart';
import 'domain/models.dart';
import 'features/launch/startup_page.dart';
import 'features/notes/note_editor_page.dart';
import 'features/notes/notes_page.dart';
import 'features/past/past_page.dart';
import 'features/settings/help_page.dart';
import 'features/settings/recently_deleted_page.dart';
import 'features/settings/settings_page.dart';
import 'features/shell/app_shell.dart';
import 'features/tasks/task_detail_page.dart';
import 'features/tasks/tasks_page.dart';
import 'services/backup/automatic_backup_coordinator.dart';
import 'services/notifications/notification_coordinator.dart';
import 'ui/components/ime_inset_guard.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/launch',
    routes: <RouteBase>[
      GoRoute(
        path: '/launch',
        builder: (context, state) => const StartupPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':taskId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        TaskDetailPage(taskId: state.pathParameters['taskId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/past',
                builder: (context, state) => const PastPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/notes',
                builder: (context, state) => const NotesPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':noteId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        NoteEditorPage(noteId: state.pathParameters['noteId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'help',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const HelpPage(),
                  ),
                  GoRoute(
                    path: RecentlyDeletedPage.routeName,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => RecentlyDeletedPage(
                      onChanged: () =>
                          ref.read(appStoreProvider.notifier).refresh(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class DangguiApp extends ConsumerStatefulWidget {
  const DangguiApp({super.key, this.sansFontFamily});

  /// A deterministic font-family seam used by visual regression tests.
  /// Production leaves this null and uses each platform's native sans stack.
  final String? sansFontFamily;

  @override
  ConsumerState<DangguiApp> createState() => _DangguiAppState();
}

class _DangguiAppState extends ConsumerState<DangguiApp>
    with WidgetsBindingObserver {
  var _startupReconciled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _startupReconciled) {
      unawaited(_reconcileAutomaticBackup(startup: false));
      unawaited(_reconcileNotifications(refreshStore: true));
    }
  }

  Future<void> _reconcileNotifications({required bool refreshStore}) async {
    try {
      await ref.read(notificationCoordinatorProvider).reconcile();
    } on Object catch (error, stackTrace) {
      // A platform permission query must never prevent the local app from
      // starting or returning to the foreground. Durable jobs retry later.
      if (kDebugMode) {
        debugPrint('Notification reconciliation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (refreshStore && mounted) {
      try {
        await ref.read(appStoreProvider.notifier).refresh();
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Notification state refresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
  }

  Future<void> _reconcileAutomaticBackup({required bool startup}) async {
    try {
      final coordinator = ref.read(automaticBackupCoordinatorProvider);
      if (startup) {
        await coordinator.onStartup();
      } else {
        await coordinator.onForeground();
      }
    } on Object catch (error, stackTrace) {
      // BackupService records write failures in its local audit table. Errors
      // must never prevent the offline app from opening.
      if (kDebugMode) {
        debugPrint('Automatic backup reconciliation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(notificationStateRevisionProvider, (previous, next) {
      if (previous == null || previous == next) return;
      unawaited(_refreshStoreAfterNotificationAction());
    });
    final appState = ref.watch(appStoreProvider).value;
    if (appState != null) {
      if (!_startupReconciled) {
        _startupReconciled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_reconcileNotifications(refreshStore: true));
            unawaited(_reconcileAutomaticBackup(startup: true));
          }
        });
      }
    }
    final settings = appState?.settings ?? const AppSettingsModel();
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '当归',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: _localeFor(settings.localeMode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (settings.localeMode != LocaleMode.system) {
          return _localeFor(settings.localeMode);
        }
        if (locale != null) {
          for (final candidate in supported) {
            if (candidate.languageCode == locale.languageCode) {
              return candidate;
            }
          }
        }
        return const Locale('zh');
      },
      theme: DangguiTheme.light(
        compact: settings.density == DisplayDensity.compact,
        serifBody: settings.fontMode == FontMode.serif,
        sansFontFamily: widget.sansFontFamily,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final userScale = settings.textScalePercent / 100;
        final combined = (media.textScaler.scale(1) * userScale).clamp(.9, 2.0);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(combined)),
          child: ImeInsetGuard(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }

  Future<void> _refreshStoreAfterNotificationAction() async {
    try {
      await ref.read(appStoreProvider.notifier).refresh();
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Notification action state refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}

Locale? _localeFor(LocaleMode mode) {
  return switch (mode) {
    LocaleMode.system => null,
    LocaleMode.zhHans => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ),
    LocaleMode.en => const Locale('en'),
    LocaleMode.ja => const Locale('ja'),
    LocaleMode.ru => const Locale('ru'),
  };
}
