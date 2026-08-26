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

    fun schedule(record: AlarmRecord): AlarmScheduleResult = synchronized(schedulerLock) {
        if (record.triggerAtEpochMs <= System.currentTimeMillis()) {
            return AlarmScheduleResult.INVALID_TRIGGER_TIME
        }

        val scheduledRecord = normalizedScheduled(record)
        val previous = store.get(record.reminderId)
        if (previous == scheduledRecord) {
            if (!canScheduleExactAlarms()) {
                return AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            }
            val installed = installSystemAlarm(scheduledRecord)
            if (installed) cancelLegacySystemAlarm(scheduledRecord.reminderId)
            return if (installed) {
                AlarmScheduleResult.SUCCESS
            } else if (!canScheduleExactAlarms()) {
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            } else {
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED
            }
        }
        if (previous != null && scheduledRecord.scheduleRevision <= previous.scheduleRevision) {
            return AlarmScheduleResult.STALE_SCHEDULE_REVISION
        }

        val pending = scheduledRecord.copy(state = AlarmRecord.STATE_PENDING)
        val alreadyStaged = store.get(record.reminderId, record.scheduleRevision) == pending
        val staged = alreadyStaged ||
            if (previous == null) {
                store.stageInitial(scheduledRecord)
            } else {
                store.stageReplacement(scheduledRecord) == previous
            }
        if (!staged) {
            return if ((store.latestRevision(record.reminderId) ?: Long.MIN_VALUE) >= record.scheduleRevision) {
                AlarmScheduleResult.STALE_SCHEDULE_REVISION
            } else {
                AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED
            }
        }
        if (!canScheduleExactAlarms()) {
            return AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
        }

        if (!installSystemAlarm(scheduledRecord)) {
            return if (!canScheduleExactAlarms()) {
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            } else {
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED
            }
        }

        val otherPending =
            store.pending().filter {
                it.reminderId == scheduledRecord.reminderId && it != pending
            }
        if (!store.commitPendingReplacement(pending, previous, replacementEvents(previous, scheduledRecord))) {
            cancelInstalledSystemAlarm(scheduledRecord)
            return AlarmScheduleResult.DURABLE_COMMIT_FAILED
        }

        previous?.let { cancelInstalledSystemAlarm(it) }
        otherPending.forEach { cancelInstalledSystemAlarm(it) }
        cancelLegacySystemAlarm(scheduledRecord.reminderId)
        if (previous?.state == AlarmRecord.STATE_RINGING) {
            AlarmActions.refreshSession(context, store)
        }
        AlarmScheduleResult.SUCCESS
    }

    fun scheduleSnooze(
        ringingRecord: AlarmRecord,
        snoozedRecord: AlarmRecord,
        snoozedEvent: AlarmEvent,
    ): AlarmScheduleResult = synchronized(schedulerLock) {
        if (snoozedRecord.triggerAtEpochMs <= System.currentTimeMillis()) {
            return AlarmScheduleResult.INVALID_TRIGGER_TIME
        }
        if (store.get(ringingRecord.reminderId) != ringingRecord) {
            return AlarmScheduleResult.STALE_SCHEDULE_REVISION
        }
        if (ringingRecord.state != AlarmRecord.STATE_RINGING) {
            return AlarmScheduleResult.STALE_SCHEDULE_REVISION
        }
        if (snoozedRecord.scheduleRevision <= ringingRecord.scheduleRevision) {
            return AlarmScheduleResult.STALE_SCHEDULE_REVISION
        }

        val pending =
            snoozedRecord.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                ringStartedElapsedRealtimeMs = null,
            )
        val alreadyStaged =
            store.get(snoozedRecord.reminderId, snoozedRecord.scheduleRevision) == pending
        if (!alreadyStaged && store.stageReplacement(snoozedRecord) != ringingRecord) {
            return if ((store.latestRevision(snoozedRecord.reminderId) ?: Long.MIN_VALUE) >=
                snoozedRecord.scheduleRevision
            ) {
                AlarmScheduleResult.STALE_SCHEDULE_REVISION
            } else {
                AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED
            }
        }
        if (!canScheduleExactAlarms()) {
            return AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
        }
        val scheduled = normalizedScheduled(snoozedRecord)
        if (!installSystemAlarm(scheduled)) {
            return if (!canScheduleExactAlarms()) {
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            } else {
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED
            }
        }

        val registered = registeredEvent(scheduled)
        if (
            !store.commitPendingReplacement(
                pending = pending,
                expectedPrevious = ringingRecord,
                eventsToAppend = listOf(snoozedEvent, registered),
            )
        ) {
            cancelInstalledSystemAlarm(scheduled)
            return AlarmScheduleResult.DURABLE_COMMIT_FAILED
        }

        cancelInstalledSystemAlarm(ringingRecord)
        cancelLegacySystemAlarm(ringingRecord.reminderId)
        AlarmScheduleResult.SUCCESS
    }

    fun cancel(reminderId: String): AlarmActionOutcome = synchronized(schedulerLock) {
        val targets =
            store.stageCancellation(reminderId)
                ?: return AlarmActionOutcome(AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED, 0)
        val installedCancelled = targets.map(::cancelInstalledSystemAlarm).all { it }
        val legacyCancelled = cancelLegacySystemAlarm(reminderId)
        val systemCancelled = installedCancelled && legacyCancelled
        val finalized = systemCancelled && store.finalizeCancellation(reminderId)
        val durableState =
            AlarmTransactionPolicy.afterCancelAttempt(
                systemCancelSucceeded = systemCancelled,
                durableFinalizeSucceeded = finalized,
            )
        if (targets.any { it.state == AlarmRecord.STATE_RINGING }) {
            AlarmActions.refreshSession(context, store)
        }
        if (durableState == AlarmDurableState.REMOVED) {
            AlarmActionOutcome(AlarmScheduleResult.SUCCESS, targets.size)
        } else if (!systemCancelled) {
            AlarmActionOutcome(AlarmScheduleResult.SYSTEM_ALARM_CANCEL_FAILED, 0)
        } else {
            AlarmActionOutcome(AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED, 0)
        }
    }

    fun cancelSystemAlarm(record: AlarmRecord): Unit = synchronized(schedulerLock) {
        cancelInstalledSystemAlarm(record)
        cancelLegacySystemAlarm(record.reminderId)
    }

    /** Reinstalls durable alarms after boot, clock, timezone, permission, or package changes. */
    fun rescheduleAll(): Unit = synchronized(schedulerLock) {
        recoverCancellationTombstones()
        reconcileExpiredStoredAlarms()
        val now = System.currentTimeMillis()
        recoverPendingTransactions(now)
        if (!canScheduleExactAlarms()) return
        store.scheduled().forEach { record ->
            if (store.get(record.reminderId, record.scheduleRevision) != record) return@forEach
            val installed =
                installSystemAlarm(
                    record,
                    triggerAtEpochMs = maxOf(record.triggerAtEpochMs, now + 1_000L),
                )
            if (!installed) {
                store.appendEvent(
                    AlarmEvent(
                        reminderId = record.reminderId,
                        taskId = record.taskId,
                        scheduleRevision = record.scheduleRevision,
                        type = "error",
                        detailCode = "system_alarm_install_failed",
                    ),
                )
            }
        }
    }

    fun reconcileStoredAlarms(now: Long = System.currentTimeMillis()): Unit =
        synchronized(schedulerLock) {
            recoverCancellationTombstones()
            reconcileExpiredStoredAlarms(now)
            recoverPendingTransactions(now)
        }

    private fun recoverCancellationTombstones() {
        store.cancellationPending()
            .groupBy(AlarmRecord::reminderId)
            .forEach { (reminderId, records) ->
                val installedCancelled = records.map(::cancelInstalledSystemAlarm).all { it }
                val legacyCancelled = cancelLegacySystemAlarm(reminderId)
                if (installedCancelled && legacyCancelled) store.finalizeCancellation(reminderId)
            }
    }

    private fun reconcileExpiredStoredAlarms(now: Long = System.currentTimeMillis()) {
        val reconciliation =
            store.reconcileScheduledAlarms(
                now = now,
                exactAlarmAllowed = canScheduleExactAlarms(),
            )
        reconciliation.removed.forEach { record ->
            cancelInstalledSystemAlarm(record)
            // A failed replacement can coexist with an older legacy alarm. Expiring only the
            // pending revision must not cancel that still-active reminder-only PendingIntent.
            if (store.get(record.reminderId) == null) {
                cancelLegacySystemAlarm(record.reminderId)
            }
        }
    }

    private fun recoverPendingTransactions(now: Long) {
        var refreshRingingSession = false
        store.pending()
            .groupBy(AlarmRecord::reminderId)
            .forEach { (reminderId, pendingRecords) ->
                val pending = pendingRecords.maxByOrNull(AlarmRecord::scheduleRevision) ?: return@forEach
                when (
                    AlarmTransactionPolicy.recoveryDecision(
                        triggerAtEpochMs = pending.triggerAtEpochMs,
                        nowEpochMs = now,
                        exactAlarmAllowed = canScheduleExactAlarms(),
                    )
                ) {
                    AlarmRecoveryDecision.RETAIN_DURABLE -> return@forEach
                    AlarmRecoveryDecision.EXPIRE -> {
                        cancelInstalledSystemAlarm(pending)
                        store.rollbackPending(pending)
                        return@forEach
                    }
                    AlarmRecoveryDecision.INSTALL -> Unit
                }
                val previous = store.get(reminderId)
                if (previous != null && pending.scheduleRevision <= previous.scheduleRevision) {
                    cancelInstalledSystemAlarm(pending)
                    store.rollbackPending(pending)
                    return@forEach
                }
                val scheduled = normalizedScheduled(pending)
                val installed =
                    installSystemAlarm(
                        scheduled,
                        triggerAtEpochMs = maxOf(scheduled.triggerAtEpochMs, now + 1_000L),
                    )
                if (!installed) {
                    store.appendEvent(
                        AlarmEvent(
                            reminderId = pending.reminderId,
                            taskId = pending.taskId,
                            scheduleRevision = pending.scheduleRevision,
                            type = "error",
                            detailCode = "pending_alarm_install_failed",
                        ),
                    )
                    return@forEach
                }
                if (!store.commitPendingReplacement(pending, previous, replacementEvents(previous, scheduled))) {
                    cancelInstalledSystemAlarm(scheduled)
                    store.appendEvent(
                        AlarmEvent(
                            reminderId = pending.reminderId,
                            taskId = pending.taskId,
                            scheduleRevision = pending.scheduleRevision,
                            type = "error",
                            detailCode = "pending_alarm_commit_failed",
                        ),
                    )
                    return@forEach
                }
                previous?.let { cancelInstalledSystemAlarm(it) }
                pendingRecords.filterNot { it == pending }.forEach { cancelInstalledSystemAlarm(it) }
                cancelLegacySystemAlarm(reminderId)
                refreshRingingSession = refreshRingingSession || previous?.state == AlarmRecord.STATE_RINGING
            }
        if (refreshRingingSession) AlarmActions.refreshSession(context, store)
    }

    private fun normalizedScheduled(record: AlarmRecord): AlarmRecord =
        record.copy(
            state = AlarmRecord.STATE_SCHEDULED,
            sessionId = null,
            ringStartedElapsedRealtimeMs = null,
        )

    private fun replacementEvents(
        previous: AlarmRecord?,
        scheduled: AlarmRecord,
    ): List<AlarmEvent> =
        buildList {
            if (previous?.state == AlarmRecord.STATE_RINGING) {
                add(
                    AlarmEvent(
                        reminderId = previous.reminderId,
                        taskId = previous.taskId,
                        scheduleRevision = previous.scheduleRevision,
                        type = "stopped",
                        sessionId = previous.sessionId,
                        detailCode = "replaced_by_schedule",
                    ),
                )
            }
            add(registeredEvent(scheduled))
        }

    private fun registeredEvent(record: AlarmRecord): AlarmEvent =
        AlarmEvent(
            reminderId = record.reminderId,
            taskId = record.taskId,
            scheduleRevision = record.scheduleRevision,
            type = "registered",
            nextTriggerAtEpochMs = record.triggerAtEpochMs,
        )

    private fun installSystemAlarm(
        record: AlarmRecord,
        triggerAtEpochMs: Long = record.triggerAtEpochMs,
    ): Boolean {
        if (!canScheduleExactAlarms()) return false
        val operation = alarmDeliveryPendingIntent(record)
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
        } catch (_: IllegalStateException) {
            false
        }
    }

    private fun alarmDeliveryPendingIntent(record: AlarmRecord): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val identityUri = alarmIdentityUri(record.reminderId, record.scheduleRevision)
        return when (AlarmDeliveryPolicy.dispatchRouteForSdk(Build.VERSION.SDK_INT)) {
            AlarmDispatchRoute.WAKEFUL_RECEIVER ->
                PendingIntent.getBroadcast(
                    context,
                    FIRE_ALARM_REQUEST_CODE,
                    Intent(context, AlarmReceiver::class.java).apply {
                        action = ACTION_FIRE_ALARM
                        data = identityUri
                        putExtra(EXTRA_REMINDER_ID, record.reminderId)
                        putExtra(EXTRA_SCHEDULE_REVISION, record.scheduleRevision)
                    },
                    flags,
                )
            AlarmDispatchRoute.DIRECT_FOREGROUND_SERVICE ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    PendingIntent.getForegroundService(
                        context,
                        FIRE_ALARM_REQUEST_CODE,
                        Intent(context, AlarmRingingService::class.java).apply {
                            action = AlarmRingingService.ACTION_FIRE
                            data = identityUri
                            putExtra(EXTRA_REMINDER_ID, record.reminderId)
                            putExtra(EXTRA_SCHEDULE_REVISION, record.scheduleRevision)
                        },
                        flags,
                    )
                } else {
                    error("Foreground-service alarm route requires Android 8 or newer")
                }
        }
    }

    private fun cancelInstalledSystemAlarm(record: AlarmRecord): Boolean =
        runCatching { alarmManager.cancel(alarmDeliveryPendingIntent(record)) }.isSuccess

    /** Cancels a v1.1.3 broadcast PendingIntent whose identity did not include revision. */
    private fun cancelLegacySystemAlarm(reminderId: String): Boolean =
        runCatching {
            val legacy =
                PendingIntent.getBroadcast(
                    context,
                    FIRE_ALARM_REQUEST_CODE,
                    Intent(context, AlarmReceiver::class.java).apply {
                        action = ACTION_FIRE_ALARM
                        data =
                            Uri.Builder()
                                .scheme("danggui")
                                .authority("alarm")
                                .appendPath(reminderId)
                                .build()
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            alarmManager.cancel(legacy)
        }.isSuccess

    companion object {
        const val ACTION_FIRE_ALARM = "com.danggui.memo.action.FIRE_ALARM"
        const val ACTION_SHOW_ALARMS = "com.danggui.memo.action.SHOW_ALARMS"
        const val EXTRA_REMINDER_ID = "reminderId"
        const val EXTRA_SCHEDULE_REVISION = "scheduleRevision"
        private const val FIRE_ALARM_REQUEST_CODE = 7101
        private const val SHOW_ALARM_REQUEST_CODE = 7102
        private val schedulerLock = Any()

        internal fun alarmIdentityUri(reminderId: String, scheduleRevision: Long): Uri =
            Uri.Builder()
                .scheme("danggui")
                .authority("alarm")
                .appendPath(reminderId)
                .appendPath(scheduleRevision.toString())
                .build()
    }
}
