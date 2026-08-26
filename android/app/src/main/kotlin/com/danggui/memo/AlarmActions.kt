package com.danggui.memo

import android.content.Context
import android.content.Intent
import android.os.Build

internal object AlarmActions {
    const val ACTION_STOP = "com.danggui.memo.action.STOP_ALARM"
    const val ACTION_SNOOZE = "com.danggui.memo.action.SNOOZE_ALARM"
    const val ACTION_SESSION_CHANGED = "com.danggui.memo.action.ALARM_SESSION_CHANGED"
    const val EXTRA_REMINDER_ID = "reminderId"
    const val EXTRA_SCHEDULE_REVISION = "scheduleRevision"
    const val EXTRA_SESSION_ID = "sessionId"
    const val EXTRA_SNOOZE_MINUTES = "snoozeMinutes"

    fun stop(
        context: Context,
        reminderId: String? = null,
        scheduleRevision: Long? = null,
        sessionId: String? = null,
        allowLegacyIdentity: Boolean = false,
    ): AlarmActionOutcome {
        val store = AlarmStore(context)
        val targets =
            targets(
                store = store,
                reminderId = reminderId,
                scheduleRevision = scheduleRevision,
                sessionId = sessionId,
                allowLegacyIdentity = allowLegacyIdentity,
            )
        var stoppedCount = 0
        var storageFailed = false
        targets.forEach { record ->
            if (
                store.removeRingingAndAppendStopped(
                    reminderId = record.reminderId,
                    scheduleRevision = record.scheduleRevision,
                    sessionId = record.sessionId,
                ) != null
            ) {
                stoppedCount += 1
            } else if (store.get(record.reminderId, record.scheduleRevision) == record) {
                storageFailed = true
            }
        }
        refreshSession(context, store)
        return AlarmActionOutcome(
            result =
                if (storageFailed) {
                    AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED
                } else {
                    AlarmScheduleResult.SUCCESS
                },
            affectedCount = stoppedCount,
        )
    }

    fun snooze(
        context: Context,
        reminderId: String? = null,
        scheduleRevision: Long? = null,
        sessionId: String? = null,
        minutes: Int,
        allowLegacyIdentity: Boolean = false,
    ): AlarmActionOutcome {
        val store = AlarmStore(context)
        val targets =
            targets(
                store = store,
                reminderId = reminderId,
                scheduleRevision = scheduleRevision,
                sessionId = sessionId,
                allowLegacyIdentity = allowLegacyIdentity,
            )
        val safeMinutes = minutes.coerceIn(1, 24 * 60)
        var scheduledCount = 0
        var failure = AlarmScheduleResult.SUCCESS
        targets.forEach { record ->
            val nextTriggerAtEpochMs = System.currentTimeMillis() + safeMinutes * 60_000L
            val next =
                record.copy(
                    scheduleRevision = record.scheduleRevision + 1,
                    triggerAtEpochMs = nextTriggerAtEpochMs,
                    defaultSnoozeMinutes = safeMinutes,
                    state = AlarmRecord.STATE_SCHEDULED,
                    sessionId = null,
                    ringStartedElapsedRealtimeMs = null,
                )
            val snoozedEvent =
                AlarmEvent(
                    reminderId = record.reminderId,
                    taskId = record.taskId,
                    scheduleRevision = record.scheduleRevision,
                    type = "snoozed",
                    snoozeMinutes = safeMinutes,
                    nextTriggerAtEpochMs = nextTriggerAtEpochMs,
                    sessionId = record.sessionId,
                )
            val scheduled =
                AlarmScheduler(context).scheduleSnooze(
                    ringingRecord = record,
                    snoozedRecord = next,
                    snoozedEvent = snoozedEvent,
                )
            if (scheduled == AlarmScheduleResult.SUCCESS) {
                scheduledCount += 1
            } else {
                if (failure == AlarmScheduleResult.SUCCESS) failure = scheduled
                store.appendEvent(
                    AlarmEvent(
                        reminderId = record.reminderId,
                        taskId = record.taskId,
                        scheduleRevision = record.scheduleRevision,
                        type = "error",
                        sessionId = record.sessionId,
                        detailCode = scheduled.errorCode ?: "snooze_schedule_failed",
                    ),
                )
            }
        }
        refreshSession(context, store)
        return AlarmActionOutcome(failure, scheduledCount)
    }

    /** Old callers without an identity operate on the first visible alarm, never on every alarm. */
    private fun targets(
        store: AlarmStore,
        reminderId: String?,
        scheduleRevision: Long?,
        sessionId: String?,
        allowLegacyIdentity: Boolean,
    ): List<AlarmRecord> {
        val ringing = store.ringing()
        if (AlarmIdentityPolicy.hasCompleteCurrentIdentity(reminderId, scheduleRevision, sessionId)) {
            return ringing.filter { record ->
                AlarmIdentityPolicy.matchesCurrent(
                    recordReminderId = record.reminderId,
                    recordRevision = record.scheduleRevision,
                    recordSessionId = record.sessionId,
                    requestedReminderId = requireNotNull(reminderId),
                    requestedRevision = requireNotNull(scheduleRevision),
                    requestedSessionId = requireNotNull(sessionId),
                )
            }
        }
        if (!allowLegacyIdentity || sessionId != null) return emptyList()
        return ringing.filter { record ->
            AlarmIdentityPolicy.matchesLegacy(
                recordReminderId = record.reminderId,
                recordRevision = record.scheduleRevision,
                recordSessionId = record.sessionId,
                requestedReminderId = reminderId,
                requestedRevision = scheduleRevision,
            )
        }.take(1)
    }

    fun refreshSession(context: Context, store: AlarmStore = AlarmStore(context)) {
        context.sendBroadcast(
            Intent(ACTION_SESSION_CHANGED).apply { setPackage(context.packageName) },
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
            store.ringing().forEach { record ->
                store.appendEvent(
                    AlarmEvent(
                        reminderId = record.reminderId,
                        taskId = record.taskId,
                        scheduleRevision = record.scheduleRevision,
                        type = "error",
                        sessionId = record.sessionId,
                        detailCode = "ringing_service_refresh_failed",
                    ),
                )
            }
        }
    }
}
