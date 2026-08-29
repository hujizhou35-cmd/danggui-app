import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/testing/xcui_scenario_harness.dart';

/// Dedicated entrypoint selected only by the disposable-Simulator CI script.
///
/// The production entrypoint does not import the destructive contract harness,
/// so ordinary Debug/Profile/Release artifacts cannot select or reach its
/// scenario controls. This entrypoint also requires a Debug build and exposes
/// only the two allow-listed XCUITest scenarios.
const _supportedXcuiScenarios = <String>{
  'task-reminder-trash-restore',
  'backup-restore-reminder-rebuild',
};

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF4EFE7),
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0xFFD8CEC1),
    ),
  );
  if (!kDebugMode) {
    _showUnavailableHarness('XCUITEST FAIL non-debug harness build');
    return;
  }
  runApp(DangguiXcuiScenarioSelectorApp(onSelected: runDangguiXcuiScenario));
}

@visibleForTesting
class DangguiXcuiScenarioSelectorApp extends StatelessWidget {
  const DangguiXcuiScenarioSelectorApp({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final scenario in _supportedXcuiScenarios)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Semantics(
                  key: ValueKey<String>('xcui-scenario-$scenario'),
                  identifier: 'xcui-scenario-$scenario',
                  excludeSemantics: true,
                  button: true,
                  enabled: true,
                  label: 'Run $scenario',
                  onTap: () => onSelected(scenario),
                  child: FilledButton(
                    onPressed: () => onSelected(scenario),
                    child: Text(scenario),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showUnavailableHarness(String reason) =>
    runApp(_UnavailableHarnessApp(reason: reason));

class _UnavailableHarnessApp extends StatelessWidget {
  const _UnavailableHarnessApp({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Semantics(
          identifier: 'xcui-scenario-result',
          label: reason,
          child: Text(reason),
        ),
      ),
    ),
  );
}
