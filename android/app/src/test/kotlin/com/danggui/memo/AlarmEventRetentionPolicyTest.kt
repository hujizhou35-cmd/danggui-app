package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmEventRetentionPolicyTest {
    @Test
    fun `more than two hundred diagnostics cannot evict unacknowledged business events`() {
        val delivered = event("delivered", "11111111-2222-4333-8444-555555555555")
        val diagnostics =
            (1..250).map { index ->
                event("error", null, eventId = "diagnostic-$index", occurredAt = index.toLong())
            }
        val stopped =
            event(
                "stopped",
                "11111111-2222-4333-8444-555555555555",
                eventId = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
                occurredAt = 300L,
            )

        val retained = AlarmEventRetentionPolicy.retain(listOf(delivered) + diagnostics + stopped)

        assertEquals(202, retained.size)
        assertTrue(retained.contains(delivered))
        assertTrue(retained.contains(stopped))
        assertEquals(200, retained.count { it.type == "error" })
        assertEquals("diagnostic-51", retained.first { it.type == "error" }.eventId)
    }

    @Test
    fun `different unacknowledged business event ids never collapse`() {
        val first = event("missed", null, eventId = "first", occurredAt = 1L)
        val latest = event("missed", null, eventId = "latest", occurredAt = 2L)

        val retained = AlarmEventRetentionPolicy.retain(listOf(first, latest))

        assertEquals(listOf(first, latest), retained)
    }

    @Test
    fun `exact duplicate business event id is one independently ackable event`() {
        val first = event("missed", null, eventId = "same", occurredAt = 1L)
        val recoveredCopy = first.copy(occurredAtEpochMs = 2L)

        val retained = AlarmEventRetentionPolicy.retain(listOf(first, recoveredCopy))

        assertEquals(listOf(recoveredCopy), retained)
    }

    @Test
    fun `standalone v114 terminal survives diagnostic pressure and migrates safely`() {
        val stopped =
            event(
                "stopped",
                "11111111-2222-4333-8444-555555555555",
                eventId = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
                occurredAt = 1L,
            )
        val retained =
            AlarmEventRetentionPolicy.retain(
                listOf(stopped) +
                    (1..250).map { index ->
                        event(
                            "error",
                            null,
                            eventId = "diagnostic-$index",
                            occurredAt = index + 1L,
                        )
                    },
            )

        assertEquals(
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L),
            AlarmIdentityPolicy.migratedV114EventSessionId(
                stopped,
                emptyList(),
                retained,
            ),
        )
    }

    @Test
    fun `business queue accepts 4096 unique events and rejects the 4097th`() {
        val atCapacity =
            (0 until AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS).map(::uniqueBusinessEvent)

        assertEquals(
            AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS,
            AlarmEventRetentionPolicy.retainWithinCapacity(atCapacity)?.size,
        )
        assertNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(
                atCapacity + uniqueBusinessEvent(AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS),
            ),
        )
    }

    @Test
    fun `durable pending reservation survives reconstruction and ack releases its slot`() {
        val queued =
            (0 until AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS - 1)
                .map(::uniqueBusinessEvent)
        val reserved = uniqueBusinessEvent(AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS - 1)
            .copy(type = "snoozed")
        // Reconstruct the durable record instead of retaining an object alias,
        // modelling the values AlarmStore reads after a process restart.
        val restoredPending =
            AlarmRecord(
                reminderId = "pending-reminder",
                taskId = "pending-task",
                scheduleRevision = 42L,
                triggerAtEpochMs = 1_000L,
                title = "",
                body = "",
                localeTag = "en",
                vibrationEnabled = true,
                defaultSnoozeMinutes = 10,
                state = AlarmRecord.STATE_PENDING,
                reservedBusinessEvents = listOf(reserved.copy()),
            )
        val restoredReservations =
            AlarmEventRetentionPolicy.reservationsFrom(listOf(restoredPending))
        assertEquals(listOf(reserved), restoredReservations)
        assertNotNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(queued, restoredReservations),
        )

        val overflow = uniqueBusinessEvent(AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS)
        assertNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(
                queued,
                restoredReservations + overflow,
            ),
        )

        val acknowledged =
            AlarmEventRetentionPolicy.acknowledge(queued, setOf(queued.first().eventId))
        assertNotNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(
                acknowledged,
                restoredReservations + overflow,
            ),
        )
    }

    @Test
    fun `a reservation for an already persisted event id does not consume another slot`() {
        val atCapacity =
            (0 until AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS).map(::uniqueBusinessEvent)
        val duplicateIdReservation = atCapacity.first().copy()

        assertNotNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(
                atCapacity,
                listOf(duplicateIdReservation),
            ),
        )
    }

    @Test
    fun `same reminder revision and type with a different event id needs another slot`() {
        val atCapacity =
            (0 until AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS).map(::uniqueBusinessEvent)
        val distinctUnacknowledgedEvent =
            atCapacity.first().copy(eventId = "another-unacknowledged-id")

        assertNull(
            AlarmEventRetentionPolicy.retainWithinCapacity(
                atCapacity,
                listOf(distinctUnacknowledgedEvent),
            ),
        )
    }

    @Test
    fun `same revision events from different generations remain independently ackable`() {
        val generationA = "11111111-1111-4111-8111-111111111111"
        val generationB = "22222222-2222-4222-8222-222222222222"
        val oldGeneration =
            event("stopped", "old", eventId = "old-event").copy(
                deviceGeneration = generationA,
            )
        val newGeneration =
            event("stopped", "new", eventId = "new-event").copy(
                deviceGeneration = generationB,
            )

        assertEquals(
            listOf(oldGeneration, newGeneration),
            AlarmEventRetentionPolicy.retain(listOf(oldGeneration, newGeneration)),
        )
    }

    private fun event(
        type: String,
        sessionId: String?,
        eventId: String = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
        occurredAt: Long = 0L,
    ): AlarmEvent =
        AlarmEvent(
            eventId = eventId,
            reminderId = "r1",
            taskId = "t1",
            scheduleRevision = 7L,
            type = type,
            occurredAtEpochMs = occurredAt,
            sessionId = sessionId,
        )

    private fun uniqueBusinessEvent(index: Int): AlarmEvent =
        AlarmEvent(
            eventId = "business-$index",
            reminderId = "reminder-$index",
            taskId = "task-$index",
            scheduleRevision = index.toLong(),
            type = "delivered",
            occurredAtEpochMs = index.toLong(),
            sessionId = "session-$index",
        )
}
