package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

/** Android 7/7.1 wakeful delivery plus compatibility for v1.1.3 registrations. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_FIRE_ALARM) return
        val reminderId = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_ID) ?: return
        val scheduleRevision =
            intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, Long.MIN_VALUE)
        if (scheduleRevision == Long.MIN_VALUE) return
        val rawDeviceGeneration =
            intent.getStringExtra(AlarmScheduler.EXTRA_DEVICE_GENERATION)
        val deviceGeneration = rawDeviceGeneration?.let {
            AlarmIdentityPolicy.canonicalDeviceGeneration(it) ?: return
        }
        val store = AlarmStore(context.applicationContext)
        if (!store.isActiveDeviceGeneration(deviceGeneration)) return

        val pendingResult = goAsync()
        val applicationContext = context.applicationContext
        val powerManager = applicationContext.getSystemService(PowerManager::class.java)
        powerManager
            .newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "${applicationContext.packageName}:alarm-handoff",
            )
            .apply {
                setReferenceCounted(false)
                // The service takes its own bounded lock. Keeping this lock until its timeout
                // closes the BroadcastReceiver -> service CPU sleep gap.
                acquire(HANDOFF_TIMEOUT_MILLIS)
            }

        try {
            val serviceIntent =
                Intent(applicationContext, AlarmRingingService::class.java).apply {
                    action = AlarmRingingService.ACTION_FIRE
                    data =
                        AlarmScheduler.alarmIdentityUri(
                            reminderId,
                            scheduleRevision,
                            deviceGeneration,
                        )
                    putExtra(AlarmScheduler.EXTRA_REMINDER_ID, reminderId)
                    putExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, scheduleRevision)
                    deviceGeneration?.let {
                        putExtra(AlarmScheduler.EXTRA_DEVICE_GENERATION, it)
                    }
                }
            val started =
                runCatching {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        applicationContext.startForegroundService(serviceIntent)
                    } else {
                        applicationContext.startService(serviceIntent)
                    }
                }.getOrNull() != null
            if (!started) {
                store.get(reminderId, scheduleRevision, deviceGeneration)
                    ?.let { record ->
                        store.appendEvent(
                            AlarmEvent(
                                reminderId = record.reminderId,
                                taskId = record.taskId,
                                scheduleRevision = record.scheduleRevision,
                                deviceGeneration = record.deviceGeneration,
                                type = "error",
                                detailCode = "service_handoff_failed",
                            ),
                        )
                    }
            }
        } finally {
            pendingResult.finish()
        }
    }

    companion object {
        private const val HANDOFF_TIMEOUT_MILLIS = 20_000L
    }
}
