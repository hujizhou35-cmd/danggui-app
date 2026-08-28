package com.danggui.memo

internal data class AlarmTerminalFlush(
    val records: List<AlarmRecord>,
    val events: List<AlarmEvent>,
)

/** Pure crash-safe transition rules for stopping an already-ringing alarm. */
internal object AlarmTerminalEventPolicy {
    fun terminalize(ringing: AlarmRecord, event: AlarmEvent): AlarmRecord {
        require(ringing.state == AlarmRecord.STATE_RINGING)
        require(event.type == "stopped")
        require(event.reminderId == ringing.reminderId)
        require(event.scheduleRevision == ringing.scheduleRevision)
        require(event.deviceGeneration == ringing.deviceGeneration)
        return ringing.copy(
            state = AlarmRecord.STATE_TERMINAL_PENDING,
            reservedBusinessEvents = listOf(event),
        )
    }

    /**
     * Prevents a last-known-good generation's old ringing session from being
     * resurrected when restore rolls platform ownership back to that mirror.
     * The caller persists this projection atomically with the generation fence.
     */
    fun terminalizeRestoredGeneration(
        records: List<AlarmRecord>,
        activeGeneration: String?,
        occurredAtEpochMs: Long,
    ): List<AlarmRecord> =
        records.map { record ->
            if (
                record.deviceGeneration == activeGeneration &&
                    record.state == AlarmRecord.STATE_RINGING
            ) {
                terminalize(
                    record,
                    AlarmEvent(
                        reminderId = record.reminderId,
                        taskId = record.taskId,
                        scheduleRevision = record.scheduleRevision,
                        deviceGeneration = record.deviceGeneration,
                        type = "stopped",
                        occurredAtEpochMs = occurredAtEpochMs,
                        sessionId = record.sessionId,
                        detailCode = "generation_interruption",
                    ),
                )
            } else {
                record
            }
        }

    /**
     * Flushes as many active-generation terminal tombstones as capacity allows.
     * A tombstone is removed only in the same projection that persists its
     * exact stopped event.
     */
    fun flush(
        records: List<AlarmRecord>,
        events: List<AlarmEvent>,
        activeGeneration: String?,
    ): AlarmTerminalFlush {
        val retainedRecords = records.toMutableList()
        var retainedEvents = events
        val scheduledReservations =
            AlarmEventRetentionPolicy.reservationsFrom(
                records.filter { it.deviceGeneration == activeGeneration },
            )
        records
            .filter {
                it.state == AlarmRecord.STATE_TERMINAL_PENDING &&
                    it.deviceGeneration == activeGeneration
            }
            .forEach { tombstone ->
                val terminalEvent = tombstone.reservedBusinessEvents.singleOrNull()
                    ?: return@forEach
                val activeEvents =
                    retainedEvents.filter { it.deviceGeneration == activeGeneration }
                val inactiveEvents =
                    retainedEvents.filterNot { it.deviceGeneration == activeGeneration }
                val nextActive =
                    AlarmEventRetentionPolicy.retainWithinCapacity(
                        activeEvents + terminalEvent,
                        scheduledReservations,
                    ) ?: return@forEach
                retainedEvents = inactiveEvents + nextActive
                retainedRecords.remove(tombstone)
            }
        return AlarmTerminalFlush(retainedRecords, retainedEvents)
    }
}
