import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../application/app_store.dart';
import '../../core/theme/theme.dart';

/// Branded initialization surface shown between the native splash and Tasks.
///
/// [minimumDisplayDuration] is injectable so widget tests can advance a fake
/// clock without slowing down. Production keeps the complete composition on
/// screen for at least 1.2 seconds, even when local initialization is instant.
class StartupPage extends ConsumerStatefulWidget {
  const StartupPage({
    super.key,
    this.minimumDisplayDuration = const Duration(milliseconds: 1200),
    this.artworkAsset = 'assets/brand/danggui-launch-artwork.png',
    this.artworkReadyTimeout = const Duration(seconds: 3),
  });

  final Duration minimumDisplayDuration;
  final String artworkAsset;

  /// A fail-safe for a decoder that neither yields a frame nor reports an
  /// error. Missing/corrupt assets use [Image.errorBuilder] and start the
  /// branded fallback clock immediately; this timeout prevents an unusual
  /// image pipeline stall from trapping users on Startup forever.
  final Duration artworkReadyTimeout;

  @override
  ConsumerState<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends ConsumerState<StartupPage> {
  Timer? _minimumDisplayTimer;
  Timer? _artworkReadyFallbackTimer;
  var _minimumDisplayElapsed = false;
  var _minimumDisplayClockStarted = false;
  var _artworkFrameCallbackQueued = false;
  var _navigationQueued = false;

  @override
  void initState() {
    super.initState();
    // The image frameBuilder normally starts the display clock. Keep a bounded
    // fallback in case a platform decoder neither yields a frame nor reports
    // an error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _minimumDisplayClockStarted) return;
      if (widget.artworkReadyTimeout <= Duration.zero) {
        _startMinimumDisplayClock();
        return;
      }
      _artworkReadyFallbackTimer = Timer(
        widget.artworkReadyTimeout,
        _startMinimumDisplayClock,
      );
    });
  }

  @override
  void dispose() {
    _minimumDisplayTimer?.cancel();
    _artworkReadyFallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appStoreProvider);
    _queueNavigationWhenReady(bootstrap);

    final l10n = AppLocalizations.of(context);
    final tokens = context.dangguiTheme;
    return Scaffold(
      backgroundColor: tokens.paper,
      body: Stack(
        key: const ValueKey<String>('startup-brand-composition'),
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            widget.artworkAsset,
            key: const ValueKey<String>('startup-watercolor-artwork'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                _queueArtworkFrameReady();
                return KeyedSubtree(
                  key: const ValueKey<String>(
                    'startup-watercolor-decoded-frame',
                  ),
                  child: child,
                );
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _queueArtworkFrameReady();
              return ColoredBox(
                key: const ValueKey<String>(
                  'startup-watercolor-error-fallback',
                ),
                color: tokens.paper,
              );
            },
          ),
          SafeArea(
            child: bootstrap.hasError
                ? Align(
                    alignment: const Alignment(0, .78),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _StartupError(
                        title: l10n.bootstrapError,
                        retryLabel: l10n.retry,
                        onRetry: _retryBootstrap,
                      ),
                    ),
                  )
                : _StartupBrand(
                    appName: l10n.appName,
                    privacyTagline: l10n.privacyTagline,
                    loadingLabel: l10n.loading,
                  ),
          ),
        ],
      ),
    );
  }

  void _retryBootstrap() {
    // AppStore's initialization error may be cached by either provider above
    // it (support-directory discovery or database open/quick-check). Reset the
    // complete dependency chain so Retry performs a genuinely fresh attempt.
    // Both downstream providers watch this source, so invalidating it rebuilds
    // the database and AppStore exactly once without racing duplicate opens.
    ref.invalidate(databaseFileProvider);
  }

  void _queueNavigationWhenReady(AsyncValue<Object?> bootstrap) {
    if (_navigationQueued ||
        !_minimumDisplayElapsed ||
        bootstrap.isLoading ||
        bootstrap.hasError ||
        !bootstrap.hasValue) {
      return;
    }
    _navigationQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/tasks');
    });
  }

  void _startMinimumDisplayClock() {
    if (!mounted || _minimumDisplayClockStarted) return;
    _artworkReadyFallbackTimer?.cancel();
    _minimumDisplayClockStarted = true;
    if (widget.minimumDisplayDuration <= Duration.zero) {
      setState(() => _minimumDisplayElapsed = true);
      return;
    }
    _minimumDisplayTimer = Timer(widget.minimumDisplayDuration, () {
      if (!mounted) return;
      setState(() => _minimumDisplayElapsed = true);
    });
  }

  void _queueArtworkFrameReady() {
    if (_minimumDisplayClockStarted || _artworkFrameCallbackQueued) return;
    _artworkFrameCallbackQueued = true;
    // frameBuilder runs while the image subtree is being built. Waiting for
    // the end of that frame means the minimum duration begins only after the
    // decoded artwork (or the visible error fallback) has reached the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _artworkFrameCallbackQueued = false;
      _startMinimumDisplayClock();
    });
  }
}

class _StartupBrand extends StatelessWidget {
  const _StartupBrand({
    required this.appName,
    required this.privacyTagline,
    required this.loadingLabel,
  });

  final String appName;
  final String privacyTagline;
  final String loadingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.dangguiTheme;
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < 700;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              key: const ValueKey<String>('startup-brand-title'),
              top: height * (compact ? .57 : .655),
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        appName,
                        style: textTheme.displaySmall?.copyWith(
                          color: tokens.sage,
                          fontFamily: 'DangguiDisplay',
                          fontSize: compact ? 42 : 50,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          letterSpacing: 7,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: _BrandSeal(),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 18),
                  _BotanicalDivider(compact: compact),
                ],
              ),
            ),
            Positioned(
              key: const ValueKey<String>('startup-privacy-tagline'),
              top: height * (compact ? .75 : .79),
              left: 28,
              right: 28,
              child: Text(
                privacyTagline,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: tokens.muted,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Positioned(
              key: const ValueKey<String>('startup-loading-status'),
              top: height * (compact ? .83 : .865),
              left: 28,
              right: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: compact ? 26 : 32,
                    height: compact ? 26 : 32,
                    child: CircularProgressIndicator(
                      key: const ValueKey<String>('startup-progress'),
                      strokeWidth: 3,
                      color: tokens.sage,
                      backgroundColor: tokens.sageSoft,
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 16),
                  Text(
                    loadingLabel,
                    textAlign: TextAlign.center,
                    style: textTheme.labelLarge?.copyWith(
                      color: tokens.muted,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BrandSeal extends StatelessWidget {
  const _BrandSeal();

  @override
  Widget build(BuildContext context) {
    final terracotta = context.dangguiTheme.terra;
    return Semantics(
      label: '当归印章',
      image: true,
      child: Container(
        width: 25,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: terracotta,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: terracotta, width: 1.5),
        ),
        child: const Text(
          '当\n归',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w600,
            height: .95,
          ),
        ),
      ),
    );
  }
}

class _BotanicalDivider extends StatelessWidget {
  const _BotanicalDivider({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = context.dangguiTheme.sage.withValues(alpha: .52);
    return SizedBox(
      width: compact ? 230 : 280,
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: color, height: 1)),
          const SizedBox(width: 10),
          Icon(Icons.eco_outlined, size: compact ? 16 : 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: color, height: 1)),
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
