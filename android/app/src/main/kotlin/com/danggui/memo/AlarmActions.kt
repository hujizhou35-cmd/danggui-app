package com.danggui.memo

import android.content.Context
import android.content.Intent
import android.os.Build

internal object AlarmActions {
    const val ACTION_STOP = "com.danggui.memo.action.STOP_ALARM"
    const val ACTION_SNOOZE = "com.danggui.memo.action.SNOOZE_ALARM"
    const val ACTION_SESSION_CHANGED = "com.danggui.memo.action.ALARM_SESSION_CHANGED"
    const val EXTRA_REMINDER_ID = "reminderId"
    const val EXTRA_SNOOZE_MINUTES = "snoozeMinutes"

    fun stop(context: Context, reminderId: String? = null): Int {
        val store = AlarmStore(context)
        val targets = targets(store, reminderId)
        var stoppedCount = 0
        targets.forEach { record ->
            if (store.removeRingingAndAppendStopped(record) != null) stoppedCount += 1
        }
        refreshSession(context, store)
        return stoppedCount
    }

    fun snooze(context: Context, reminderId: String? = null, minutes: Int): Int {
        val store = AlarmStore(context)
        val targets = targets(store, reminderId)
        val safeMinutes = minutes.coerceIn(1, 24 * 60)
        val nextTriggerAtEpochMs = System.currentTimeMillis() + safeMinutes * 60_000L
        var scheduledCount = 0
        targets.forEach { record ->
            val next =
                record.copy(
                    scheduleRevision = record.scheduleRevision + 1,
                    triggerAtEpochMs = nextTriggerAtEpochMs,
                    defaultSnoozeMinutes = safeMinutes,
                    state = AlarmRecord.STATE_SCHEDULED,
                )
            val snoozedEvent =
                AlarmEvent(
                    reminderId = record.reminderId,
                    taskId = record.taskId,
                    scheduleRevision = record.scheduleRevision,
                    type = "snoozed",
                    snoozeMinutes = safeMinutes,
                    nextTriggerAtEpochMs = nextTriggerAtEpochMs,
                )
            val scheduled =
                AlarmScheduler(context).scheduleSnooze(
                    ringingRecord = record,
                    snoozedRecord = next,
                    snoozedEvent = snoozedEvent,
                )
            if (scheduled) {
                scheduledCount += 1
            } else {
                store.removeRingingAndAppendStopped(record)
            }
        }
        refreshSession(context, store)
        return scheduledCount
    }

    private fun targets(store: AlarmStore, reminderId: String?): List<AlarmRecord> {
        val ringing = store.ringing()
        return if (reminderId == null) ringing else ringing.filter { it.reminderId == reminderId }
    }

    fun refreshSession(context: Context, store: AlarmStore = AlarmStore(context)) {
        context.sendBroadcast(
            Intent(ACTION_SESSION_CHANGED).apply {
                setPackage(context.packageName)
            },
        )
        if (store.ringing().isEmpty()) {
            context.stopService(Intent(context, AlarmRingingService::class.java))
            return
        }
        val refreshIntent =
            Intent(context, AlarmRingingService::class.java).apply {
                action = AlarmRingingService.ACTION_REFRESH
            }
        val serviceStarted =
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(refreshIntent)
                } else {
                    context.startService(refreshIntent)
                }
            }.getOrNull() != null
        if (!serviceStarted) {
            store.ringing().forEach { store.removeRingingAndAppendStopped(it) }
        }
    }
}
