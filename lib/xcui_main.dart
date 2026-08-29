import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/testing/xcui_scenario_harness.dart';

/// Dedicated entrypoint selected only by the disposable-Simulator CI script.
///
/// The production entrypoint does not import the destructive contract harness,
/// so ordinary Debug/Profile/Release artifacts cannot reach it through launch
/// environment variables. This entrypoint also requires a Debug build and an
/// allow-listed XCUITest launch scenario.
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
  final scenario = Platform.environment['DANGGUI_XCUITEST_SCENARIO'];
  if (!kDebugMode) {
    _showUnavailableHarness('XCUITEST FAIL non-debug harness build');
    return;
  }
  if (scenario == null || scenario.isEmpty) {
    _showUnavailableHarness('XCUITEST FAIL launch scenario unavailable');
    return;
  }
  if (!_supportedXcuiScenarios.contains(scenario)) {
    _showUnavailableHarness('XCUITEST FAIL launch scenario not allow-listed');
    return;
  }
  runDangguiXcuiScenario(scenario);
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
