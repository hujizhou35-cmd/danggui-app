package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmGenerationPolicyTest {
    private val generationA = "11111111-1111-4111-8111-111111111111"
    private val generationB = "22222222-2222-4222-8222-222222222222"

    @Test
    fun `missing persisted generation preserves only legacy v1_1_4 alarms`() {
        assertTrue(AlarmGenerationPolicy.isActive(null, null))
        assertFalse(AlarmGenerationPolicy.isActive(null, generationA))
    }

    @Test
    fun `legacy to generated activation retires the legacy platform record`() {
        val legacy = record(reminderId = "legacy", generation = null)
        val generated = record(reminderId = "new", generation = generationA)

        assertEquals(
            listOf(legacy),
            AlarmGenerationPolicy.recordsToRetire(listOf(legacy, generated), generationA),
        )
    }

    @Test
    fun `generation A to B activation rejects old pending intent and service identity`() {
        val old = record(reminderId = "old", generation = generationA)
        val current = record(reminderId = "current", generation = generationB)
        val retired =
            AlarmGenerationPolicy.recordsToRetire(listOf(old, current), generationB)

        assertEquals(listOf(old), retired)
        assertFalse(AlarmGenerationPolicy.isActive(generationB, old.deviceGeneration))
        assertTrue(AlarmGenerationPolicy.isActive(generationB, current.deviceGeneration))
    }

    @Test
    fun `delayed generation A cancel is a no-op after generation B activation`() {
        assertFalse(AlarmGenerationPolicy.isActive(generationB, generationA))
        assertTrue(AlarmGenerationPolicy.isActive(generationB, generationB))
        assertFalse(AlarmGenerationPolicy.isActive(generationB, null))
    }

    @Test
    fun `A to B cleanup failure preserves LKG and B to A selects future A route again`() {
        val futureA = record(reminderId = "a", generation = generationA)
        val futureB = record(reminderId = "b", generation = generationB)
        val mirror = listOf(futureA, futureB)

        val bestEffortCleanup =
            AlarmGenerationPolicy.recordsToRetire(mirror, generationB)
        assertEquals(listOf(futureA), bestEffortCleanup)
        // A failed AlarmManager cancellation never mutates the durable mirror.
        assertEquals(listOf(futureA, futureB), mirror)

        val rollbackProjection =
            AlarmGenerationPolicy.recordsForActiveGeneration(mirror, generationA)
        assertEquals(listOf(futureA), rollbackProjection)
        assertEquals(AlarmRecord.STATE_SCHEDULED, rollbackProjection.single().state)

        val eventA = event(reminderId = "a", generation = generationA)
        val eventB = event(reminderId = "b", generation = generationB)
        val eventMirror = listOf(eventA, eventB)
        assertEquals(
            listOf(eventB),
            AlarmGenerationPolicy.eventsForActiveGeneration(eventMirror, generationB),
        )
        assertEquals(eventMirror, listOf(eventA, eventB))
        assertEquals(
            listOf(eventA),
            AlarmGenerationPolicy.eventsForActiveGeneration(eventMirror, generationA),
        )
    }

    @Test
    fun `persisted generation survives process restart and remains canonical`() {
        val persisted = AlarmGenerationPolicy.storageToken(generationA.uppercase())

        assertEquals(generationA, persisted)
        assertEquals(generationA, AlarmGenerationPolicy.restoredGeneration(persisted))
        assertTrue(AlarmGenerationPolicy.isActive(persisted, generationA))
        assertFalse(AlarmGenerationPolicy.isActive(persisted, generationB))
        assertEquals(generationA, AlarmGenerationPolicy.normalizedStorageToken(persisted))
        assertNull(AlarmGenerationPolicy.normalizedStorageToken("corrupted"))
        val invalid =
            AlarmGenerationPolicy.recoveredStorageToken(
                primaryPresent = true,
                primaryValue = "corrupted",
                backupPresent = true,
                backupValue = "also-corrupted",
            )
        assertEquals(AlarmGenerationPolicy.INVALID_STORAGE_TOKEN, invalid)
        assertFalse(AlarmGenerationPolicy.isRecoverable(invalid))
        assertFalse(AlarmGenerationPolicy.isActive(invalid, null))
        assertNull(
            AlarmGenerationPolicy.restoredGeneration(
                AlarmGenerationPolicy.storageToken(deviceGeneration = null),
            ),
        )
    }

    @Test
    fun `active event projection filters stale generation without deleting its LKG journal`() {
        val old = event(reminderId = "old", generation = generationA)
        val current = event(reminderId = "current", generation = generationB)
        val durableMirror = listOf(old, current)

        assertEquals(
            listOf(current),
            AlarmGenerationPolicy.eventsForActiveGeneration(durableMirror, generationB),
        )
        assertEquals(listOf(old, current), durableMirror)
    }

    private fun record(reminderId: String, generation: String?): AlarmRecord =
        AlarmRecord(
            reminderId = reminderId,
            taskId = "task-$reminderId",
            scheduleRevision = 1,
            deviceGeneration = generation,
            triggerAtEpochMs = 10_000,
            title = "Alarm",
            body = "Body",
            localeTag = "en",
            vibrationEnabled = true,
            defaultSnoozeMinutes = 10,
        )

    private fun event(reminderId: String, generation: String?): AlarmEvent =
        AlarmEvent(
            eventId = "event-$reminderId",
            reminderId = reminderId,
            taskId = "task-$reminderId",
            scheduleRevision = 1,
            deviceGeneration = generation,
            type = "delivered",
            occurredAtEpochMs = 10_000,
        )
}
