package com.danggui.memo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build

internal class AlarmScheduler(context: Context) {
    private val context = context.applicationContext
    private val alarmManager = this.context.getSystemService(AlarmManager::class.java)
    private val store = AlarmStore(this.context)

    fun canScheduleExactAlarms(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()

    fun schedule(record: AlarmRecord): Boolean = synchronized(schedulerLock) {
        if (record.triggerAtEpochMs <= System.currentTimeMillis()) return false
        if (!canScheduleExactAlarms()) return false

        val scheduledRecord = record.copy(state = AlarmRecord.STATE_SCHEDULED)
        val previousRecord = store.get(record.reminderId)
        // Persist first: a fired PendingIntent must never point at a missing mirror record.
        if (!store.put(scheduledRecord)) return false

        if (installSystemAlarm(scheduledRecord)) return true
        store.restoreIfCurrent(scheduledRecord, previousRecord)
        false
    }

    fun scheduleSnooze(
        ringingRecord: AlarmRecord,
        snoozedRecord: AlarmRecord,
        snoozedEvent: AlarmEvent,
    ): Boolean = synchronized(schedulerLock) {
        if (snoozedRecord.triggerAtEpochMs <= System.currentTimeMillis()) return false
        if (!canScheduleExactAlarms()) return false
        if (
            !store.replaceRingingAndAppendEvent(
                expected = ringingRecord,
                replacement = snoozedRecord,
                event = snoozedEvent,
            )
        ) {
            return false
        }
        if (installSystemAlarm(snoozedRecord)) return true

        store.rollbackReplacementAndEvent(
            expectedReplacement = snoozedRecord,
            previous = ringingRecord,
            eventId = snoozedEvent.eventId,
        )
        false
    }

    fun cancel(reminderId: String): AlarmRecord? = synchronized(schedulerLock) {
        cancelSystemAlarm(reminderId)
        store.remove(reminderId)
    }

    fun cancelSystemAlarm(reminderId: String): Unit = synchronized(schedulerLock) {
        alarmManager.cancel(firePendingIntent(reminderId, 0L))
    }

    /**
     * Reinstalls already-durable alarms without rewriting the JSON store once per alarm.
     * This path is used by boot/time/package receivers, where synchronous O(N²) I/O can
     * otherwise exceed the broadcast execution window.
     */
    fun rescheduleAll(): Unit = synchronized(schedulerLock) {
        reconcileStoredAlarms()
        if (!canScheduleExactAlarms()) return

        val now = System.currentTimeMillis()
        val failed = mutableListOf<AlarmRecord>()
        store.scheduled().forEach { record ->
            // A Flutter schedule/cancel/snooze sequence uses the same process lock. The
            // store check also rejects snapshots changed by a firing receiver.
            if (store.get(record.reminderId) != record) return@forEach
            val installed =
                // A reboot or package replacement may have occurred just after the due time.
                // Re-arm records still inside the grace window for prompt delivery.
                installSystemAlarm(
                    record,
                    triggerAtEpochMs = maxOf(record.triggerAtEpochMs, now + 1_000L),
                )
            if (!installed) failed += record
        }
        if (!canScheduleExactAlarms()) {
            reconcileStoredAlarms()
            return
        }
        if (failed.isNotEmpty()) {
            store.removeScheduled(failed.map { it.reminderId to it.scheduleRevision }.toSet())
        }
    }

    fun reconcileStoredAlarms(now: Long = System.currentTimeMillis()): Unit =
        synchronized(schedulerLock) {
            val reconciliation =
                store.reconcileScheduledAlarms(
                    now = now,
                    missedAlarmGraceMillis = MISSED_ALARM_GRACE_MILLIS,
                    exactAlarmAllowed = canScheduleExactAlarms(),
                )
            reconciliation.removed.forEach { cancelSystemAlarm(it.reminderId) }
        }

    private fun installSystemAlarm(
        record: AlarmRecord,
        triggerAtEpochMs: Long = record.triggerAtEpochMs,
    ): Boolean {
        if (!canScheduleExactAlarms()) return false
        val operation = firePendingIntent(record)
        val showIntent =
            PendingIntent.getActivity(
                context,
                SHOW_ALARM_REQUEST_CODE,
                Intent(context, MainActivity::class.java).apply {
                    action = ACTION_SHOW_ALARMS
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        return try {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtEpochMs, showIntent),
                operation,
            )
            true
        } catch (_: SecurityException) {
            false
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    private fun firePendingIntent(record: AlarmRecord): PendingIntent =
        firePendingIntent(record.reminderId, record.scheduleRevision)

    private fun firePendingIntent(reminderId: String, scheduleRevision: Long): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            FIRE_ALARM_REQUEST_CODE,
            Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_FIRE_ALARM
                data = Uri.Builder().scheme("danggui").authority("alarm").appendPath(reminderId).build()
                putExtra(EXTRA_REMINDER_ID, reminderId)
                putExtra(EXTRA_SCHEDULE_REVISION, scheduleRevision)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val ACTION_FIRE_ALARM = "com.danggui.memo.action.FIRE_ALARM"
        const val ACTION_SHOW_ALARMS = "com.danggui.memo.action.SHOW_ALARMS"
        const val EXTRA_REMINDER_ID = "reminderId"
        const val EXTRA_SCHEDULE_REVISION = "scheduleRevision"
        private const val FIRE_ALARM_REQUEST_CODE = 7101
        private const val SHOW_ALARM_REQUEST_CODE = 7102
        private const val MISSED_ALARM_GRACE_MILLIS = 2 * 60_000L
        private val schedulerLock = Any()
    }
}
