import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/testing/xcui_scenario_harness.dart';

/// Dedicated entrypoint selected only by the disposable-Simulator CI script.
///
/// The production entrypoint does not import the destructive contract harness,
/// so ordinary Debug/Profile/Release artifacts cannot reach it through launch
/// environment variables. This entrypoint also requires a compile-time opt-in
/// and a Debug build before it accepts an XCUITest scenario.
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
  const harnessBuild = bool.fromEnvironment(
    'DANGGUI_XCUITEST_BUILD',
    defaultValue: false,
  );
  final scenario = Platform.environment['DANGGUI_XCUITEST_SCENARIO'];
  if (kDebugMode && harnessBuild && scenario != null && scenario.isNotEmpty) {
    runDangguiXcuiScenario(scenario);
    return;
  }
  runApp(
    const _UnavailableHarnessApp(
      reason: 'XCUITEST FAIL harness build gate unavailable',
    ),
  );
}

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
