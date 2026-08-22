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
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DangguiBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
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
