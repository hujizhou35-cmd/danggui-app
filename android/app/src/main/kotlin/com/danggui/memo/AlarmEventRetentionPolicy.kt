package com.danggui.memo

/**
 * Keeps compare-and-swap business events until Flutter acknowledges them while
 * bounding only lossy diagnostics. A business event remains independently
 * acknowledgeable until Flutter acknowledges its immutable event ID. Exact
 * duplicate IDs are one logical event and may be collapsed after recovery.
 */
internal object AlarmEventRetentionPolicy {
    const val MAX_DIAGNOSTIC_EVENTS = 200
    const val MAX_BUSINESS_EVENTS = 4_096

    private val businessTypes = setOf("delivered", "missed", "stopped", "snoozed")

    fun retain(events: List<AlarmEvent>): List<AlarmEvent> {
        return requireNotNull(retainWithinCapacity(events)) {
            "Unacknowledged alarm business-event capacity is exhausted."
        }
    }

    /**
     * Returns the lossy-diagnostic projection when every unacknowledged
     * business event and durable reservation still fits. A null result is
     * back-pressure: callers must leave the owning alarm record unchanged.
     */
    fun retainWithinCapacity(
        events: List<AlarmEvent>,
        reservedBusinessEvents: List<AlarmEvent> = emptyList(),
    ): List<AlarmEvent>? {
        if (events.isEmpty() && reservedBusinessEvents.isEmpty()) return emptyList()
        val newestBusinessIndex = linkedMapOf<String, Int>()
        val diagnosticIndices = mutableListOf<Int>()
        events.forEachIndexed { index, event ->
            if (event.type in businessTypes) {
                newestBusinessIndex[event.eventId] = index
            } else {
                diagnosticIndices += index
            }
        }
        val occupiedBusinessEventIds = newestBusinessIndex.keys.toMutableSet()
        reservedBusinessEvents
            .asSequence()
            .filter(::isBusinessEvent)
            .map(AlarmEvent::eventId)
            .forEach(occupiedBusinessEventIds::add)
        if (occupiedBusinessEventIds.size > MAX_BUSINESS_EVENTS) return null
        val retainedIndices =
            buildSet {
                addAll(newestBusinessIndex.values)
                addAll(diagnosticIndices.takeLast(MAX_DIAGNOSTIC_EVENTS))
            }
        return events.filterIndexed { index, _ -> index in retainedIndices }
    }

    fun isBusinessEvent(event: AlarmEvent): Boolean = event.type in businessTypes

    fun reservationsFrom(records: Iterable<AlarmRecord>): List<AlarmEvent> =
        records
            .asSequence()
            .filter { it.state == AlarmRecord.STATE_PENDING }
            .flatMap { it.reservedBusinessEvents.asSequence() }
            .filter(::isBusinessEvent)
            .toList()

    fun acknowledge(events: List<AlarmEvent>, eventIds: Set<String>): List<AlarmEvent> =
        if (eventIds.isEmpty()) events else events.filterNot { it.eventId in eventIds }
}
