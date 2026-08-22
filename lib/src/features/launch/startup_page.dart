import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_store.dart';
import '../../core/theme/theme.dart';

class StartupPage extends ConsumerWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appStoreProvider);
    if (bootstrap.hasValue && !bootstrap.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/tasks');
      });
    }
    final l10n = AppLocalizations.of(context);
    final tokens = context.dangguiTheme;
    return Scaffold(
      backgroundColor: tokens.paper,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/brand/danggui-launch-artwork.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: Align(
              alignment: const Alignment(0, .76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: bootstrap.hasError
                    ? _StartupError(
                        title: l10n.bootstrapError,
                        retryLabel: l10n.retry,
                        onRetry: () => ref.invalidate(appStoreProvider),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            l10n.appName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: 43, color: tokens.sage),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.privacyTagline,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: tokens.muted),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: tokens.sage,
                              backgroundColor: tokens.sageSoft,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.loading,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.title,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
