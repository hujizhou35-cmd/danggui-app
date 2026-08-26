package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager

/** Compatibility handoff for alarms registered by v1.1.3 and earlier. */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_FIRE_ALARM) return
        val reminderId = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_ID) ?: return
        val scheduleRevision =
            intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, Long.MIN_VALUE)
        if (scheduleRevision == Long.MIN_VALUE) return

        val pendingResult = goAsync()
        val applicationContext = context.applicationContext
        val powerManager = applicationContext.getSystemService(PowerManager::class.java)
        powerManager
            .newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "${applicationContext.packageName}:legacy-alarm-handoff",
            )
            .apply {
                setReferenceCounted(false)
                // The service takes its own bounded lock. Keeping this lock until its timeout
                // closes the old BroadcastReceiver -> foreground-service CPU sleep gap.
                acquire(LEGACY_HANDOFF_TIMEOUT_MILLIS)
            }

        try {
            val serviceIntent =
                Intent(applicationContext, AlarmRingingService::class.java).apply {
                    action = AlarmRingingService.ACTION_FIRE
                    data = AlarmScheduler.alarmIdentityUri(reminderId, scheduleRevision)
                    putExtra(AlarmScheduler.EXTRA_REMINDER_ID, reminderId)
                    putExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, scheduleRevision)
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
                AlarmStore(applicationContext).get(reminderId, scheduleRevision)?.let { record ->
                    AlarmStore(applicationContext).appendEvent(
                        AlarmEvent(
                            reminderId = record.reminderId,
                            taskId = record.taskId,
                            scheduleRevision = record.scheduleRevision,
                            type = "error",
                            detailCode = "legacy_service_handoff_failed",
                        ),
                    )
                }
            }
        } finally {
            pendingResult.finish()
        }
    }

    companion object {
        private const val LEGACY_HANDOFF_TIMEOUT_MILLIS = 20_000L
    }
}
