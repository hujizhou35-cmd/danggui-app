package com.danggui.memo

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.UserManager
import org.json.JSONArray
import org.json.JSONObject

internal data class AlarmReconciliation(val removed: List<AlarmRecord>)

internal data class AlarmGenerationActivation(
    val activeGeneration: String?,
    val retiredRecords: List<AlarmRecord>,
    val changed: Boolean,
)

/**
 * Device-protected durable mirror for native alarms.
 *
 * Records are keyed by reminder + revision so a committed old alarm and a pending
 * replacement can coexist during the short two-phase installation transaction.
 */
internal class AlarmStore(context: Context) {
    private val preferences = openPreferences(context)

    init {
        var sessionIdentityMigrationSucceeded = false
        AlarmDirectBootMigrationPolicy.startupSteps.forEach { step ->
            when (step) {
                AlarmDirectBootStartupStep.MIGRATE_V114_SESSION_IDENTITY ->
                    sessionIdentityMigrationSucceeded =
                        migrateV114SessionIdentityIfNeeded(preferences)
                AlarmDirectBootStartupStep.RECOVER_IMPORTED_RINGING ->
                    if (
                        AlarmDirectBootMigrationPolicy.canRecoverImportedRinging(
                            sessionIdentityMigrationSucceeded,
                        )
                    ) {
                        recoverCredentialImportedRingingIfNeeded()
                    }
            }
        }
    }

    fun activeDeviceGeneration(): String? = synchronized(lock) {
        AlarmGenerationPolicy.restoredGeneration(readActiveGenerationToken())
    }

    fun isActiveDeviceGeneration(deviceGeneration: String?): Boolean = synchronized(lock) {
        isActiveDeviceGenerationLocked(deviceGeneration)
    }

    fun canRecoverActiveDeviceGeneration(): Boolean = synchronized(lock) {
        AlarmGenerationPolicy.isRecoverable(readActiveGenerationToken())
    }

    /**
     * Atomically establishes the database generation that owns native platform
     * state. Older database projections remain a last-known-good mirror until
     * restore is conclusively committed by the shared layer. Public reads are
     * fenced to the active generation, while platform cancellation is retried
     * from the preserved inactive records.
     */
    fun activateDeviceGeneration(deviceGeneration: String?): AlarmGenerationActivation? =
        synchronized(lock) {
            val canonical = deviceGeneration?.let {
                AlarmIdentityPolicy.canonicalDeviceGeneration(it) ?: return@synchronized null
            }
            val previousToken = readActiveGenerationToken()
            val nextToken = AlarmGenerationPolicy.storageToken(canonical)
            val records = readRecords()
            val events = readEvents()
            val retired = AlarmGenerationPolicy.recordsToRetire(records.values, canonical)
            val changed =
                (previousToken ?: AlarmGenerationPolicy.LEGACY_STORAGE_TOKEN) != nextToken
            val primaryToken =
                AlarmGenerationPolicy.normalizedStorageToken(
                    safeGetString(preferences, KEY_ACTIVE_DEVICE_GENERATION),
                )
            val backupToken =
                AlarmGenerationPolicy.normalizedStorageToken(
                    safeGetString(preferences, KEY_ACTIVE_DEVICE_GENERATION_BACKUP),
                )
            if (!changed && primaryToken == nextToken && backupToken == nextToken) {
                // The active fence is already durable, but inactive platform
                // identities may have survived an earlier best-effort cancel.
                // Keep returning the preserved cleanup set so every boot,
                // reconciliation and repeated activation retries it.
                return@synchronized AlarmGenerationActivation(canonical, retired, false)
            }
            val activationRecords =
                if (changed) {
                    terminalizeRestoredGenerationRinging(
                        records = records,
                        activeGeneration = canonical,
                        occurredAtEpochMs = System.currentTimeMillis(),
                    )
                } else {
                    records
                }
            if (!writeActivation(nextToken, activationRecords, events)) {
                return@synchronized null
            }
            AlarmGenerationActivation(canonical, retired, changed)
        }

    fun get(reminderId: String): AlarmRecord? = synchronized(lock) {
        activeRecord(activeGenerationRecords(readRecords()), reminderId)
    }

    fun get(
        reminderId: String,
        scheduleRevision: Long,
        deviceGeneration: String? = null,
    ): AlarmRecord? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) return@synchronized null
        readRecords()[recordKey(reminderId, scheduleRevision, deviceGeneration)]
    }

    fun recordsForReminder(reminderId: String): List<AlarmRecord> = synchronized(lock) {
        activeGenerationRecords(readRecords()).values.filter {
            it.reminderId == reminderId &&
                it.state != AlarmRecord.STATE_TERMINAL_PENDING
        }
    }

    fun scheduled(): List<AlarmRecord> = synchronized(lock) {
        activeRecords(activeGenerationRecords(readRecords()))
            .filter { it.state == AlarmRecord.STATE_SCHEDULED }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun ringing(): List<AlarmRecord> = synchronized(lock) {
        activeRecords(activeGenerationRecords(readRecords()))
            .filter { it.state == AlarmRecord.STATE_RINGING }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun pending(): List<AlarmRecord> = synchronized(lock) {
        activeGenerationRecords(readRecords()).values
            .filter { it.state == AlarmRecord.STATE_PENDING }
            .sortedWith(compareBy(AlarmRecord::reminderId, AlarmRecord::scheduleRevision))
    }

    fun cancellationPending(): List<AlarmRecord> = synchronized(lock) {
        activeGenerationRecords(readRecords()).values
            .filter { it.state == AlarmRecord.STATE_CANCEL_PENDING }
            .sortedWith(compareBy(AlarmRecord::reminderId, AlarmRecord::scheduleRevision))
    }

    fun latestRevision(reminderId: String): Long? = synchronized(lock) {
        activeGenerationRecords(readRecords()).values
            .asSequence()
            .filter {
                it.reminderId == reminderId &&
                    it.state != AlarmRecord.STATE_CANCEL_PENDING &&
                    it.state != AlarmRecord.STATE_TERMINAL_PENDING
            }
            .maxOfOrNull(AlarmRecord::scheduleRevision)
    }

    fun isDeliverable(record: AlarmRecord): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(record.deviceGeneration)) return@synchronized false
        val records = readRecords()
        records[recordKey(record)] == record &&
            isDeliverableRecord(activeGenerationRecords(records), record)
    }

    fun stageReplacement(
        record: AlarmRecord,
        reservedBusinessEvents: List<AlarmEvent> = emptyList(),
    ): AlarmRecord? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(record.deviceGeneration)) return@synchronized null
        if (reservedBusinessEvents.any { !AlarmEventRetentionPolicy.isBusinessEvent(it) }) {
            return@synchronized null
        }
        val records = readRecords()
        val activeRecords = activeGenerationRecords(records)
        if (records[recordKey(record)]?.state == AlarmRecord.STATE_TERMINAL_PENDING) {
            return@synchronized null
        }
        val previous = activeRecord(activeRecords, record.reminderId)
        if (
            !AlarmIdentityPolicy.canReplace(
                currentRevision = previous?.scheduleRevision,
                currentGeneration = previous?.deviceGeneration,
                candidateRevision = record.scheduleRevision,
                candidateGeneration = record.deviceGeneration,
            )
        ) {
            return@synchronized null
        }
        val pending =
            record.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                legacySessionId = null,
                ringStartedElapsedRealtimeMs = null,
                reservedBusinessEvents = reservedBusinessEvents,
            )
        if (activeRecords.values.any {
                it.reminderId == record.reminderId &&
                    it.state == AlarmRecord.STATE_CANCEL_PENDING &&
                    cancellationBlocksCandidate(it, record)
            }
        ) {
            return@synchronized null
        }
        val existing = records[recordKey(pending)]
        if (existing == pending) return@synchronized previous
        val newestRevision = newestRevisionForCandidate(activeRecords.values, record)
        if (newestRevision != null && newestRevision >= record.scheduleRevision) {
            return@synchronized null
        }
        records[recordKey(pending)] = pending
        if (writeRecords(records)) previous else null
    }

    fun stageInitial(record: AlarmRecord): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(record.deviceGeneration)) return@synchronized false
        val records = readRecords()
        val activeRecords = activeGenerationRecords(records)
        if (records[recordKey(record)]?.state == AlarmRecord.STATE_TERMINAL_PENDING) {
            return@synchronized false
        }
        if (activeRecord(activeRecords, record.reminderId) != null) {
            return@synchronized false
        }
        if (activeRecords.values.any {
                it.reminderId == record.reminderId &&
                    it.state == AlarmRecord.STATE_CANCEL_PENDING &&
                    cancellationBlocksCandidate(it, record)
            }
        ) {
            return@synchronized false
        }
        val newerRevision = newestRevisionForCandidate(activeRecords.values, record)
        if (newerRevision != null && newerRevision > record.scheduleRevision) {
            return@synchronized false
        }
        val pending =
            record.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                legacySessionId = null,
                ringStartedElapsedRealtimeMs = null,
                reservedBusinessEvents = emptyList(),
            )
        records[recordKey(pending)] = pending
        writeRecords(records)
    }

    fun commitPendingReplacement(
        pending: AlarmRecord,
        expectedPrevious: AlarmRecord?,
        eventsToAppend: List<AlarmEvent>,
    ): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(pending.deviceGeneration)) return@synchronized false
        val records = readRecords()
        val pendingKey = recordKey(pending)
        val storedPending = records[pendingKey]
        if (storedPending != pending || storedPending.state != AlarmRecord.STATE_PENDING) {
            return@synchronized false
        }
        val currentPrevious =
            activeRecords(activeGenerationRecords(records))
                .filter { it.reminderId == pending.reminderId && recordKey(it) != pendingKey }
                .maxByOrNull { it.scheduleRevision }
        if (currentPrevious != expectedPrevious) return@synchronized false

        val activeToken = readActiveGenerationToken()
        records.entries.removeAll {
            it.value.reminderId == pending.reminderId &&
                it.key != pendingKey &&
                it.value.state != AlarmRecord.STATE_TERMINAL_PENDING &&
                AlarmGenerationPolicy.isActive(activeToken, it.value.deviceGeneration)
        }
        records[pendingKey] =
            pending.copy(
                state = AlarmRecord.STATE_SCHEDULED,
                sessionId = null,
                legacySessionId = null,
                ringStartedElapsedRealtimeMs = null,
                reservedBusinessEvents = emptyList(),
            )
        writeRecordsAndEvents(
            records,
            readEvents() + eventsToAppend + storedPending.reservedBusinessEvents,
        )
    }

    /**
     * Durably hides every revision before any PendingIntent is cancelled. A crash after this
     * commit can only leave cancel-pending records, which recovery retires but never rearms.
     * Null means the tombstone write failed; an empty list is a successful idempotent cancel.
     */
    fun stageCancellation(
        reminderId: String,
        deviceGeneration: String?,
    ): List<AlarmRecord>? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) {
            return@synchronized emptyList()
        }
        val records = readRecords()
        val targets =
            activeGenerationRecords(records).values.filter {
                it.reminderId == reminderId &&
                    it.deviceGeneration == deviceGeneration &&
                    it.state != AlarmRecord.STATE_TERMINAL_PENDING
            }
        if (targets.isEmpty()) return@synchronized emptyList()
        targets.forEach { record ->
            records[recordKey(record)] = record.copy(state = AlarmRecord.STATE_CANCEL_PENDING)
        }
        if (writeRecords(records)) targets else null
    }

    fun finalizeCancellation(
        reminderId: String,
        deviceGeneration: String?,
    ): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) return@synchronized true
        val records = readRecords()
        val matching =
            activeGenerationRecords(records).values.filter {
                it.reminderId == reminderId &&
                    it.deviceGeneration == deviceGeneration &&
                    it.state != AlarmRecord.STATE_TERMINAL_PENDING
            }
        if (matching.isEmpty()) return@synchronized true
        if (matching.any { it.state != AlarmRecord.STATE_CANCEL_PENDING }) {
            return@synchronized false
        }
        val activeToken = readActiveGenerationToken()
        records.entries.removeAll {
            it.value.reminderId == reminderId &&
                it.value.deviceGeneration == deviceGeneration &&
                it.value.state != AlarmRecord.STATE_TERMINAL_PENDING &&
                AlarmGenerationPolicy.isActive(activeToken, it.value.deviceGeneration)
        }
        writeRecords(records)
    }

    fun rollbackPending(expectedPending: AlarmRecord): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(expectedPending.deviceGeneration)) {
            return@synchronized false
        }
        val records = readRecords()
        val key = recordKey(expectedPending)
        if (records[key] != expectedPending || expectedPending.state != AlarmRecord.STATE_PENDING) {
            return@synchronized false
        }
        records.remove(key)
        writeRecords(records)
    }

    fun remove(reminderId: String): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val removed =
            activeRecord(activeGenerationRecords(records), reminderId)
                ?: return@synchronized null
        val activeToken = readActiveGenerationToken()
        records.entries.removeAll {
            it.value.reminderId == reminderId &&
                it.value.state != AlarmRecord.STATE_TERMINAL_PENDING &&
                AlarmGenerationPolicy.isActive(activeToken, it.value.deviceGeneration)
        }
        if (writeRecords(records)) removed else null
    }

    fun removeScheduled(
        reminderId: String,
        scheduleRevision: Long,
        deviceGeneration: String? = null,
    ): AlarmRecord? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) return@synchronized null
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision, deviceGeneration)
        val current = records[key]
        if (current?.state != AlarmRecord.STATE_SCHEDULED) return@synchronized null
        records.remove(key)
        if (writeRecords(records)) current else null
    }

    fun removeScheduled(keys: Set<Pair<String, Long>>): List<AlarmRecord> = synchronized(lock) {
        if (keys.isEmpty()) return@synchronized emptyList()
        val records = readRecords()
        val removed = mutableListOf<AlarmRecord>()
        val activeToken = readActiveGenerationToken()
        keys.forEach { (reminderId, scheduleRevision) ->
            records.values
                .filter {
                    it.reminderId == reminderId &&
                        it.scheduleRevision == scheduleRevision &&
                        AlarmGenerationPolicy.isActive(activeToken, it.deviceGeneration) &&
                        it.state == AlarmRecord.STATE_SCHEDULED
                }
                .forEach { current ->
                    records.remove(recordKey(current))
                    removed += current
                }
        }
        if (removed.isEmpty()) return@synchronized emptyList()
        if (writeRecords(records)) removed else emptyList()
    }

    fun reconcileScheduledAlarms(
        now: Long,
        exactAlarmAllowed: Boolean,
    ): AlarmReconciliation = synchronized(lock) {
        val records = readRecords()
        val removed = mutableListOf<AlarmRecord>()
        val events = readEvents().toMutableList()
        activeGenerationRecords(records).values.toList().forEach { record ->
            if (records[recordKey(record)] != record) return@forEach
            val pending = record.state == AlarmRecord.STATE_PENDING
            val scheduled = record.state == AlarmRecord.STATE_SCHEDULED
            if (!pending && !scheduled) return@forEach
            val recoveryDecision =
                AlarmTransactionPolicy.recoveryDecision(
                    triggerAtEpochMs = record.triggerAtEpochMs,
                    nowEpochMs = now,
                    exactAlarmAllowed = exactAlarmAllowed,
                )
            if (recoveryDecision != AlarmRecoveryDecision.EXPIRE) return@forEach
            val terminalRecords =
                if (
                    pending &&
                        records.values
                            .filter {
                                it.reminderId == record.reminderId &&
                                    it.deviceGeneration == record.deviceGeneration &&
                                    it.state == AlarmRecord.STATE_PENDING
                            }
                            .maxByOrNull(AlarmRecord::scheduleRevision) == record
                ) {
                    records.values.filter {
                        it.reminderId == record.reminderId &&
                            it.deviceGeneration == record.deviceGeneration &&
                            it.state == AlarmRecord.STATE_PENDING
                    }
                } else {
                    listOf(record)
                }
            terminalRecords.forEach { terminal ->
                records.remove(recordKey(terminal))
                removed += terminal
                events +=
                    AlarmEvent(
                        reminderId = terminal.reminderId,
                        taskId = terminal.taskId,
                        scheduleRevision = terminal.scheduleRevision,
                        deviceGeneration = terminal.deviceGeneration,
                        type = "missed",
                        occurredAtEpochMs = now,
                        sessionId =
                            AlarmIdentityPolicy.deterministicSessionId(
                                terminal.reminderId,
                                terminal.scheduleRevision,
                                terminal.deviceGeneration,
                            ),
                        detailCode = "recovery_window_expired",
                        delayMillis = now - terminal.triggerAtEpochMs,
                    )
            }
        }
        if (removed.isEmpty()) return@synchronized AlarmReconciliation(emptyList())
        if (writeRecordsAndEvents(records, events)) {
            AlarmReconciliation(removed)
        } else {
            AlarmReconciliation(emptyList())
        }
    }

    fun expireDeliverable(
        reminderId: String,
        scheduleRevision: Long,
        deviceGeneration: String?,
        occurredAtEpochMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) return@synchronized null
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision, deviceGeneration)
        val current = records[key]
        if (
            current == null ||
                !isDeliverableRecord(activeGenerationRecords(records), current)
        ) return@synchronized null
        if (current.state == AlarmRecord.STATE_PENDING) {
            val activeToken = readActiveGenerationToken()
            records.entries.removeAll {
                it.value.reminderId == reminderId &&
                    AlarmGenerationPolicy.isActive(activeToken, it.value.deviceGeneration) &&
                    it.value.state == AlarmRecord.STATE_PENDING
            }
        } else {
            records.remove(key)
        }
        val event =
            AlarmEvent(
                reminderId = current.reminderId,
                taskId = current.taskId,
                scheduleRevision = current.scheduleRevision,
                deviceGeneration = current.deviceGeneration,
                type = "missed",
                occurredAtEpochMs = occurredAtEpochMs,
                sessionId =
                    AlarmIdentityPolicy.deterministicSessionId(
                        current.reminderId,
                        current.scheduleRevision,
                        current.deviceGeneration,
                    ),
                detailCode = "recovery_window_expired",
                delayMillis = occurredAtEpochMs - current.triggerAtEpochMs,
            )
        if (writeRecordsAndEvents(records, readEvents() + event)) current else null
    }

    fun markRingingAndAppendDelivered(
        reminderId: String,
        scheduleRevision: Long,
        deviceGeneration: String?,
        occurredAtEpochMs: Long,
        sessionId: String,
        ringStartedElapsedRealtimeMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(deviceGeneration)) return@synchronized null
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision, deviceGeneration)
        val current = records[key]
        if (
            current == null ||
                !isDeliverableRecord(activeGenerationRecords(records), current)
        ) return@synchronized null
        if (current.state == AlarmRecord.STATE_PENDING) {
            val activeToken = readActiveGenerationToken()
            records.entries.removeAll {
                it.value.reminderId == reminderId &&
                    it.key != key &&
                    AlarmGenerationPolicy.isActive(activeToken, it.value.deviceGeneration)
            }
        }
        val ringing =
            current.copy(
                state = AlarmRecord.STATE_RINGING,
                sessionId = sessionId,
                legacySessionId = null,
                ringStartedElapsedRealtimeMs = ringStartedElapsedRealtimeMs,
                reservedBusinessEvents = emptyList(),
            )
        records[key] = ringing
        val event =
            AlarmEvent(
                reminderId = current.reminderId,
                taskId = current.taskId,
                scheduleRevision = current.scheduleRevision,
                deviceGeneration = current.deviceGeneration,
                type = "delivered",
                occurredAtEpochMs = occurredAtEpochMs,
                sessionId = ringing.sessionId,
                delayMillis = (occurredAtEpochMs - current.triggerAtEpochMs).coerceAtLeast(0L),
            )
        if (writeRecordsAndEvents(records, readEvents() + event)) ringing else null
    }

    fun removeRingingAndAppendStopped(
        expected: AlarmRecord,
        occurredAtEpochMs: Long = System.currentTimeMillis(),
        detailCode: String? = null,
    ): AlarmRecord? =
        removeRingingAndAppendStopped(
            reminderId = expected.reminderId,
            scheduleRevision = expected.scheduleRevision,
            sessionId = expected.sessionId,
            occurredAtEpochMs = occurredAtEpochMs,
            detailCode = detailCode,
        )

    fun removeRingingAndAppendStopped(
        reminderId: String,
        scheduleRevision: Long,
        sessionId: String?,
        occurredAtEpochMs: Long = System.currentTimeMillis(),
        detailCode: String? = null,
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val current = activeRecord(activeGenerationRecords(records), reminderId)
        if (current?.state != AlarmRecord.STATE_RINGING) return@synchronized null
        if (current.scheduleRevision != scheduleRevision) {
            return@synchronized null
        }
        if (current.sessionId != sessionId) return@synchronized null
        val event =
            AlarmEvent(
                reminderId = current.reminderId,
                taskId = current.taskId,
                scheduleRevision = current.scheduleRevision,
                deviceGeneration = current.deviceGeneration,
                type = "stopped",
                occurredAtEpochMs = occurredAtEpochMs,
                sessionId = current.sessionId,
                detailCode = detailCode,
            )
        records[recordKey(current)] = AlarmTerminalEventPolicy.terminalize(current, event)
        val projection = terminalProjection(records, readEvents())
        if (writeRecordsAndEvents(projection.first, projection.second)) current else null
    }

    fun appendEvent(event: AlarmEvent): Boolean = synchronized(lock) {
        if (!isActiveDeviceGenerationLocked(event.deviceGeneration)) return@synchronized false
        val retained =
            retainEventsForActiveGeneration(
                readEvents() + event,
                reservedBusinessEvents(activeGenerationRecords(readRecords())),
            ) ?: return@synchronized false
        val encoded = encodeEvents(retained)
        val editor = preferences.edit()
        editor.putString(KEY_EVENTS_BACKUP, encoded)
        editor.putString(KEY_EVENTS, encoded).commit()
    }

    fun events(): List<AlarmEvent> = synchronized(lock) {
        val activeToken = readActiveGenerationToken()
        readEvents().filter {
            AlarmGenerationPolicy.isActive(activeToken, it.deviceGeneration)
        }
    }

    fun hasBusinessEventCapacity(events: List<AlarmEvent>): Boolean = synchronized(lock) {
        if (events.any { !isActiveDeviceGenerationLocked(it.deviceGeneration) }) {
            return@synchronized false
        }
        retainEventsForActiveGeneration(
            readEvents(),
            reservedBusinessEvents(activeGenerationRecords(readRecords())) +
                events.filter(AlarmEventRetentionPolicy::isBusinessEvent),
        ) != null
    }

    fun acknowledgeEvents(eventIds: Set<String>): Boolean = synchronized(lock) {
        if (eventIds.isEmpty()) return@synchronized true
        val activeToken = readActiveGenerationToken()
        val remaining =
            readEvents().filterNot { event ->
                event.eventId in eventIds &&
                    AlarmGenerationPolicy.isActive(activeToken, event.deviceGeneration)
            }
        val projection = terminalProjection(readRecords(), remaining)
        // Acknowledgement is a terminal deletion, not an ordinary append.  If
        // the backup retained the pre-ack array, fallback recovery could
        // resurrect a consumed business event after primary corruption.
        writeRecordsAndEvents(projection.first, projection.second)
    }

    fun flushTerminalEvents(): Int = synchronized(lock) {
        val records = readRecords()
        val before = activeTerminalCount(records)
        if (before == 0) return@synchronized 0
        val projection = terminalProjection(records, readEvents())
        val after = activeTerminalCount(projection.first)
        if (after == before) return@synchronized 0
        if (writeRecordsAndEvents(projection.first, projection.second)) before - after else 0
    }

    fun recoverAfterBoot(bootToken: String, occurredAtEpochMs: Long): Int =
        recoverRingingAfterInterruption(KEY_LAST_RECOVERED_BOOT, bootToken, occurredAtEpochMs)

    fun recoverAfterPackageReplacement(packageToken: String, occurredAtEpochMs: Long): Int =
        recoverRingingAfterInterruption(KEY_LAST_RECOVERED_PACKAGE, packageToken, occurredAtEpochMs)

    private fun recoverRingingAfterInterruption(
        markerKey: String,
        interruptionToken: String,
        occurredAtEpochMs: Long,
    ): Int = synchronized(lock) {
        if (safeGetString(preferences, markerKey) == interruptionToken) return@synchronized 0
        val records = readRecords()
        val ringing =
            activeGenerationRecords(records).values.filter {
                it.state == AlarmRecord.STATE_RINGING
            }
        ringing.forEach { record ->
            val event =
                AlarmEvent(
                    reminderId = record.reminderId,
                    taskId = record.taskId,
                    scheduleRevision = record.scheduleRevision,
                    deviceGeneration = record.deviceGeneration,
                    type = "stopped",
                    occurredAtEpochMs = occurredAtEpochMs,
                    sessionId = record.sessionId,
                    detailCode = "system_interruption",
                )
            records[recordKey(record)] = AlarmTerminalEventPolicy.terminalize(record, event)
        }
        val projection = terminalProjection(records, readEvents())
        val editor = preferences.edit().putString(markerKey, interruptionToken)
        if (ringing.isNotEmpty()) {
            val encodedRecords = encodeRecords(projection.first)
            val encodedEvents = encodeEvents(projection.second)
            editor
                .putString(
                    KEY_RECORDS_BACKUP,
                    encodedRecords,
                )
                .putString(KEY_EVENTS_BACKUP, encodedEvents)
                .putString(KEY_RECORDS, encodedRecords)
                .putString(KEY_EVENTS, encodedEvents)
        }
        if (editor.commit()) ringing.size else 0
    }

    private fun recoverCredentialImportedRingingIfNeeded(): Int = synchronized(lock) {
        val pending =
            runCatching {
                preferences.getBoolean(KEY_CREDENTIAL_IMPORT_RECOVERY_PENDING, false)
            }.getOrDefault(false)
        if (!pending) return@synchronized 0
        val records = readRecords()
        val ringing =
            activeGenerationRecords(records).values.filter {
                it.state == AlarmRecord.STATE_RINGING
            }
        val occurredAtEpochMs = System.currentTimeMillis()
        ringing.forEach { record ->
            val event =
                AlarmEvent(
                    reminderId = record.reminderId,
                    taskId = record.taskId,
                    scheduleRevision = record.scheduleRevision,
                    deviceGeneration = record.deviceGeneration,
                    type = "stopped",
                    occurredAtEpochMs = occurredAtEpochMs,
                    sessionId = record.sessionId,
                    detailCode = "system_interruption",
                )
            records[recordKey(record)] = AlarmTerminalEventPolicy.terminalize(record, event)
        }
        val projection = terminalProjection(records, readEvents())
        val editor = preferences.edit().remove(KEY_CREDENTIAL_IMPORT_RECOVERY_PENDING)
        if (ringing.isNotEmpty()) {
            val encodedRecords = encodeRecords(projection.first)
            val encodedEvents = encodeEvents(projection.second)
            editor
                .putString(KEY_RECORDS_BACKUP, encodedRecords)
                .putString(KEY_EVENTS_BACKUP, encodedEvents)
                .putString(KEY_RECORDS, encodedRecords)
                .putString(KEY_EVENTS, encodedEvents)
        }
        if (editor.commit()) ringing.size else 0
    }

    private fun readRecords(): LinkedHashMap<String, AlarmRecord> =
        decodeRecordsOrNull(safeGetString(preferences, KEY_RECORDS))
            ?: decodeRecordsOrNull(safeGetString(preferences, KEY_RECORDS_BACKUP))
            ?: linkedMapOf()

    private fun writeRecords(records: Map<String, AlarmRecord>): Boolean {
        if (
            retainEventsForActiveGeneration(
                readEvents(),
                reservedBusinessEvents(activeGenerationRecords(records)),
            ) == null
        ) {
            return false
        }
        val encoded = encodeRecords(records)
        val editor = preferences.edit()
        editor.putString(KEY_RECORDS_BACKUP, encoded)
        return editor.putString(KEY_RECORDS, encoded).commit()
    }

    private fun writeRecordsAndEvents(
        records: Map<String, AlarmRecord>,
        events: List<AlarmEvent>,
    ): Boolean {
        val retainedEvents =
            retainEventsForActiveGeneration(
                events,
                reservedBusinessEvents(activeGenerationRecords(records)),
            ) ?: return false
        val encodedRecords = encodeRecords(records)
        val encodedEvents = encodeEvents(retainedEvents)
        val editor = preferences.edit()
        editor.putString(KEY_RECORDS_BACKUP, encodedRecords)
        editor.putString(KEY_EVENTS_BACKUP, encodedEvents)
        return editor
            .putString(KEY_RECORDS, encodedRecords)
            .putString(KEY_EVENTS, encodedEvents)
            .commit()
    }

    private fun readEvents(): List<AlarmEvent> =
        decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS))
            ?: decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS_BACKUP))
            ?: emptyList()

    private fun reservedBusinessEvents(records: Map<String, AlarmRecord>): List<AlarmEvent> =
        AlarmEventRetentionPolicy.reservationsFrom(records.values)

    private fun terminalProjection(
        records: Map<String, AlarmRecord>,
        events: List<AlarmEvent>,
    ): Pair<LinkedHashMap<String, AlarmRecord>, List<AlarmEvent>> {
        val activeToken = readActiveGenerationToken()
        if (!AlarmGenerationPolicy.isRecoverable(activeToken)) {
            return LinkedHashMap(records) to events
        }
        val activeGeneration = AlarmGenerationPolicy.restoredGeneration(activeToken)
        val projection =
            AlarmTerminalEventPolicy.flush(
                records = records.values.toList(),
                events = events,
                activeGeneration = activeGeneration,
            )
        val projectedRecords = linkedMapOf<String, AlarmRecord>()
        projection.records.forEach { projectedRecords[recordKey(it)] = it }
        return projectedRecords to projection.events
    }

    private fun activeTerminalCount(records: Map<String, AlarmRecord>): Int {
        val activeToken = readActiveGenerationToken()
        return records.values.count {
            it.state == AlarmRecord.STATE_TERMINAL_PENDING &&
                AlarmGenerationPolicy.isActive(activeToken, it.deviceGeneration)
        }
    }

    private fun retainEventsForActiveGeneration(
        events: List<AlarmEvent>,
        reservedEvents: List<AlarmEvent>,
    ): List<AlarmEvent>? {
        val activeToken = readActiveGenerationToken()
        val activeEvents =
            events.filter {
                AlarmGenerationPolicy.isActive(activeToken, it.deviceGeneration)
            }
        val inactiveEvents =
            events.filterNot {
                AlarmGenerationPolicy.isActive(activeToken, it.deviceGeneration)
            }
        val retainedActive =
            AlarmEventRetentionPolicy.retainWithinCapacity(activeEvents, reservedEvents)
                ?: return null
        // Only the active generation is capacity-managed. Inactive events are
        // an LKG restore journal and must survive a failed database swap.
        return inactiveEvents + retainedActive
    }

    private fun readActiveGenerationToken(): String? =
        storedActiveGenerationToken(preferences)

    private fun isActiveDeviceGenerationLocked(deviceGeneration: String?): Boolean =
        AlarmGenerationPolicy.isActive(readActiveGenerationToken(), deviceGeneration)

    private fun activeGenerationRecords(
        records: Map<String, AlarmRecord>,
    ): LinkedHashMap<String, AlarmRecord> {
        val activeToken = readActiveGenerationToken()
        return linkedMapOf<String, AlarmRecord>().apply {
            records.forEach { (key, record) ->
                if (AlarmGenerationPolicy.isActive(activeToken, record.deviceGeneration)) {
                    put(key, record)
                }
            }
        }
    }

    /**
     * A generation that is being restored may contain a ringing mirror from
     * the last time it owned native state. Convert that mirror into a durable
     * terminal tombstone in the same SharedPreferences commit as the ownership
     * fence, so a post-fence I/O failure can never resurrect old output.
     */
    private fun terminalizeRestoredGenerationRinging(
        records: Map<String, AlarmRecord>,
        activeGeneration: String?,
        occurredAtEpochMs: Long,
    ): LinkedHashMap<String, AlarmRecord> =
        linkedMapOf<String, AlarmRecord>().apply {
            AlarmTerminalEventPolicy.terminalizeRestoredGeneration(
                records = records.values.toList(),
                activeGeneration = activeGeneration,
                occurredAtEpochMs = occurredAtEpochMs,
            ).forEach { projected ->
                put(recordKey(projected), projected)
            }
        }

    private fun writeActivation(
        generationToken: String,
        records: Map<String, AlarmRecord>,
        events: List<AlarmEvent>,
    ): Boolean {
        val encodedRecords = encodeRecords(records)
        val encodedEvents = encodeEvents(events)
        return preferences.edit()
            .putString(KEY_ACTIVE_DEVICE_GENERATION, generationToken)
            .putString(KEY_ACTIVE_DEVICE_GENERATION_BACKUP, generationToken)
            .putString(KEY_RECORDS_BACKUP, encodedRecords)
            .putString(KEY_EVENTS_BACKUP, encodedEvents)
            .putString(KEY_RECORDS, encodedRecords)
            .putString(KEY_EVENTS, encodedEvents)
            .commit()
    }

    companion object {
        private const val PREFERENCES_NAME = "danggui_native_alarm_store_v1"
        private const val KEY_RECORDS = "records"
        private const val KEY_RECORDS_BACKUP = "records_backup"
        private const val KEY_EVENTS = "events"
        private const val KEY_EVENTS_BACKUP = "events_backup"
        private const val KEY_ACTIVE_DEVICE_GENERATION = "active_device_generation_v1"
        private const val KEY_ACTIVE_DEVICE_GENERATION_BACKUP =
            "active_device_generation_v1_backup"
        private const val KEY_DEVICE_STORAGE_MIGRATED = "device_storage_migrated"
        private const val KEY_LAST_RECOVERED_BOOT = "last_recovered_boot"
        private const val KEY_LAST_RECOVERED_PACKAGE = "last_recovered_package"
        private const val KEY_SESSION_IDENTITY_V2 = "session_identity_v2"
        private const val KEY_CREDENTIAL_IMPORT_RECOVERY_PENDING =
            "credential_import_recovery_pending"
        private val lock = Any()

        private fun recordKey(record: AlarmRecord): String =
            recordKey(record.reminderId, record.scheduleRevision, record.deviceGeneration)

        private fun recordKey(
            reminderId: String,
            scheduleRevision: Long,
            deviceGeneration: String?,
        ): String =
            if (deviceGeneration == null) {
                "$reminderId#$scheduleRevision"
            } else {
                "$reminderId#$scheduleRevision#$deviceGeneration"
            }

        private fun cancellationBlocksCandidate(
            cancellation: AlarmRecord,
            candidate: AlarmRecord,
        ): Boolean =
            candidate.deviceGeneration == null ||
                cancellation.deviceGeneration == candidate.deviceGeneration

        private fun newestRevisionForCandidate(
            records: Collection<AlarmRecord>,
            candidate: AlarmRecord,
        ): Long? =
            records
                .asSequence()
                .filter {
                    it.reminderId == candidate.reminderId &&
                        it.deviceGeneration == candidate.deviceGeneration &&
                        it.state != AlarmRecord.STATE_TERMINAL_PENDING
                }
                .maxOfOrNull(AlarmRecord::scheduleRevision)

        private fun activeRecord(
            records: Map<String, AlarmRecord>,
            reminderId: String,
        ): AlarmRecord? =
            records.values
                .asSequence()
                .filter {
                        it.reminderId == reminderId &&
                        it.state != AlarmRecord.STATE_PENDING &&
                        it.state != AlarmRecord.STATE_CANCEL_PENDING &&
                        it.state != AlarmRecord.STATE_TERMINAL_PENDING
                }
                .maxByOrNull { it.scheduleRevision }

        private fun activeRecords(records: Map<String, AlarmRecord>): List<AlarmRecord> =
            records.values
                .filter {
                    it.state != AlarmRecord.STATE_PENDING &&
                        it.state != AlarmRecord.STATE_CANCEL_PENDING &&
                        it.state != AlarmRecord.STATE_TERMINAL_PENDING
                }
                .groupBy(AlarmRecord::reminderId)
                .values
                .mapNotNull { candidates -> candidates.maxByOrNull { it.scheduleRevision } }

        private fun isDeliverableRecord(
            records: Map<String, AlarmRecord>,
            record: AlarmRecord,
        ): Boolean =
            when (record.state) {
                AlarmRecord.STATE_SCHEDULED -> activeRecord(records, record.reminderId) == record
                AlarmRecord.STATE_PENDING -> {
                    val hasCommittedRecord = activeRecord(records, record.reminderId) != null
                    val newestPending =
                        newestPendingRecord(records.values, record.reminderId)
                    !hasCommittedRecord && newestPending == record
                }
                else -> false
            }

        private fun newestPendingRecord(
            records: Collection<AlarmRecord>,
            reminderId: String,
        ): AlarmRecord? {
            val candidates = records.filter {
                it.reminderId == reminderId && it.state == AlarmRecord.STATE_PENDING
            }
            val highestRevision = candidates.maxOfOrNull(AlarmRecord::scheduleRevision)
                ?: return null
            // LinkedHashMap order is durable through encode/decode. A newly
            // staged generation therefore wins a same-revision recovery tie.
            return candidates.lastOrNull { it.scheduleRevision == highestRevision }
        }

        private fun openPreferences(context: Context): SharedPreferences {
            val applicationContext = context.applicationContext
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                return applicationContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            }
            val deviceContext = applicationContext.createDeviceProtectedStorageContext()
            val devicePreferences =
                deviceContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val userManager = applicationContext.getSystemService(UserManager::class.java)
            if (userManager?.isUserUnlocked == true) {
                synchronized(lock) {
                    migrateCredentialProtectedData(applicationContext, devicePreferences)
                }
            }
            return devicePreferences
        }

        private fun migrateCredentialProtectedData(
            context: Context,
            devicePreferences: SharedPreferences,
        ) {
            if (runCatching {
                    devicePreferences.getBoolean(KEY_DEVICE_STORAGE_MIGRATED, false)
                }.getOrDefault(false)
            ) {
                return
            }
            val credentialPreferences =
                context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val credentialRecords = storedRecords(credentialPreferences)
            val credentialEvents = storedEvents(credentialPreferences)
            val deviceRecords = storedRecords(devicePreferences)
            val deviceEvents = storedEvents(devicePreferences)
            val migrationDecision =
                AlarmDirectBootMigrationPolicy.decide(
                    credentialRecordCount = credentialRecords.size,
                    credentialEventCount = credentialEvents.size,
                )
            val mergedRecords =
                linkedMapOf<String, AlarmRecord>().apply {
                    putAll(credentialRecords)
                    putAll(deviceRecords)
                }
            val mergedEvents =
                trimEvents(
                    (
                        credentialEvents + deviceEvents
                        ).distinctBy(AlarmEvent::eventId).sortedBy(AlarmEvent::occurredAtEpochMs),
                )
            val editor = devicePreferences.edit().putBoolean(KEY_DEVICE_STORAGE_MIGRATED, true)
            val activeGenerationToken =
                AlarmDirectBootMigrationPolicy.selectActiveGenerationToken(
                    deviceAlarmStatePresent = deviceRecords.isNotEmpty() || deviceEvents.isNotEmpty(),
                    credentialAlarmStatePresent =
                        credentialRecords.isNotEmpty() || credentialEvents.isNotEmpty(),
                    deviceToken = storedActiveGenerationToken(devicePreferences),
                    credentialToken = storedActiveGenerationToken(credentialPreferences),
                )
            if (mergedRecords.isNotEmpty()) editor.putString(KEY_RECORDS, encodeRecords(mergedRecords))
            if (mergedEvents.isNotEmpty()) editor.putString(KEY_EVENTS, encodeEvents(mergedEvents))
            if (mergedRecords.isNotEmpty()) {
                editor.putString(KEY_RECORDS_BACKUP, encodeRecords(mergedRecords))
            }
            if (mergedEvents.isNotEmpty()) {
                editor.putString(KEY_EVENTS_BACKUP, encodeEvents(mergedEvents))
            }
            if (migrationDecision.resetSessionMigrationMarker) {
                editor.remove(KEY_SESSION_IDENTITY_V2)
            }
            if (migrationDecision.resetRecoveryMarkers) {
                editor.remove(KEY_LAST_RECOVERED_BOOT)
                editor.remove(KEY_LAST_RECOVERED_PACKAGE)
            }
            if (migrationDecision.recoverImportedRinging) {
                editor.putBoolean(KEY_CREDENTIAL_IMPORT_RECOVERY_PENDING, true)
            }
            activeGenerationToken?.let {
                editor.putString(KEY_ACTIVE_DEVICE_GENERATION, it)
                editor.putString(KEY_ACTIVE_DEVICE_GENERATION_BACKUP, it)
            }
            editor.commit()
        }

        /**
         * One-shot migration for v1.1.4's random ringing UUIDs.  The source is
         * app-private device-protected storage, and each event must additionally
         * match the recognisable v1.1.4 lifecycle shape before it is rewritten.
         * Once the marker exists, arbitrary later values are never normalised.
         */
        private fun migrateV114SessionIdentityIfNeeded(preferences: SharedPreferences): Boolean =
            synchronized(lock) {
                if (
                    runCatching {
                        preferences.getBoolean(KEY_SESSION_IDENTITY_V2, false)
                    }.getOrDefault(false)
                ) {
                    return@synchronized true
                }
                val originalRecords = storedRecords(preferences)
                val originalEvents = storedEvents(preferences)
                val migratedRecords =
                    linkedMapOf<String, AlarmRecord>().apply {
                        originalRecords.values.forEach { record ->
                            val session = AlarmIdentityPolicy.migratedV114RingingSessionId(record)
                            val migrated =
                                if (session == null) {
                                    record
                                } else {
                                    record.copy(
                                        sessionId = session,
                                        legacySessionId = record.sessionId,
                                    )
                                }
                            this[recordKey(migrated)] = migrated
                        }
                    }
                val migratedEvents =
                    originalEvents.map { event ->
                        val session =
                            AlarmIdentityPolicy.migratedV114EventSessionId(
                                event = event,
                                records = originalRecords.values,
                                events = originalEvents,
                            )
                        if (session == null || session == event.sessionId) {
                            event
                        } else {
                            event.copy(sessionId = session)
                        }
                    }
                val recordsEncoded = encodeRecords(migratedRecords)
                val eventsEncoded = encodeEvents(trimEvents(migratedEvents))
                preferences.edit()
                    .putString(KEY_RECORDS_BACKUP, recordsEncoded)
                    .putString(KEY_RECORDS, recordsEncoded)
                    .putString(KEY_EVENTS_BACKUP, eventsEncoded)
                    .putString(KEY_EVENTS, eventsEncoded)
                    .putBoolean(KEY_SESSION_IDENTITY_V2, true)
                    .commit()
            }

        private fun decodeRecords(encoded: String?): LinkedHashMap<String, AlarmRecord> =
            decodeRecordsOrNull(encoded) ?: linkedMapOf()

        private fun decodeRecordsOrNull(encoded: String?): LinkedHashMap<String, AlarmRecord>? {
            if (encoded == null) return null
            return runCatching {
                val root = JSONObject(encoded)
                val records = linkedMapOf<String, AlarmRecord>()
                val keys = root.keys()
                while (keys.hasNext()) {
                    val legacyKey = keys.next()
                    val record = AlarmRecord.fromJson(root.getJSONObject(legacyKey))
                    records[recordKey(record)] = record
                }
                records
            }.getOrNull()
        }

        private fun encodeRecords(records: Map<String, AlarmRecord>): String {
            val root = JSONObject()
            records.forEach { (key, record) -> root.put(key, record.toJson()) }
            return root.toString()
        }

        private fun decodeEvents(encoded: String?): List<AlarmEvent> =
            decodeEventsOrNull(encoded) ?: emptyList()

        private fun decodeEventsOrNull(encoded: String?): List<AlarmEvent>? {
            if (encoded == null) return null
            return runCatching {
                val array = JSONArray(encoded)
                buildList {
                    repeat(array.length()) { index ->
                        add(AlarmEvent.fromJson(array.getJSONObject(index)))
                    }
                }
            }.getOrNull()
        }

        private fun safeGetString(preferences: SharedPreferences, key: String): String? =
            runCatching { preferences.getString(key, null) }.getOrNull()

        private fun storedActiveGenerationToken(preferences: SharedPreferences): String? =
            AlarmGenerationPolicy.recoveredStorageToken(
                primaryPresent =
                    runCatching { preferences.contains(KEY_ACTIVE_DEVICE_GENERATION) }
                        .getOrDefault(false),
                primaryValue = safeGetString(preferences, KEY_ACTIVE_DEVICE_GENERATION),
                backupPresent =
                    runCatching { preferences.contains(KEY_ACTIVE_DEVICE_GENERATION_BACKUP) }
                        .getOrDefault(false),
                backupValue =
                    safeGetString(preferences, KEY_ACTIVE_DEVICE_GENERATION_BACKUP),
            )

        private fun storedRecords(preferences: SharedPreferences): LinkedHashMap<String, AlarmRecord> =
            decodeRecordsOrNull(safeGetString(preferences, KEY_RECORDS))
                ?: decodeRecords(safeGetString(preferences, KEY_RECORDS_BACKUP))

        private fun storedEvents(preferences: SharedPreferences): List<AlarmEvent> =
            decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS))
                ?: decodeEvents(safeGetString(preferences, KEY_EVENTS_BACKUP))

        private fun encodeEvents(events: List<AlarmEvent>): String =
            JSONArray(events.map(AlarmEvent::toJson)).toString()

        private fun trimEvents(events: List<AlarmEvent>): List<AlarmEvent> =
            events
                .groupBy(AlarmEvent::deviceGeneration)
                .values
                .flatMap(AlarmEventRetentionPolicy::retain)
                .sortedBy(AlarmEvent::occurredAtEpochMs)
    }
}
