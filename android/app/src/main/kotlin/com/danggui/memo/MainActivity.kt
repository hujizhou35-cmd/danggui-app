package com.danggui.memo

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.danggui.memo/reminder_platform",
        ).setMethodCallHandler(ReminderPlatformHandler(this))

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.danggui.memo/settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val notificationIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            val fallbackIntent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            )
            try {
                startActivity(notificationIntent)
                result.success(null)
            } catch (_: Exception) {
                try {
                    startActivity(fallbackIntent)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("settings_unavailable", error.message, null)
                }
            }
        }
    }
}
