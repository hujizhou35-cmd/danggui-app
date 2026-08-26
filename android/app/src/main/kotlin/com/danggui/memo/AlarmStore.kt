package com.danggui.memo

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.UserManager
import org.json.JSONArray
import org.json.JSONObject

internal data class AlarmReconciliation(val removed: List<AlarmRecord>)

/**
 * Device-protected durable mirror for native alarms.
 *
 * Records are keyed by reminder + revision so a committed old alarm and a pending
 * replacement can coexist during the short two-phase installation transaction.
 */
internal class AlarmStore(context: Context) {
    private val preferences = openPreferences(context)

    fun get(reminderId: String): AlarmRecord? = synchronized(lock) {
        activeRecord(readRecords(), reminderId)
    }

    fun get(reminderId: String, scheduleRevision: Long): AlarmRecord? = synchronized(lock) {
        readRecords()[recordKey(reminderId, scheduleRevision)]
    }

    fun scheduled(): List<AlarmRecord> = synchronized(lock) {
        activeRecords(readRecords())
            .filter { it.state == AlarmRecord.STATE_SCHEDULED }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun ringing(): List<AlarmRecord> = synchronized(lock) {
        activeRecords(readRecords())
            .filter { it.state == AlarmRecord.STATE_RINGING }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun pending(): List<AlarmRecord> = synchronized(lock) {
        readRecords().values
            .filter { it.state == AlarmRecord.STATE_PENDING }
            .sortedWith(compareBy(AlarmRecord::reminderId, AlarmRecord::scheduleRevision))
    }

    fun cancellationPending(): List<AlarmRecord> = synchronized(lock) {
        readRecords().values
            .filter { it.state == AlarmRecord.STATE_CANCEL_PENDING }
            .sortedWith(compareBy(AlarmRecord::reminderId, AlarmRecord::scheduleRevision))
    }

    fun latestRevision(reminderId: String): Long? = synchronized(lock) {
        readRecords().values
            .asSequence()
            .filter {
                it.reminderId == reminderId &&
                    it.state != AlarmRecord.STATE_CANCEL_PENDING
            }
            .maxOfOrNull(AlarmRecord::scheduleRevision)
    }

    fun isDeliverable(record: AlarmRecord): Boolean = synchronized(lock) {
        val records = readRecords()
        records[recordKey(record)] == record && isDeliverableRecord(records, record)
    }

    fun stageReplacement(record: AlarmRecord): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val previous = activeRecord(records, record.reminderId)
        if (!AlarmIdentityPolicy.canReplace(previous?.scheduleRevision, record.scheduleRevision)) {
            return@synchronized null
        }
        val pending =
            record.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                ringStartedElapsedRealtimeMs = null,
            )
        if (records.values.any {
                it.reminderId == record.reminderId &&
                    it.state == AlarmRecord.STATE_CANCEL_PENDING
            }
        ) {
            return@synchronized null
        }
        val existing = records[recordKey(pending)]
        if (existing == pending) return@synchronized previous
        val newestRevision =
            records.values
                .asSequence()
                .filter { it.reminderId == record.reminderId }
                .maxOfOrNull(AlarmRecord::scheduleRevision)
        if (newestRevision != null && newestRevision >= record.scheduleRevision) {
            return@synchronized null
        }
        records[recordKey(pending)] = pending
        if (writeRecords(records)) previous else null
    }

    fun stageInitial(record: AlarmRecord): Boolean = synchronized(lock) {
        val records = readRecords()
        if (activeRecord(records, record.reminderId) != null) return@synchronized false
        if (records.values.any {
                it.reminderId == record.reminderId &&
                    it.state == AlarmRecord.STATE_CANCEL_PENDING
            }
        ) {
            return@synchronized false
        }
        val newerRevision =
            records.values
                .asSequence()
                .filter { it.reminderId == record.reminderId }
                .maxOfOrNull(AlarmRecord::scheduleRevision)
        if (newerRevision != null && newerRevision > record.scheduleRevision) {
            return@synchronized false
        }
        val pending =
            record.copy(
                state = AlarmRecord.STATE_PENDING,
                sessionId = null,
                ringStartedElapsedRealtimeMs = null,
            )
        records[recordKey(pending)] = pending
        writeRecords(records)
    }

    fun commitPendingReplacement(
        pending: AlarmRecord,
        expectedPrevious: AlarmRecord?,
        eventsToAppend: List<AlarmEvent>,
    ): Boolean = synchronized(lock) {
        val records = readRecords()
        val pendingKey = recordKey(pending)
        val storedPending = records[pendingKey]
        if (storedPending != pending || storedPending.state != AlarmRecord.STATE_PENDING) {
            return@synchronized false
        }
        val currentPrevious =
            activeRecords(records)
                .filter { it.reminderId == pending.reminderId && recordKey(it) != pendingKey }
                .maxByOrNull { it.scheduleRevision }
        if (currentPrevious != expectedPrevious) return@synchronized false

        records.entries.removeAll {
            it.value.reminderId == pending.reminderId && it.key != pendingKey
        }
        records[pendingKey] =
            pending.copy(
                state = AlarmRecord.STATE_SCHEDULED,
                sessionId = null,
                ringStartedElapsedRealtimeMs = null,
            )
        writeRecordsAndEvents(records, readEvents() + eventsToAppend)
    }

    /**
     * Durably hides every revision before any PendingIntent is cancelled. A crash after this
     * commit can only leave cancel-pending records, which recovery retires but never rearms.
     * Null means the tombstone write failed; an empty list is a successful idempotent cancel.
     */
    fun stageCancellation(reminderId: String): List<AlarmRecord>? = synchronized(lock) {
        val records = readRecords()
        val targets = records.values.filter { it.reminderId == reminderId }
        if (targets.isEmpty()) return@synchronized emptyList()
        targets.forEach { record ->
            records[recordKey(record)] = record.copy(state = AlarmRecord.STATE_CANCEL_PENDING)
        }
        if (writeRecords(records)) targets else null
    }

    fun finalizeCancellation(reminderId: String): Boolean = synchronized(lock) {
        val records = readRecords()
        val matching = records.values.filter { it.reminderId == reminderId }
        if (matching.isEmpty()) return@synchronized true
        if (matching.any { it.state != AlarmRecord.STATE_CANCEL_PENDING }) {
            return@synchronized false
        }
        records.entries.removeAll { it.value.reminderId == reminderId }
        writeRecords(records)
    }

    fun rollbackPending(expectedPending: AlarmRecord): Boolean = synchronized(lock) {
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
        val removed = activeRecord(records, reminderId) ?: return@synchronized null
        records.entries.removeAll { it.value.reminderId == reminderId }
        if (writeRecords(records)) removed else null
    }

    fun removeScheduled(reminderId: String, scheduleRevision: Long): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision)
        val current = records[key]
        if (current?.state != AlarmRecord.STATE_SCHEDULED) return@synchronized null
        records.remove(key)
        if (writeRecords(records)) current else null
    }

    fun removeScheduled(keys: Set<Pair<String, Long>>): List<AlarmRecord> = synchronized(lock) {
        if (keys.isEmpty()) return@synchronized emptyList()
        val records = readRecords()
        val removed = mutableListOf<AlarmRecord>()
        keys.forEach { (reminderId, scheduleRevision) ->
            val key = recordKey(reminderId, scheduleRevision)
            val current = records[key]
            if (current?.state == AlarmRecord.STATE_SCHEDULED) {
                records.remove(key)
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
        records.values.toList().forEach { record ->
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
                                    it.state == AlarmRecord.STATE_PENDING
                            }
                            .maxByOrNull(AlarmRecord::scheduleRevision) == record
                ) {
                    records.values.filter {
                        it.reminderId == record.reminderId &&
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
                        type = "missed",
                        occurredAtEpochMs = now,
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
        occurredAtEpochMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision)
        val current = records[key]
        if (current == null || !isDeliverableRecord(records, current)) return@synchronized null
        if (current.state == AlarmRecord.STATE_PENDING) {
            records.entries.removeAll {
                it.value.reminderId == reminderId &&
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
                type = "missed",
                occurredAtEpochMs = occurredAtEpochMs,
                detailCode = "recovery_window_expired",
                delayMillis = occurredAtEpochMs - current.triggerAtEpochMs,
            )
        if (writeRecordsAndEvents(records, readEvents() + event)) current else null
    }

    fun markRingingAndAppendDelivered(
        reminderId: String,
        scheduleRevision: Long,
        occurredAtEpochMs: Long,
        sessionId: String,
        ringStartedElapsedRealtimeMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val key = recordKey(reminderId, scheduleRevision)
        val current = records[key]
        if (current == null || !isDeliverableRecord(records, current)) return@synchronized null
        if (current.state == AlarmRecord.STATE_PENDING) {
            records.entries.removeAll { it.value.reminderId == reminderId && it.key != key }
        }
        val ringing =
            current.copy(
                state = AlarmRecord.STATE_RINGING,
                sessionId = sessionId,
                ringStartedElapsedRealtimeMs = ringStartedElapsedRealtimeMs,
            )
        records[key] = ringing
        val event =
            AlarmEvent(
                reminderId = current.reminderId,
                taskId = current.taskId,
                scheduleRevision = current.scheduleRevision,
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
        val current = activeRecord(records, reminderId)
        if (current?.state != AlarmRecord.STATE_RINGING) return@synchronized null
        if (current.scheduleRevision != scheduleRevision) {
            return@synchronized null
        }
        if (current.sessionId != sessionId) return@synchronized null
        records.remove(recordKey(current))
        val event =
            AlarmEvent(
                reminderId = current.reminderId,
                taskId = current.taskId,
                scheduleRevision = current.scheduleRevision,
                type = "stopped",
                occurredAtEpochMs = occurredAtEpochMs,
                sessionId = current.sessionId,
                detailCode = detailCode,
            )
        if (writeRecordsAndEvents(records, readEvents() + event)) current else null
    }

    fun appendEvent(event: AlarmEvent): Boolean = synchronized(lock) {
        val encoded = encodeEvents(trimEvents(readEvents() + event))
        val editor = preferences.edit()
        editor.putString(KEY_EVENTS_BACKUP, validEncodedEventsOrBackup() ?: encoded)
        editor.putString(KEY_EVENTS, encoded).commit()
    }

    fun events(): List<AlarmEvent> = synchronized(lock) { readEvents() }

    fun acknowledgeEvents(eventIds: Set<String>): Boolean = synchronized(lock) {
        if (eventIds.isEmpty()) return@synchronized true
        val remaining = readEvents().filterNot { eventIds.contains(it.eventId) }
        val encoded = encodeEvents(remaining)
        val editor = preferences.edit()
        editor.putString(KEY_EVENTS_BACKUP, validEncodedEventsOrBackup() ?: encoded)
        editor.putString(KEY_EVENTS, encoded)
        editor.commit()
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
        val ringing = records.values.filter { it.state == AlarmRecord.STATE_RINGING }
        ringing.forEach { records.remove(recordKey(it)) }
        val terminalEvents =
            ringing.map { record ->
                AlarmEvent(
                    reminderId = record.reminderId,
                    taskId = record.taskId,
                    scheduleRevision = record.scheduleRevision,
                    type = "stopped",
                    occurredAtEpochMs = occurredAtEpochMs,
                    sessionId = record.sessionId,
                    detailCode = "system_interruption",
                )
            }
        val editor = preferences.edit().putString(markerKey, interruptionToken)
        if (ringing.isNotEmpty()) {
            val encodedRecords = encodeRecords(records)
            val encodedEvents = encodeEvents(trimEvents(readEvents() + terminalEvents))
            editor
                .putString(
                    KEY_RECORDS_BACKUP,
                    validEncodedRecordsOrBackup() ?: encodedRecords,
                )
                .putString(KEY_EVENTS_BACKUP, validEncodedEventsOrBackup() ?: encodedEvents)
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
        val encoded = encodeRecords(records)
        val editor = preferences.edit()
        editor.putString(KEY_RECORDS_BACKUP, validEncodedRecordsOrBackup() ?: encoded)
        return editor.putString(KEY_RECORDS, encoded).commit()
    }

    private fun writeRecordsAndEvents(
        records: Map<String, AlarmRecord>,
        events: List<AlarmEvent>,
    ): Boolean {
        val encodedRecords = encodeRecords(records)
        val encodedEvents = encodeEvents(trimEvents(events))
        val editor = preferences.edit()
        editor.putString(
            KEY_RECORDS_BACKUP,
            validEncodedRecordsOrBackup() ?: encodedRecords,
        )
        editor.putString(KEY_EVENTS_BACKUP, validEncodedEventsOrBackup() ?: encodedEvents)
        return editor
            .putString(KEY_RECORDS, encodedRecords)
            .putString(KEY_EVENTS, encodedEvents)
            .commit()
    }

    private fun readEvents(): List<AlarmEvent> =
        decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS))
            ?: decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS_BACKUP))
            ?: emptyList()

    private fun validEncodedRecordsOrBackup(): String? =
        safeGetString(preferences, KEY_RECORDS)?.takeIf { decodeRecordsOrNull(it) != null }
            ?: safeGetString(preferences, KEY_RECORDS_BACKUP)
                ?.takeIf { decodeRecordsOrNull(it) != null }

    private fun validEncodedEventsOrBackup(): String? =
        safeGetString(preferences, KEY_EVENTS)?.takeIf { decodeEventsOrNull(it) != null }
            ?: safeGetString(preferences, KEY_EVENTS_BACKUP)
                ?.takeIf { decodeEventsOrNull(it) != null }

    companion object {
        private const val PREFERENCES_NAME = "danggui_native_alarm_store_v1"
        private const val KEY_RECORDS = "records"
        private const val KEY_RECORDS_BACKUP = "records_backup"
        private const val KEY_EVENTS = "events"
        private const val KEY_EVENTS_BACKUP = "events_backup"
        private const val KEY_DEVICE_STORAGE_MIGRATED = "device_storage_migrated"
        private const val KEY_LAST_RECOVERED_BOOT = "last_recovered_boot"
        private const val KEY_LAST_RECOVERED_PACKAGE = "last_recovered_package"
        internal const val MAX_EVENTS = 200
        private val lock = Any()

        private fun recordKey(record: AlarmRecord): String =
            recordKey(record.reminderId, record.scheduleRevision)

        private fun recordKey(reminderId: String, scheduleRevision: Long): String =
            "$reminderId#$scheduleRevision"

        private fun activeRecord(
            records: Map<String, AlarmRecord>,
            reminderId: String,
        ): AlarmRecord? =
            records.values
                .asSequence()
                .filter {
                    it.reminderId == reminderId &&
                        it.state != AlarmRecord.STATE_PENDING &&
                        it.state != AlarmRecord.STATE_CANCEL_PENDING
                }
                .maxByOrNull { it.scheduleRevision }

        private fun activeRecords(records: Map<String, AlarmRecord>): List<AlarmRecord> =
            records.values
                .filter {
                    it.state != AlarmRecord.STATE_PENDING &&
                        it.state != AlarmRecord.STATE_CANCEL_PENDING
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
                        records.values
                            .asSequence()
                            .filter {
                                it.reminderId == record.reminderId &&
                                    it.state == AlarmRecord.STATE_PENDING
                            }
                            .maxByOrNull { it.scheduleRevision }
                    !hasCommittedRecord && newestPending == record
                }
                else -> false
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
            val mergedRecords =
                storedRecords(credentialPreferences).apply {
                    storedRecords(devicePreferences).forEach {
                            (key, deviceRecord) ->
                        this[key] = deviceRecord
                    }
                }
            val mergedEvents =
                trimEvents(
                    (
                        storedEvents(credentialPreferences) + storedEvents(devicePreferences)
                        ).distinctBy(AlarmEvent::eventId).sortedBy(AlarmEvent::occurredAtEpochMs),
                )
            val editor = devicePreferences.edit().putBoolean(KEY_DEVICE_STORAGE_MIGRATED, true)
            if (mergedRecords.isNotEmpty()) editor.putString(KEY_RECORDS, encodeRecords(mergedRecords))
            if (mergedEvents.isNotEmpty()) editor.putString(KEY_EVENTS, encodeEvents(mergedEvents))
            editor.commit()
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

        private fun storedRecords(preferences: SharedPreferences): LinkedHashMap<String, AlarmRecord> =
            decodeRecordsOrNull(safeGetString(preferences, KEY_RECORDS))
                ?: decodeRecords(safeGetString(preferences, KEY_RECORDS_BACKUP))

        private fun storedEvents(preferences: SharedPreferences): List<AlarmEvent> =
            decodeEventsOrNull(safeGetString(preferences, KEY_EVENTS))
                ?: decodeEvents(safeGetString(preferences, KEY_EVENTS_BACKUP))

        private fun encodeEvents(events: List<AlarmEvent>): String =
            JSONArray(events.map(AlarmEvent::toJson)).toString()

        private fun trimEvents(events: List<AlarmEvent>): List<AlarmEvent> =
            events.takeLast(MAX_EVENTS)
    }
}
