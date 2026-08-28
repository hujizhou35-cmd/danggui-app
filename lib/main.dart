import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/testing/xcui_scenario_harness.dart';

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
  const xcuiHarnessBuild = bool.fromEnvironment(
    'DANGGUI_XCUITEST_BUILD',
    defaultValue: false,
  );
  if (kDebugMode && xcuiHarnessBuild) {
    final scenario = Platform.environment['DANGGUI_XCUITEST_SCENARIO'];
    if (scenario != null && scenario.isNotEmpty) {
      runDangguiXcuiScenario(scenario);
      return;
    }
  }
  runApp(const ProviderScope(child: DangguiApp()));
}
