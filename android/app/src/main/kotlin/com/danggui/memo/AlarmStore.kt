package com.danggui.memo

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.UserManager
import org.json.JSONArray
import org.json.JSONObject

internal data class AlarmReconciliation(val removed: List<AlarmRecord>)

internal class AlarmStore(context: Context) {
    private val preferences = openPreferences(context)

    fun get(reminderId: String): AlarmRecord? = synchronized(lock) {
        readRecords()[reminderId]
    }

    fun scheduled(): List<AlarmRecord> = synchronized(lock) {
        readRecords().values
            .filter { it.state == AlarmRecord.STATE_SCHEDULED }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun ringing(): List<AlarmRecord> = synchronized(lock) {
        readRecords().values
            .filter { it.state == AlarmRecord.STATE_RINGING }
            .sortedBy { it.triggerAtEpochMs }
    }

    fun put(record: AlarmRecord): Boolean = synchronized(lock) {
        val records = readRecords()
        records[record.reminderId] = record
        writeRecords(records)
    }

    fun restoreIfCurrent(expected: AlarmRecord, previous: AlarmRecord?): Boolean = synchronized(lock) {
        val records = readRecords()
        if (records[expected.reminderId] != expected) return@synchronized false
        if (previous == null) {
            records.remove(expected.reminderId)
        } else {
            records[expected.reminderId] = previous
        }
        writeRecords(records)
    }

    fun replaceRingingAndAppendEvent(
        expected: AlarmRecord,
        replacement: AlarmRecord,
        event: AlarmEvent,
    ): Boolean = synchronized(lock) {
        val records = readRecords()
        val current = records[expected.reminderId]
        if (
            current != expected ||
                current.state != AlarmRecord.STATE_RINGING ||
                replacement.reminderId != expected.reminderId ||
                replacement.taskId != expected.taskId ||
                replacement.scheduleRevision != expected.scheduleRevision + 1 ||
                replacement.state != AlarmRecord.STATE_SCHEDULED ||
                event.reminderId != expected.reminderId ||
                event.taskId != expected.taskId ||
                event.scheduleRevision != expected.scheduleRevision ||
                event.type != "snoozed" ||
                event.nextTriggerAtEpochMs != replacement.triggerAtEpochMs
        ) {
            return@synchronized false
        }
        records[replacement.reminderId] = replacement
        val events = appendAndTrim(readEvents(), event)
        preferences.edit()
            .putString(KEY_RECORDS, encodeRecords(records))
            .putString(KEY_EVENTS, encodeEvents(events))
            .commit()
    }

    fun rollbackReplacementAndEvent(
        expectedReplacement: AlarmRecord,
        previous: AlarmRecord,
        eventId: String,
    ): Boolean = synchronized(lock) {
        val records = readRecords()
        if (records[expectedReplacement.reminderId] != expectedReplacement) {
            return@synchronized false
        }
        records[previous.reminderId] = previous
        val events = readEvents().filterNot { it.eventId == eventId }
        val editor =
            preferences.edit()
                .putString(KEY_RECORDS, encodeRecords(records))
        if (events.isEmpty()) {
            editor.remove(KEY_EVENTS)
        } else {
            editor.putString(KEY_EVENTS, encodeEvents(events))
        }
        editor.commit()
    }

    fun remove(reminderId: String): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val removed = records.remove(reminderId) ?: return@synchronized null
        if (writeRecords(records)) removed else null
    }

    fun removeScheduled(reminderId: String, scheduleRevision: Long): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val current = records[reminderId]
        if (
            current == null ||
                current.scheduleRevision != scheduleRevision ||
                current.state != AlarmRecord.STATE_SCHEDULED
        ) {
            return@synchronized null
        }
        records.remove(reminderId)
        if (writeRecords(records)) current else null
    }

    fun removeScheduled(keys: Set<Pair<String, Long>>): List<AlarmRecord> = synchronized(lock) {
        if (keys.isEmpty()) return@synchronized emptyList()
        val records = readRecords()
        val removed = mutableListOf<AlarmRecord>()
        keys.forEach { (reminderId, scheduleRevision) ->
            val current = records[reminderId]
            if (
                current != null &&
                    current.scheduleRevision == scheduleRevision &&
                    current.state == AlarmRecord.STATE_SCHEDULED
            ) {
                records.remove(reminderId)
                removed += current
            }
        }
        if (removed.isEmpty()) return@synchronized emptyList()
        if (writeRecords(records)) removed else emptyList()
    }

    fun reconcileScheduledAlarms(
        now: Long,
        missedAlarmGraceMillis: Long,
        exactAlarmAllowed: Boolean,
    ): AlarmReconciliation = synchronized(lock) {
        val records = readRecords()
        val removed = mutableListOf<AlarmRecord>()
        val expired = mutableListOf<AlarmRecord>()
        records.values.toList().forEach { record ->
            if (record.state != AlarmRecord.STATE_SCHEDULED) return@forEach
            val missed = record.triggerAtEpochMs <= now - missedAlarmGraceMillis
            val futureWithoutExactAccess =
                !exactAlarmAllowed && record.triggerAtEpochMs > now
            if (!missed && !futureWithoutExactAccess) return@forEach
            records.remove(record.reminderId)
            removed += record
            if (missed) expired += record
        }
        if (removed.isEmpty()) return@synchronized AlarmReconciliation(emptyList())

        val events =
            (
                readEvents() +
                    expired.map { record ->
                        AlarmEvent(
                            reminderId = record.reminderId,
                            taskId = record.taskId,
                            scheduleRevision = record.scheduleRevision,
                            type = "stopped",
                            occurredAtEpochMs = now,
                        )
                    }
                ).takeLast(MAX_EVENTS)
        val editor = preferences.edit().putString(KEY_RECORDS, encodeRecords(records))
        if (expired.isNotEmpty()) editor.putString(KEY_EVENTS, encodeEvents(events))
        if (editor.commit()) AlarmReconciliation(removed) else AlarmReconciliation(emptyList())
    }

    fun expireScheduled(
        reminderId: String,
        scheduleRevision: Long,
        occurredAtEpochMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val current = records[reminderId]
        if (
            current == null ||
                current.scheduleRevision != scheduleRevision ||
                current.state != AlarmRecord.STATE_SCHEDULED
        ) {
            return@synchronized null
        }
        records.remove(reminderId)
        val events =
            appendAndTrim(
                readEvents(),
                AlarmEvent(
                    reminderId = current.reminderId,
                    taskId = current.taskId,
                    scheduleRevision = current.scheduleRevision,
                    type = "stopped",
                    occurredAtEpochMs = occurredAtEpochMs,
                ),
            )
        val committed =
            preferences.edit()
                .putString(KEY_RECORDS, encodeRecords(records))
                .putString(KEY_EVENTS, encodeEvents(events))
                .commit()
        if (committed) current else null
    }

    fun markRingingAndAppendFired(
        reminderId: String,
        scheduleRevision: Long,
        occurredAtEpochMs: Long,
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val current = records[reminderId]
        if (
            current == null ||
                current.scheduleRevision != scheduleRevision ||
                current.state != AlarmRecord.STATE_SCHEDULED
        ) {
            return@synchronized null
        }
        val ringing = current.copy(state = AlarmRecord.STATE_RINGING)
        records[reminderId] = ringing
        val events =
            appendAndTrim(
                readEvents(),
                AlarmEvent(
                    reminderId = current.reminderId,
                    taskId = current.taskId,
                    scheduleRevision = current.scheduleRevision,
                    type = "fired",
                    occurredAtEpochMs = occurredAtEpochMs,
                ),
            )
        val committed =
            preferences.edit()
                .putString(KEY_RECORDS, encodeRecords(records))
                .putString(KEY_EVENTS, encodeEvents(events))
                .commit()
        if (committed) ringing else null
    }

    fun removeRingingAndAppendStopped(
        expected: AlarmRecord,
        occurredAtEpochMs: Long = System.currentTimeMillis(),
    ): AlarmRecord? = synchronized(lock) {
        val records = readRecords()
        val current = records[expected.reminderId]
        if (current != expected || current.state != AlarmRecord.STATE_RINGING) {
            return@synchronized null
        }
        val removed = records.remove(expected.reminderId) ?: return@synchronized null
        val events =
            appendAndTrim(
                readEvents(),
                AlarmEvent(
                    reminderId = removed.reminderId,
                    taskId = removed.taskId,
                    scheduleRevision = removed.scheduleRevision,
                    type = "stopped",
                    occurredAtEpochMs = occurredAtEpochMs,
                ),
            )
        val committed =
            preferences.edit()
                .putString(KEY_RECORDS, encodeRecords(records))
                .putString(KEY_EVENTS, encodeEvents(events))
                .commit()
        if (committed) removed else null
    }

    fun appendEvent(event: AlarmEvent): Boolean = synchronized(lock) {
        preferences.edit()
            .putString(KEY_EVENTS, encodeEvents(appendAndTrim(readEvents(), event)))
            .commit()
    }

    fun events(): List<AlarmEvent> = synchronized(lock) {
        readEvents()
    }

    fun acknowledgeEvents(eventIds: Set<String>): Boolean = synchronized(lock) {
        if (eventIds.isEmpty()) return@synchronized true
        val remaining = readEvents().filterNot { eventIds.contains(it.eventId) }
        val editor = preferences.edit()
        if (remaining.isEmpty()) {
            editor.remove(KEY_EVENTS)
        } else {
            editor.putString(KEY_EVENTS, encodeEvents(remaining))
        }
        editor.commit()
    }

    /**
     * Clears a pre-reboot ringing session and records its terminal events exactly once per boot.
     * The boot token is stored in the same device-protected transaction as the records/events.
     */
    fun recoverAfterBoot(bootToken: String, occurredAtEpochMs: Long): Int =
        recoverRingingAfterInterruption(
            markerKey = KEY_LAST_RECOVERED_BOOT,
            interruptionToken = bootToken,
            occurredAtEpochMs = occurredAtEpochMs,
        )

    fun recoverAfterPackageReplacement(
        packageToken: String,
        occurredAtEpochMs: Long,
    ): Int =
        recoverRingingAfterInterruption(
            markerKey = KEY_LAST_RECOVERED_PACKAGE,
            interruptionToken = packageToken,
            occurredAtEpochMs = occurredAtEpochMs,
        )

    private fun recoverRingingAfterInterruption(
        markerKey: String,
        interruptionToken: String,
        occurredAtEpochMs: Long,
    ): Int = synchronized(lock) {
        if (preferences.getString(markerKey, null) == interruptionToken) {
            return@synchronized 0
        }
        val records = readRecords()
        val ringing = records.values.filter { it.state == AlarmRecord.STATE_RINGING }
        ringing.forEach { records.remove(it.reminderId) }
        val events =
            (
                readEvents() +
                    ringing.map { record ->
                        AlarmEvent(
                            reminderId = record.reminderId,
                            taskId = record.taskId,
                            scheduleRevision = record.scheduleRevision,
                            type = "stopped",
                            occurredAtEpochMs = occurredAtEpochMs,
                        )
                    }
                ).takeLast(MAX_EVENTS)
        val editor = preferences.edit().putString(markerKey, interruptionToken)
        if (ringing.isNotEmpty()) {
            editor
                .putString(KEY_RECORDS, encodeRecords(records))
                .putString(KEY_EVENTS, encodeEvents(events))
        }
        if (editor.commit()) ringing.size else 0
    }

    private fun readRecords(): LinkedHashMap<String, AlarmRecord> =
        decodeRecords(preferences.getString(KEY_RECORDS, null))

    private fun writeRecords(records: Map<String, AlarmRecord>): Boolean =
        preferences.edit().putString(KEY_RECORDS, encodeRecords(records)).commit()

    private fun readEvents(): List<AlarmEvent> =
        decodeEvents(preferences.getString(KEY_EVENTS, null))

    companion object {
        private const val PREFERENCES_NAME = "danggui_native_alarm_store_v1"
        private const val KEY_RECORDS = "records"
        private const val KEY_EVENTS = "events"
        private const val KEY_DEVICE_STORAGE_MIGRATED = "device_storage_migrated"
        private const val KEY_LAST_RECOVERED_BOOT = "last_recovered_boot"
        private const val KEY_LAST_RECOVERED_PACKAGE = "last_recovered_package"
        private const val MAX_EVENTS = 200
        private val lock = Any()

        private fun openPreferences(context: Context): SharedPreferences {
            val applicationContext = context.applicationContext
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                return applicationContext.getSharedPreferences(
                    PREFERENCES_NAME,
                    Context.MODE_PRIVATE,
                )
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
            if (devicePreferences.getBoolean(KEY_DEVICE_STORAGE_MIGRATED, false)) return
            val credentialPreferences =
                context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val deviceRecords =
                decodeRecords(devicePreferences.getString(KEY_RECORDS, null))

            val mergedRecords =
                decodeRecords(credentialPreferences.getString(KEY_RECORDS, null)).apply {
                    deviceRecords.forEach { (reminderId, deviceRecord) ->
                        val credentialRecord = this[reminderId]
                        if (
                            credentialRecord == null ||
                                deviceRecord.scheduleRevision >= credentialRecord.scheduleRevision
                        ) {
                            this[reminderId] = deviceRecord
                        }
                    }
                }
            val mergedEvents =
                (
                    decodeEvents(credentialPreferences.getString(KEY_EVENTS, null)) +
                        decodeEvents(devicePreferences.getString(KEY_EVENTS, null))
                    ).distinctBy(AlarmEvent::eventId)
                    .sortedBy(AlarmEvent::occurredAtEpochMs)
                    .takeLast(MAX_EVENTS)

            val editor =
                devicePreferences.edit()
                    .putBoolean(KEY_DEVICE_STORAGE_MIGRATED, true)
            if (mergedRecords.isNotEmpty()) {
                editor.putString(KEY_RECORDS, encodeRecords(mergedRecords))
            }
            if (mergedEvents.isNotEmpty()) {
                editor.putString(KEY_EVENTS, encodeEvents(mergedEvents))
            }
            editor.commit()
        }

        private fun decodeRecords(encoded: String?): LinkedHashMap<String, AlarmRecord> {
            if (encoded == null) return linkedMapOf()
            return runCatching {
                val root = JSONObject(encoded)
                val records = linkedMapOf<String, AlarmRecord>()
                val keys = root.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    records[key] = AlarmRecord.fromJson(root.getJSONObject(key))
                }
                records
            }.getOrDefault(linkedMapOf())
        }

        private fun encodeRecords(records: Map<String, AlarmRecord>): String {
            val root = JSONObject()
            records.forEach { (key, record) -> root.put(key, record.toJson()) }
            return root.toString()
        }

        private fun decodeEvents(encoded: String?): List<AlarmEvent> {
            if (encoded == null) return emptyList()
            return runCatching {
                val array = JSONArray(encoded)
                buildList {
                    repeat(array.length()) { index ->
                        add(AlarmEvent.fromJson(array.getJSONObject(index)))
                    }
                }
            }.getOrDefault(emptyList())
        }

        private fun encodeEvents(events: List<AlarmEvent>): String =
            JSONArray(events.map(AlarmEvent::toJson)).toString()

        private fun appendAndTrim(events: List<AlarmEvent>, event: AlarmEvent): List<AlarmEvent> =
            (events + event).takeLast(MAX_EVENTS)
    }
}
