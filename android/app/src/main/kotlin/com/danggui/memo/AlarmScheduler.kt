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

    fun activateDeviceGeneration(deviceGeneration: String?): AlarmActionOutcome =
        synchronized(schedulerLock) {
            val activation =
                store.activateDeviceGeneration(deviceGeneration)
                    ?: return AlarmActionOutcome(
                        AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED,
                        0,
                    )
            val retiredRinging =
                activation.retiredRecords.any { it.state == AlarmRecord.STATE_RINGING }
            activation.retiredRecords.forEach { record ->
                runCatching {
                    cancelInstalledSystemAlarm(record)
                    if (record.deviceGeneration == null) {
                        cancelLegacySystemAlarm(record.reminderId)
                    }
                }
            }
            if (activation.changed) runCatching { restoreActivatedGeneration() }
            if (retiredRinging || activation.changed) {
                runCatching { AlarmActions.refreshSession(context, store) }
            }
            // The active-generation fence is the safety boundary. Platform
            // cancellation is idempotent best effort and is retried from the
            // preserved inactive mirror on every activation/reconciliation.
            AlarmActionOutcome(AlarmScheduleResult.SUCCESS, activation.retiredRecords.size)
        }

    fun schedule(record: AlarmRecord): AlarmScheduleResult = synchronized(schedulerLock) {
        store.flushTerminalEvents()
        if (!store.isActiveDeviceGeneration(record.deviceGeneration)) {
            return AlarmScheduleResult.INACTIVE_DEVICE_GENERATION
        }
        val now = System.currentTimeMillis()
        if (record.triggerAtEpochMs < now - AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS) {
            return AlarmScheduleResult.INVALID_TRIGGER_TIME
        }

        val scheduledRecord = normalizedScheduled(record)
        val previous = store.get(record.reminderId)
        if (previous == scheduledRecord) {
            if (!canScheduleExactAlarms()) {
                return AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            }
            val installed =
                installSystemAlarm(
                    scheduledRecord,
                    triggerAtEpochMs = maxOf(scheduledRecord.triggerAtEpochMs, now + 1_000L),
                )
            if (installed) cancelLegacySystemAlarm(scheduledRecord.reminderId)
            return if (installed) {
                AlarmScheduleResult.SUCCESS
            } else if (!canScheduleExactAlarms()) {
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            } else {
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED
            }
        }
        if (
            previous != null &&
                !AlarmIdentityPolicy.canReplace(
                    currentRevision = previous.scheduleRevision,
                    currentGeneration = previous.deviceGeneration,
                    candidateRevision = scheduledRecord.scheduleRevision,
                    candidateGeneration = scheduledRecord.deviceGeneration,
                )
        ) {
            return AlarmScheduleResult.STALE_SCHEDULE_REVISION
        }

        val transitionEvents = replacementEvents(previous, scheduledRecord)
        val reservations = transitionEvents.filter(AlarmEventRetentionPolicy::isBusinessEvent)
        val pendingTemplate =
            scheduledRecord.copy(
                state = AlarmRecord.STATE_PENDING,
                reservedBusinessEvents = reservations,
            )
        val storedRevision =
            store.get(
                record.reminderId,
                record.scheduleRevision,
                record.deviceGeneration,
            )
        val alreadyStaged =
            storedRevision?.state == AlarmRecord.STATE_PENDING &&
                normalizedScheduled(storedRevision) == scheduledRecord
        val pending = if (alreadyStaged) requireNotNull(storedRevision) else pendingTemplate
        val staged = alreadyStaged ||
            if (previous == null) {
                store.stageInitial(scheduledRecord)
            } else {
                store.stageReplacement(scheduledRecord, reservations) == previous
            }
        if (!staged) {
            return if (!store.hasBusinessEventCapacity(reservations)) {
                AlarmScheduleResult.BUSINESS_EVENT_CAPACITY_EXCEEDED
            } else if (
                store.get(record.reminderId)?.let { current ->
                    !AlarmIdentityPolicy.canReplace(
                        currentRevision = current.scheduleRevision,
                        currentGeneration = current.deviceGeneration,
                        candidateRevision = record.scheduleRevision,
                        candidateGeneration = record.deviceGeneration,
                    )
                } == true
            ) {
                AlarmScheduleResult.STALE_SCHEDULE_REVISION
            } else {
                AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED
            }
        }
        if (!canScheduleExactAlarms()) {
            return AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
        }

        if (
            !installSystemAlarm(
                scheduledRecord,
                triggerAtEpochMs =
                    maxOf(scheduledRecord.triggerAtEpochMs, System.currentTimeMillis() + 1_000L),
            )
        ) {
            return if (!canScheduleExactAlarms()) {
                AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED
            } else {
                AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED
            }
        }

        val retirementTargets =
            store.recordsForReminder(scheduledRecord.reminderId).filter { it != pending }
        if (
            !store.commitPendingReplacement(
                pending,
                previous,
                pendingCommitEvents(pending, previous, scheduledRecord),
            )
        ) {
            cancelInstalledSystemAlarm(scheduledRecord)
            return if (!store.hasBusinessEventCapacity(pending.reservedBusinessEvents)) {
                AlarmScheduleResult.BUSINESS_EVENT_CAPACITY_EXCEEDED
            } else {
                AlarmScheduleResult.DURABLE_COMMIT_FAILED
            }
        }

        retirementTargets.forEach { cancelInstalledSystemAlarm(it) }
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
        if (
            !store.isActiveDeviceGeneration(ringingRecord.deviceGeneration) ||
                !store.isActiveDeviceGeneration(snoozedRecord.deviceGeneration)
        ) {
            return AlarmScheduleResult.INACTIVE_DEVICE_GENERATION
        }
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

        val reservations = listOf(snoozedEvent)
        val pendingTemplate =
            snoozedRecord.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                legacySessionId = null,
                ringStartedElapsedRealtimeMs = null,
                reservedBusinessEvents = reservations,
            )
        val storedRevision =
            store.get(
                snoozedRecord.reminderId,
                snoozedRecord.scheduleRevision,
                snoozedRecord.deviceGeneration,
            )
        val alreadyStaged =
            storedRevision?.state == AlarmRecord.STATE_PENDING &&
                normalizedScheduled(storedRevision) == normalizedScheduled(snoozedRecord)
        val pending = if (alreadyStaged) requireNotNull(storedRevision) else pendingTemplate
        if (
            !alreadyStaged &&
                store.stageReplacement(snoozedRecord, reservations) != ringingRecord
        ) {
            return if (!store.hasBusinessEventCapacity(reservations)) {
                AlarmScheduleResult.BUSINESS_EVENT_CAPACITY_EXCEEDED
            } else if (
                store.get(snoozedRecord.reminderId)?.let { current ->
                    !AlarmIdentityPolicy.canReplace(
                        currentRevision = current.scheduleRevision,
                        currentGeneration = current.deviceGeneration,
                        candidateRevision = snoozedRecord.scheduleRevision,
                        candidateGeneration = snoozedRecord.deviceGeneration,
                    )
                } == true
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

        if (
            !store.commitPendingReplacement(
                pending = pending,
                expectedPrevious = ringingRecord,
                eventsToAppend = pendingCommitEvents(pending, ringingRecord, scheduled),
            )
        ) {
            cancelInstalledSystemAlarm(scheduled)
            return if (!store.hasBusinessEventCapacity(pending.reservedBusinessEvents)) {
                AlarmScheduleResult.BUSINESS_EVENT_CAPACITY_EXCEEDED
            } else {
                AlarmScheduleResult.DURABLE_COMMIT_FAILED
            }
        }

        cancelInstalledSystemAlarm(ringingRecord)
        cancelLegacySystemAlarm(ringingRecord.reminderId)
        AlarmScheduleResult.SUCCESS
    }

    fun cancel(
        reminderId: String,
        deviceGeneration: String? = null,
    ): AlarmActionOutcome = synchronized(schedulerLock) {
        // A delayed cancel from a database image that no longer owns native
        // state is an idempotent no-op. It must not resolve by reminder ID into
        // the currently active restored database generation.
        if (!store.isActiveDeviceGeneration(deviceGeneration)) {
            return AlarmActionOutcome(AlarmScheduleResult.SUCCESS, 0)
        }
        val targets =
            store.stageCancellation(reminderId, deviceGeneration)
                ?: return AlarmActionOutcome(AlarmScheduleResult.DURABLE_STORE_WRITE_FAILED, 0)
        val installedCancelled = targets.map(::cancelInstalledSystemAlarm).all { it }
        val legacyCancelled = cancelLegacySystemAlarm(reminderId)
        val systemCancelled = installedCancelled && legacyCancelled
        val finalized =
            systemCancelled && store.finalizeCancellation(reminderId, deviceGeneration)
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
        // Reboot/package recovery retries any exact identities whose platform
        // cancellation was interrupted after an activation handoff.
        if (store.canRecoverActiveDeviceGeneration()) {
            activateDeviceGeneration(store.activeDeviceGeneration())
        }
        store.flushTerminalEvents()
        recoverCancellationTombstones()
        reconcileExpiredStoredAlarms()
        val now = System.currentTimeMillis()
        recoverPendingTransactions(now)
        if (!canScheduleExactAlarms()) return
        installScheduledRecords(now)
    }

    private fun installScheduledRecords(now: Long) {
        store.scheduled().forEach { record ->
            if (
                store.get(
                    record.reminderId,
                    record.scheduleRevision,
                    record.deviceGeneration,
                ) != record
            ) return@forEach
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
                        deviceGeneration = record.deviceGeneration,
                        type = "error",
                        detailCode = "system_alarm_install_failed",
                    ),
                )
            }
        }
    }

    private fun restoreActivatedGeneration() {
        val now = System.currentTimeMillis()
        // Restored ringing mirrors were terminalized atomically with the
        // active-generation fence. Only future scheduled routes are rearmed.
        store.flushTerminalEvents()
        reconcileExpiredStoredAlarms(now)
        recoverPendingTransactions(now)
        if (canScheduleExactAlarms()) installScheduledRecords(now)
    }

    fun reconcileStoredAlarms(now: Long = System.currentTimeMillis()): Unit =
        synchronized(schedulerLock) {
            if (store.canRecoverActiveDeviceGeneration()) {
                activateDeviceGeneration(store.activeDeviceGeneration())
            }
            store.flushTerminalEvents()
            recoverCancellationTombstones()
            reconcileExpiredStoredAlarms(now)
            recoverPendingTransactions(now)
        }

    private fun recoverCancellationTombstones() {
        store.cancellationPending()
            .groupBy { it.reminderId to it.deviceGeneration }
            .forEach { (identity, records) ->
                val (reminderId, deviceGeneration) = identity
                val installedCancelled = records.map(::cancelInstalledSystemAlarm).all { it }
                val legacyCancelled = cancelLegacySystemAlarm(reminderId)
                if (installedCancelled && legacyCancelled) {
                    store.finalizeCancellation(reminderId, deviceGeneration)
                }
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
                val highestRevision =
                    pendingRecords.maxOfOrNull(AlarmRecord::scheduleRevision) ?: return@forEach
                val pending =
                    pendingRecords.lastOrNull { it.scheduleRevision == highestRevision }
                        ?: return@forEach
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
                if (
                    previous != null &&
                        !AlarmIdentityPolicy.canReplace(
                            currentRevision = previous.scheduleRevision,
                            currentGeneration = previous.deviceGeneration,
                            candidateRevision = pending.scheduleRevision,
                            candidateGeneration = pending.deviceGeneration,
                        )
                ) {
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
                            deviceGeneration = pending.deviceGeneration,
                            type = "error",
                            detailCode = "pending_alarm_install_failed",
                        ),
                    )
                    return@forEach
                }
                val retirementTargets =
                    store.recordsForReminder(reminderId).filter { it != pending }
                if (
                    !store.commitPendingReplacement(
                        pending,
                        previous,
                        pendingCommitEvents(pending, previous, scheduled),
                    )
                ) {
                    cancelInstalledSystemAlarm(scheduled)
                    store.appendEvent(
                        AlarmEvent(
                            reminderId = pending.reminderId,
                            taskId = pending.taskId,
                            scheduleRevision = pending.scheduleRevision,
                            deviceGeneration = pending.deviceGeneration,
                            type = "error",
                            detailCode = "pending_alarm_commit_failed",
                        ),
                    )
                    return@forEach
                }
                retirementTargets.forEach { cancelInstalledSystemAlarm(it) }
                cancelLegacySystemAlarm(reminderId)
                refreshRingingSession = refreshRingingSession || previous?.state == AlarmRecord.STATE_RINGING
            }
        if (refreshRingingSession) AlarmActions.refreshSession(context, store)
    }

    private fun normalizedScheduled(record: AlarmRecord): AlarmRecord =
        record.copy(
            state = AlarmRecord.STATE_SCHEDULED,
            sessionId = null,
            legacySessionId = null,
            ringStartedElapsedRealtimeMs = null,
            reservedBusinessEvents = emptyList(),
        )

    /**
     * v1.1.5 pending records carry their business event reservation. Recovery
     * appends that exact durable event, preserving its event/session identity.
     * Older pending records have no reservation and keep the v1.1.4 fallback.
     */
    private fun pendingCommitEvents(
        pending: AlarmRecord,
        previous: AlarmRecord?,
        scheduled: AlarmRecord,
    ): List<AlarmEvent> =
        if (pending.reservedBusinessEvents.isEmpty()) {
            replacementEvents(previous, scheduled)
        } else {
            listOf(registeredEvent(scheduled))
        }

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
                        deviceGeneration = previous.deviceGeneration,
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
            deviceGeneration = record.deviceGeneration,
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
        val identityUri =
            alarmIdentityUri(
                record.reminderId,
                record.scheduleRevision,
                record.deviceGeneration,
            )
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
                        record.deviceGeneration?.let {
                            putExtra(EXTRA_DEVICE_GENERATION, it)
                        }
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
                            record.deviceGeneration?.let {
                                putExtra(EXTRA_DEVICE_GENERATION, it)
                            }
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
        const val EXTRA_DEVICE_GENERATION = "deviceGeneration"
        private const val FIRE_ALARM_REQUEST_CODE = 7101
        private const val SHOW_ALARM_REQUEST_CODE = 7102
        private val schedulerLock = Any()

        internal fun alarmIdentityUri(
            reminderId: String,
            scheduleRevision: Long,
            deviceGeneration: String? = null,
        ): Uri =
            Uri.Builder()
                .scheme("danggui")
                .authority("alarm")
                .appendPath(reminderId)
                .appendPath(scheduleRevision.toString())
                .apply { deviceGeneration?.let { appendPath(it) } }
                .build()
    }
}
