package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmTerminalEventPolicyTest {
    @Test
    fun `rollback terminalizes only restored generation ringing in fence projection`() {
        val generationA = "11111111-1111-4111-8111-111111111111"
        val generationB = "22222222-2222-4222-8222-222222222222"
        val oldRinging = ringingRecord("old", generationA)
        val currentOtherGeneration = ringingRecord("other", generationB)
        val future =
            ringingRecord("future", generationA).copy(
                state = AlarmRecord.STATE_SCHEDULED,
                sessionId = null,
            )

        val projection =
            AlarmTerminalEventPolicy.terminalizeRestoredGeneration(
                listOf(oldRinging, currentOtherGeneration, future),
                activeGeneration = generationA,
                occurredAtEpochMs = 2_000,
            )

        val terminal = projection.first()
        assertEquals(AlarmRecord.STATE_TERMINAL_PENDING, terminal.state)
        assertEquals(
            "generation_interruption",
            terminal.reservedBusinessEvents.single().detailCode,
        )
        assertEquals(currentOtherGeneration, projection[1])
        assertEquals(future, projection[2])
    }

    @Test
    fun `4096 full cutoff survives reboot and app open cannot make it ring again`() {
        val generation = "11111111-1111-4111-8111-111111111111"
        val full =
            (0 until AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS).map { index ->
                AlarmEvent(
                    eventId = "queued-$index",
                    reminderId = "queued-reminder-$index",
                    taskId = "queued-task-$index",
                    scheduleRevision = index.toLong(),
                    deviceGeneration = generation,
                    type = "delivered",
                    occurredAtEpochMs = index.toLong(),
                )
            }
        val ringing = ringingRecord("ringing", generation)
        val stopped =
            AlarmEvent(
                eventId = "terminal-stopped",
                reminderId = ringing.reminderId,
                taskId = ringing.taskId,
                scheduleRevision = ringing.scheduleRevision,
                deviceGeneration = generation,
                type = "stopped",
                occurredAtEpochMs = 2_000,
                sessionId = ringing.sessionId,
                detailCode = "automatic_cutoff",
            )
        val durableTombstone = AlarmTerminalEventPolicy.terminalize(ringing, stopped).copy()

        assertEquals(AlarmRecord.STATE_TERMINAL_PENDING, durableTombstone.state)
        assertFalse(durableTombstone.state == AlarmRecord.STATE_RINGING)
        assertTrue(
            AlarmEventRetentionPolicy.reservationsFrom(listOf(durableTombstone)).isEmpty(),
        )

        val stillFull =
            AlarmTerminalEventPolicy.flush(listOf(durableTombstone), full, generation)
        assertEquals(listOf(durableTombstone), stillFull.records)
        assertEquals(full, stillFull.events)

        val afterAck =
            AlarmTerminalEventPolicy.flush(
                stillFull.records,
                AlarmEventRetentionPolicy.acknowledge(
                    stillFull.events,
                    setOf(full.first().eventId),
                ),
                generation,
            )
        assertTrue(afterAck.records.isEmpty())
        assertEquals(AlarmEventRetentionPolicy.MAX_BUSINESS_EVENTS, afterAck.events.size)
        assertTrue(afterAck.events.contains(stopped))
    }

    private fun ringingRecord(reminderId: String, generation: String): AlarmRecord =
        AlarmRecord(
            reminderId = reminderId,
            taskId = "$reminderId-task",
            scheduleRevision = 7,
            deviceGeneration = generation,
            triggerAtEpochMs = 1_000,
            title = "Alarm",
            body = "Body",
            localeTag = "en",
            vibrationEnabled = true,
            defaultSnoozeMinutes = 10,
            state = AlarmRecord.STATE_RINGING,
            sessionId = "session-$reminderId",
        )
}
