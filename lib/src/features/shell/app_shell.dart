import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../ui/components/components.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imeVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      // The keyboard already occupies the shell navigation area. Removing the
      // bar while the IME is visible lets shell-hosted editors consume the
      // whole height before their EditorPageFrame applies the keyboard inset;
      // otherwise the 77dp navigation height would be subtracted twice.
      bottomNavigationBar: imeVisible
          ? null
          : DangguiBottomNav(
              key: const Key('app-shell-bottom-navigation'),
              currentIndex: navigationShell.currentIndex,
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: <DangguiNavigationDestination>[
                DangguiNavigationDestination(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  selectedIcon: const Icon(Icons.check_circle_rounded),
                  label: l10n.tasksTab,
                ),
                DangguiNavigationDestination(
                  icon: const Icon(Icons.history_edu_outlined),
                  selectedIcon: const Icon(Icons.history_edu_rounded),
                  label: l10n.pastTab,
                ),
                DangguiNavigationDestination(
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  selectedIcon: const Icon(Icons.sticky_note_2_rounded),
                  label: l10n.notesTab,
                ),
                DangguiNavigationDestination(
                  icon: const Icon(Icons.tune_rounded),
                  selectedIcon: const Icon(Icons.tune_rounded),
                  label: l10n.settingsTab,
                ),
              ],
            ),
    );
  }
}
