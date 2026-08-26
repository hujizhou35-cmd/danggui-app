package com.danggui.memo

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class ReminderPlatformHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val store = AlarmStore(activity)
    private val scheduler = AlarmScheduler(activity)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> result.success(getCapabilities())
            "requestExactAlarmPermission" -> result.success(requestExactAlarmPermission())
            "requestFullScreenPermission" -> result.success(requestFullScreenPermission())
            "openNotificationSettings" -> openNotificationSettings(result)
            "openAlarmSoundSettings" -> openAlarmSoundSettings(result)
            "openOemAutostartSettings" ->
                result.success(OemSettingsLauncher(activity).open().opened)
            "scheduleAlarm" -> scheduleAlarm(call.arguments, result)
            "cancelAlarm" -> cancelAlarm(call.arguments, result)
            "stopAlarm" -> stopAlarm(call.arguments, result)
            "snoozeAlarm" -> snoozeAlarm(call.arguments, result)
            "listScheduledAlarms" -> result.success(listActiveAlarms())
            "listAlarmSnapshots" -> result.success(listActiveAlarms())
            "drainAlarmEvents" -> {
                reconcileStoredAlarms()
                result.success(store.events().map(AlarmEvent::toMap))
            }
            "ackAlarmEvents" -> acknowledgeAlarmEvents(call.arguments, result)
            "scheduleTestAlarm" -> scheduleTestAlarm(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    private fun getCapabilities(): Map<String, Any> {
        reconcileStoredAlarms()
        ensureRingingService()
        val notificationManager = activity.getSystemService(NotificationManager::class.java)
        val channel = AlarmChannels.ensureRingingChannel(activity)
        val audioManager = activity.getSystemService(AudioManager::class.java)
        val powerManager = activity.getSystemService(PowerManager::class.java)
        val notificationPermissionGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        val fullScreenAllowed =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                notificationManager.canUseFullScreenIntent()
        val exactAlarmAllowed = scheduler.canScheduleExactAlarms()
        val oemLauncher = OemSettingsLauncher(activity)
        val alarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        val maxAlarmVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val notificationsEnabled = notificationManager.areNotificationsEnabled()
        val alarmChannelImportance =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                channel?.importance ?: NotificationManager.IMPORTANCE_HIGH
            } else {
                NotificationManager.IMPORTANCE_HIGH
            }
        val alarmChannelEnabled =
            alarmChannelImportance != NotificationManager.IMPORTANCE_NONE
        val capabilityLevel =
            when {
                exactAlarmAllowed &&
                    notificationPermissionGranted &&
                    notificationsEnabled &&
                    alarmChannelEnabled -> "alarm-grade"
                notificationPermissionGranted && notificationsEnabled ->
                    "time-sensitive-best-effort"
                notificationsEnabled -> "ordinary"
                else -> "unavailable"
            }
        return mapOf(
            "platform" to "android",
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "notificationsEnabled" to notificationsEnabled,
            "notificationPermissionGranted" to notificationPermissionGranted,
            "exactAlarmAllowed" to exactAlarmAllowed,
            "fullScreenAllowed" to fullScreenAllowed,
            "alarmChannelEnabled" to alarmChannelEnabled,
            "alarmChannelImportance" to alarmChannelImportance,
            "alarmVolume" to alarmVolume,
            "alarmMaxVolume" to maxAlarmVolume,
            "alarmVolumeAudible" to (alarmVolume > 0),
            "batteryOptimizationIgnored" to
                powerManager.isIgnoringBatteryOptimizations(activity.packageName),
            "oemAutostartSettingsAvailable" to oemLauncher.hasDedicatedTarget(),
            "oemSetupAvailable" to oemLauncher.hasDedicatedTarget(),
            "oemSettingsAvailable" to oemLauncher.hasDedicatedTarget(),
            "oemSettingsRequireManualConfirmation" to true,
            "scheduledAlarmCount" to store.scheduled().size,
            "ringingAlarmCount" to store.ringing().size,
            "canScheduleStrongAlarm" to exactAlarmAllowed,
            "capabilityLevel" to capabilityLevel,
        )
    }

    private fun listActiveAlarms(): List<Map<String, Any>> {
        reconcileStoredAlarms()
        ensureRingingService()
        return (store.scheduled() + store.ringing())
            .distinctBy(AlarmRecord::reminderId)
            .sortedBy(AlarmRecord::triggerAtEpochMs)
            .map(AlarmRecord::toMap)
    }

    private fun reconcileStoredAlarms() {
        scheduler.reconcileStoredAlarms()
    }

    private fun ensureRingingService() {
        if (store.ringing().isEmpty()) return
        val intent =
            Intent(activity, AlarmRingingService::class.java).apply {
                action = AlarmRingingService.ACTION_REFRESH
            }
        val serviceStarted = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.startForegroundService(intent)
            } else {
                activity.startService(intent)
            }
        }.getOrNull() != null
        if (!serviceStarted) {
            store.ringing().forEach { record ->
                store.appendEvent(
                    AlarmEvent(
                        reminderId = record.reminderId,
                        taskId = record.taskId,
                        scheduleRevision = record.scheduleRevision,
                        type = "error",
                        sessionId = record.sessionId,
                        detailCode = "ringing_service_recovery_failed",
                    ),
                )
            }
        }
    }

    private fun requestExactAlarmPermission(): Boolean {
        if (scheduler.canScheduleExactAlarms()) return true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val primary =
            Intent(
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:${activity.packageName}"),
            )
        startSettings(primary)
        return false
    }

    private fun requestFullScreenPermission(): Boolean {
        val notificationManager = activity.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return true
        }
        if (notificationManager.canUseFullScreenIntent()) {
            return true
        }
        val intent =
            Intent(
                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                Uri.parse("package:${activity.packageName}"),
            )
        startSettings(intent)
        return false
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        AlarmChannels.ensureRingingChannel(activity)
        val intent =
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, AlarmRingingService.CHANNEL_ID)
            }
        if (startSettings(intent)) {
            result.success(null)
        } else {
            result.error("settings_unavailable", "Unable to open notification settings", null)
        }
    }

    private fun openAlarmSoundSettings(result: MethodChannel.Result) {
        if (startSettings(Intent(Settings.ACTION_SOUND_SETTINGS))) {
            result.success(null)
        } else {
            result.error("settings_unavailable", "Unable to open alarm sound settings", null)
        }
    }

    private fun scheduleAlarm(arguments: Any?, result: MethodChannel.Result) {
        val argumentsMap = arguments.asArguments(result) ?: return
        val record = parseRecord(argumentsMap, result) ?: return
        val scheduled = scheduler.schedule(record)
        completeScheduleResult(scheduled, result)
    }

    private fun cancelAlarm(arguments: Any?, result: MethodChannel.Result) {
        val argumentsMap = arguments.asArguments(result) ?: return
        val reminderId = argumentsMap.requiredString("reminderId", result) ?: return
        completeScheduleResult(scheduler.cancel(reminderId).result, result)
    }

    private fun stopAlarm(arguments: Any?, result: MethodChannel.Result) {
        val argumentsMap = arguments.asArguments(result) ?: return
        val reminderId = (argumentsMap["reminderId"] as? String)?.trim()?.takeIf(String::isNotEmpty)
        val scheduleRevision =
            ((argumentsMap["scheduleRevision"] ?: argumentsMap["revision"]) as? Number)?.toLong()
        val sessionId = (argumentsMap["sessionId"] as? String)?.trim()?.takeIf(String::isNotEmpty)
        if (!AlarmIdentityPolicy.hasCompleteCurrentIdentity(reminderId, scheduleRevision, sessionId)) {
            result.error(
                "invalid_alarm_identity",
                "reminderId, scheduleRevision, and sessionId are required",
                null,
            )
            return
        }
        val outcome =
            AlarmActions.stop(
                activity,
                requireNotNull(reminderId),
                requireNotNull(scheduleRevision),
                requireNotNull(sessionId),
            )
        completeScheduleResult(outcome.result, result)
    }

    private fun snoozeAlarm(arguments: Any?, result: MethodChannel.Result) {
        val argumentsMap = arguments.asArguments(result) ?: return
        val reminderId = (argumentsMap["reminderId"] as? String)?.trim()?.takeIf(String::isNotEmpty)
        val scheduleRevision =
            ((argumentsMap["scheduleRevision"] ?: argumentsMap["revision"]) as? Number)?.toLong()
        val sessionId = (argumentsMap["sessionId"] as? String)?.trim()?.takeIf(String::isNotEmpty)
        if (!AlarmIdentityPolicy.hasCompleteCurrentIdentity(reminderId, scheduleRevision, sessionId)) {
            result.error(
                "invalid_alarm_identity",
                "reminderId, scheduleRevision, and sessionId are required",
                null,
            )
            return
        }
        val minutes = (argumentsMap["minutes"] as? Number)?.toInt() ?: 10
        val outcome =
            AlarmActions.snooze(
                context = activity,
                reminderId = requireNotNull(reminderId),
                scheduleRevision = requireNotNull(scheduleRevision),
                sessionId = requireNotNull(sessionId),
                minutes = minutes,
            )
        completeScheduleResult(outcome.result, result)
    }

    private fun acknowledgeAlarmEvents(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val rawIds = values?.get("eventIds") as? List<*>
        val eventIds = rawIds
            ?.mapNotNull { (it as? String)?.takeIf(String::isNotBlank) }
            ?.toSet()
            .orEmpty()
        store.acknowledgeEvents(eventIds)
        result.success(null)
    }

    private fun scheduleTestAlarm(arguments: Any?, result: MethodChannel.Result) {
        val argumentsMap = arguments.asOptionalArguments(result) ?: return
        val delaySeconds = ((argumentsMap["delaySeconds"] as? Number)?.toLong() ?: 15L)
            .coerceIn(5L, 3_600L)
        val now = System.currentTimeMillis()
        val record =
            AlarmRecord(
                reminderId = "__danggui_test_alarm_$now",
                taskId = "__danggui_test_alarm",
                scheduleRevision = now,
                triggerAtEpochMs = now + delaySeconds * 1_000L,
                title = (argumentsMap["title"] as? String)?.trim().orEmpty().ifBlank {
                    activity.getString(R.string.alarm_test_title)
                },
                body = (argumentsMap["body"] as? String)?.trim().orEmpty().ifBlank {
                    activity.getString(R.string.alarm_test_body)
                },
                localeTag =
                    (argumentsMap["localeTag"] as? String)?.trim().orEmpty().ifBlank {
                        activity.resources.configuration.locales[0].toLanguageTag()
                    },
                vibrationEnabled = argumentsMap["vibrationEnabled"] as? Boolean ?: true,
                defaultSnoozeMinutes = 10,
            )
        val scheduled = scheduler.schedule(record)
        if (scheduled == AlarmScheduleResult.SUCCESS) {
            result.success(null)
        } else {
            completeScheduleResult(scheduled, result)
        }
    }

    private fun parseRecord(
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ): AlarmRecord? {
        val reminderId = arguments.requiredString("reminderId", result) ?: return null
        val taskId = arguments.requiredString("taskId", result) ?: return null
        val scheduleRevision = arguments.requiredLong("scheduleRevision", result) ?: return null
        val triggerAtEpochMs = arguments.requiredLong("triggerAtEpochMs", result) ?: return null
        if (triggerAtEpochMs <= System.currentTimeMillis()) {
            result.error("invalid_trigger_time", "triggerAtEpochMs must be in the future", null)
            return null
        }
        return AlarmRecord(
            reminderId = reminderId,
            taskId = taskId,
            scheduleRevision = scheduleRevision,
            triggerAtEpochMs = triggerAtEpochMs,
            title = (arguments["title"] as? String)?.trim().orEmpty(),
            body = (arguments["body"] as? String)?.trim().orEmpty(),
            localeTag =
                (arguments["localeTag"] as? String)?.trim().orEmpty().ifBlank {
                    activity.resources.configuration.locales[0].toLanguageTag()
                },
            vibrationEnabled = arguments["vibrationEnabled"] as? Boolean ?: true,
            defaultSnoozeMinutes =
                ((arguments["defaultSnoozeMinutes"] as? Number)?.toInt() ?: 10)
                    .coerceIn(1, 24 * 60),
        )
    }

    private fun startSettings(intent: Intent): Boolean {
        val fallback =
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}"),
            )
        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                activity.startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun completeScheduleResult(
        scheduleResult: AlarmScheduleResult,
        result: MethodChannel.Result,
    ) {
        if (scheduleResult == AlarmScheduleResult.SUCCESS) {
            result.success(null)
            return
        }
        result.error(
            scheduleResult.errorCode ?: "alarm_operation_failed",
            when (scheduleResult) {
                AlarmScheduleResult.INVALID_TRIGGER_TIME -> "The alarm trigger time must be in the future."
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED ->
                    "Exact alarm access is required before scheduling a strong alarm."
                AlarmScheduleResult.STALE_SCHEDULE_REVISION ->
                    "The alarm revision or ringing session is no longer current."
                AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED,
                AlarmScheduleResult.DURABLE_COMMIT_FAILED ->
                    "The alarm could not be committed to durable storage."
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED ->
                    "Android rejected the alarm installation."
                AlarmScheduleResult.SYSTEM_ALARM_CANCEL_FAILED ->
                    "Android rejected the alarm cancellation; the durable tombstone was retained."
                AlarmScheduleResult.SUCCESS -> ""
            },
            mapOf("status" to scheduleResult.name.lowercase()),
        )
    }

    private fun Any?.asArguments(result: MethodChannel.Result): Map<*, *>? {
        val arguments = this as? Map<*, *>
        if (arguments == null) result.error("invalid_arguments", "Expected a map of arguments", null)
        return arguments
    }

    private fun Any?.asOptionalArguments(result: MethodChannel.Result): Map<*, *>? {
        if (this == null) return emptyMap<Any, Any>()
        return asArguments(result)
    }

    private fun Map<*, *>.requiredString(name: String, result: MethodChannel.Result): String? {
        val value = (this[name] as? String)?.trim()
        if (value.isNullOrEmpty()) result.error("invalid_arguments", "$name is required", null)
        return value?.takeIf(String::isNotEmpty)
    }

    private fun Map<*, *>.requiredLong(name: String, result: MethodChannel.Result): Long? {
        val value = (this[name] as? Number)?.toLong()
        if (value == null) result.error("invalid_arguments", "$name is required", null)
        return value
    }
}
