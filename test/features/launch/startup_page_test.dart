import 'dart:io';

import 'package:danggui/l10n/app_localizations.dart';
import 'package:danggui/src/application/app_store.dart';
import 'package:danggui/src/core/theme/theme.dart';
import 'package:danggui/src/data/database.dart';
import 'package:danggui/src/features/launch/startup_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late DangguiDatabase database;
  late ProviderContainer container;

  setUp(() async {
    database = DangguiDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => database)],
    );
    await container.read(appStoreProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets(
    'waits one second after the first brand frame, then navigates once',
    (tester) async {
      var destinationMounts = 0;
      final router = GoRouter(
        initialLocation: '/startup',
        routes: <RouteBase>[
          GoRoute(
            path: '/startup',
            builder: (context, state) => const StartupPage(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) =>
                _Destination(onMount: () => destinationMounts += 1),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testApp(container, router));
      expect(find.byType(StartupPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('startup-brand-composition')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('startup-watercolor-artwork')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('startup-privacy-tagline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('startup-progress')),
        findsOneWidget,
      );

      // Decode and paint the real launch artwork. The one-second clock starts
      // only after this complete image frame becomes visible.
      await _waitForArtworkFrame(tester);

      await tester.pump(const Duration(milliseconds: 999));
      expect(find.byType(StartupPage), findsOneWidget);
      expect(destinationMounts, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('startup-destination')),
        findsOneWidget,
      );
      expect(destinationMounts, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(destinationMounts, 1);
    },
  );

  testWidgets('supports an injected minimum display duration', (tester) async {
    final router = GoRouter(
      initialLocation: '/startup',
      routes: <RouteBase>[
        GoRoute(
          path: '/startup',
          builder: (context, state) => const StartupPage(
            minimumDisplayDuration: Duration(milliseconds: 250),
          ),
        ),
        GoRoute(
          path: '/tasks',
          builder: (context, state) =>
              const SizedBox(key: ValueKey<String>('startup-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(container, router));
    await _waitForArtworkFrame(tester);
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.byType(StartupPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('startup-destination')),
      findsOneWidget,
    );
  });

  testWidgets(
    'even a zero duration renders one brand frame before navigation',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/startup',
        routes: <RouteBase>[
          GoRoute(
            path: '/startup',
            builder: (context, state) =>
                const StartupPage(minimumDisplayDuration: Duration.zero),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) =>
                const SizedBox(key: ValueKey<String>('startup-destination')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_testApp(container, router));
      expect(
        find.byKey(const ValueKey<String>('startup-brand-composition')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('startup-destination')),
        findsNothing,
      );

      await _waitForArtworkFrame(tester);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('startup-destination')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed artwork decode uses a bounded branded fallback', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/startup',
      routes: <RouteBase>[
        GoRoute(
          path: '/startup',
          builder: (context, state) => const StartupPage(
            minimumDisplayDuration: Duration(milliseconds: 50),
            artworkAsset: 'assets/brand/not-a-real-launch-artwork.png',
            artworkReadyTimeout: Duration(milliseconds: 100),
          ),
        ),
        GoRoute(
          path: '/tasks',
          builder: (context, state) =>
              const SizedBox(key: ValueKey<String>('startup-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(container, router));
    expect(
      find.byKey(const ValueKey<String>('startup-brand-composition')),
      findsOneWidget,
    );
    // Whether the asset bundle reports the missing key immediately or the
    // decoder reaches the explicit 100 ms fail-safe, Startup must still leave
    // after the subsequent 50 ms brand minimum.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('startup-destination')),
      findsOneWidget,
    );
  });

  testWidgets('retry rebuilds the failed upstream database dependency chain', (
    tester,
  ) async {
    var fileAttempts = 0;
    final errorContainer = ProviderContainer(
      overrides: [
        databaseFileProvider.overrideWith((ref) async {
          fileAttempts++;
          if (fileAttempts == 1) {
            throw StateError('fixture support-directory failure');
          }
          return File('fixture-recovered.sqlite');
        }),
        databaseProvider.overrideWith((ref) async {
          await ref.watch(databaseFileProvider.future);
          return database;
        }),
      ],
    );
    addTearDown(errorContainer.dispose);
    final router = GoRouter(
      initialLocation: '/startup',
      routes: <RouteBase>[
        GoRoute(
          path: '/startup',
          builder: (context, state) => const StartupPage(
            minimumDisplayDuration: Duration(milliseconds: 50),
          ),
        ),
        GoRoute(
          path: '/tasks',
          builder: (context, state) =>
              const SizedBox(key: ValueKey<String>('startup-destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_testApp(errorContainer, router));
    await _waitForArtworkFrame(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('startup-destination')),
      findsNothing,
    );
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (fileAttempts < 2) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Retry did not rebuild databaseFileProvider.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await errorContainer.read(appStoreProvider.future);
    });
    expect(errorContainer.read(appStoreProvider).hasValue, isTrue);
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
    final navigationDeadline = DateTime.now().add(const Duration(seconds: 3));
    while (find
        .byKey(const ValueKey<String>('startup-destination'))
        .evaluate()
        .isEmpty) {
      if (DateTime.now().isAfter(navigationDeadline)) {
        throw StateError('Startup did not navigate after successful retry.');
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(fileAttempts, greaterThanOrEqualTo(2));
    expect(find.byType(FilledButton), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('startup-destination')),
      findsOneWidget,
    );
  });
}

Future<void> _waitForArtworkFrame(WidgetTester tester) async {
  final artwork = find.byKey(
    const ValueKey<String>('startup-watercolor-artwork'),
  );
  final context = tester.element(artwork);
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/brand/danggui-launch-artwork.png'),
      context,
    );
  });
  await tester.pump();
  expect(
    find.byKey(const ValueKey<String>('startup-watercolor-decoded-frame')),
    findsOneWidget,
  );
}

Widget _testApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: DangguiTheme.light(),
    ),
  );
}

class _Destination extends StatefulWidget {
  const _Destination({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: ValueKey<String>('startup-destination'));
  }
}
