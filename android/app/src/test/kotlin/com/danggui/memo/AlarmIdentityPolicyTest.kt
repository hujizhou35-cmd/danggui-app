package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmIdentityPolicyTest {
    @Test
    fun `deterministic session matches shared Swift and Dart vectors`() {
        assertEquals(
            "cd5bd2da-9bbc-58bd-a180-035d29ea7098",
            AlarmIdentityPolicy.deterministicSessionId("reminder-1", 1L),
        )
        assertEquals(
            "0e210420-bdf8-57ba-a6e5-c5b048e22881",
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L),
        )
        assertEquals(
            "9c41e0b6-c7b9-5488-a7a2-0b8885caae3b",
            AlarmIdentityPolicy.deterministicSessionId("提醒-😀", 42L),
        )
        val generation = "99999999-9999-4999-8999-999999999999"
        assertEquals(
            "7583af8c-382e-5b5d-ae26-48dd1489d676",
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L, generation),
        )
        assertEquals(
            "7583af8c-382e-5b5d-ae26-48dd1489d676",
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L, generation.uppercase()),
        )
    }

    @Test
    fun `matching revision and session accepts current action`() {
        val session = AlarmIdentityPolicy.deterministicSessionId("r1", 7L)
        assertTrue(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, session, "r1", 7L, session),
        )
    }

    @Test
    fun `stale revision cannot stop a newer alarm`() {
        val session = AlarmIdentityPolicy.deterministicSessionId("r1", 8L)
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 8L, session, "r1", 7L, session),
        )
    }

    @Test
    fun `stale session cannot snooze a restarted alarm`() {
        val current = AlarmIdentityPolicy.deterministicSessionId("r1", 7L)
        val stale = AlarmIdentityPolicy.deterministicSessionId("r1", 6L)
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, current, "r1", 7L, stale),
        )
    }

    @Test
    fun `actions compare the persisted session instead of rederiving legacy identity`() {
        assertTrue(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, "forged", "r1", 7L, "forged"),
        )
    }

    @Test
    fun `same revision generation rejects old session and accepts new session`() {
        val oldSession =
            AlarmIdentityPolicy.deterministicSessionId(
                "r1",
                7L,
                "11111111-1111-4111-8111-111111111111",
            )
        val newSession =
            AlarmIdentityPolicy.deterministicSessionId(
                "r1",
                7L,
                "22222222-2222-4222-8222-222222222222",
            )
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, newSession, "r1", 7L, oldSession),
        )
        assertTrue(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, newSession, "r1", 7L, newSession),
        )
    }

    @Test
    fun `one-shot v114 ringing alias accepts only its exact reminder revision`() {
        val current = AlarmIdentityPolicy.deterministicSessionId("r1", 7L)
        val legacy = "11111111-2222-4333-8444-555555555555"
        assertTrue(
            AlarmIdentityPolicy.matchesCurrent(
                "r1",
                7L,
                current,
                "r1",
                7L,
                legacy,
                recordLegacySessionId = legacy,
            ),
        )
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent(
                "r1",
                7L,
                current,
                "r1",
                8L,
                legacy,
                recordLegacySessionId = legacy,
            ),
        )
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, current, "r1", 7L, legacy),
        )
    }

    @Test
    fun `missing session cannot target a current record`() {
        assertFalse(
            AlarmIdentityPolicy.matchesLegacy("r1", 7L, "s2", "r1", null),
        )
    }

    @Test
    fun `legacy reminder-only action targets only a legacy record`() {
        assertTrue(
            AlarmIdentityPolicy.matchesLegacy("r1", 7L, null, "r1", null),
        )
    }

    @Test
    fun `partial current identity is rejected`() {
        assertFalse(AlarmIdentityPolicy.hasCompleteCurrentIdentity("r1", 7L, null))
        assertFalse(AlarmIdentityPolicy.hasCompleteCurrentIdentity("r1", null, "s1"))
        assertTrue(AlarmIdentityPolicy.hasCompleteCurrentIdentity("r1", 7L, "s1"))
    }

    @Test
    fun `replacement advances revision or changes to a generated device projection`() {
        val generationA = "11111111-1111-4111-8111-111111111111"
        val generationB = "22222222-2222-4222-8222-222222222222"
        assertTrue(AlarmIdentityPolicy.canReplace(7L, null, 8L, null))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, null, 7L, null))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, null, 6L, generationB))
        assertTrue(AlarmIdentityPolicy.canReplace(7L, null, 7L, generationA))
        assertTrue(AlarmIdentityPolicy.canReplace(7L, generationA, 7L, generationB))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, generationA, 7L, generationA))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, generationA, 7L, null))
    }

    @Test
    fun `device generation accepts canonical UUID case and rejects loose forms`() {
        assertEquals(
            "99999999-9999-4999-8999-999999999999",
            AlarmIdentityPolicy.canonicalDeviceGeneration(
                "99999999-9999-4999-8999-999999999999".uppercase(),
            ),
        )
        assertNull(AlarmIdentityPolicy.canonicalDeviceGeneration("99999999-9999-4999"))
        assertNull(
            AlarmIdentityPolicy.canonicalDeviceGeneration(
                " 99999999-9999-4999-8999-999999999999",
            ),
        )
        assertNull(AlarmIdentityPolicy.canonicalDeviceGeneration("not-a-uuid"))
    }

    @Test
    fun `v114 delivered stopped and repeated migration use deterministic session`() {
        val legacySession = "11111111-2222-4333-8444-555555555555"
        val delivered =
            event(
                eventId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                type = "delivered",
                sessionId = legacySession,
            )
        val stopped =
            event(
                eventId = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
                type = "stopped",
                sessionId = legacySession,
            )
        val events = listOf(delivered, stopped)
        val expected = AlarmIdentityPolicy.deterministicSessionId("r1", 7L)

        assertEquals(
            expected,
            AlarmIdentityPolicy.migratedV114EventSessionId(delivered, emptyList(), events),
        )
        assertEquals(
            expected,
            AlarmIdentityPolicy.migratedV114EventSessionId(stopped, emptyList(), events),
        )
        assertEquals(
            expected,
            AlarmIdentityPolicy.migratedV114EventSessionId(
                stopped.copy(sessionId = expected),
                emptyList(),
                listOf(
                    delivered.copy(sessionId = expected),
                    stopped.copy(sessionId = expected),
                ),
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114EventSessionId(
                delivered.copy(
                    deviceGeneration = "99999999-9999-4999-8999-999999999999",
                ),
                emptyList(),
                events,
            ),
        )
    }

    @Test
    fun `v114 snooze migrates only with delivered pair and exact successor`() {
        val legacySession = "11111111-2222-4333-8444-555555555555"
        val delivered =
            event(
                eventId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                type = "delivered",
                sessionId = legacySession,
            )
        val snoozed =
            event(
                eventId = "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff",
                type = "snoozed",
                sessionId = legacySession,
                nextTriggerAtEpochMs = 2_000_000L,
            )
        val successor = record(revision = 8L, triggerAtEpochMs = 2_000_000L)
        val events = listOf(delivered, snoozed)

        assertEquals(
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L),
            AlarmIdentityPolicy.migratedV114EventSessionId(
                snoozed,
                listOf(successor),
                events,
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114EventSessionId(
                snoozed,
                listOf(successor.copy(reminderId = "wrong")),
                events,
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114EventSessionId(
                snoozed.copy(scheduleRevision = 6L),
                listOf(successor),
                events,
            ),
        )
    }

    @Test
    fun `v114 missed migration is restricted to an expired recovery event`() {
        val missed =
            event(
                eventId = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
                type = "missed",
                sessionId = null,
                detailCode = "recovery_window_expired",
                delayMillis = AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS + 1L,
            )
        assertEquals(
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L),
            AlarmIdentityPolicy.migratedV114EventSessionId(
                missed,
                emptyList(),
                listOf(missed),
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114EventSessionId(
                missed.copy(detailCode = "forged"),
                emptyList(),
                listOf(missed),
            ),
        )
    }

    @Test
    fun `v114 active ringing session migrates but arbitrary state does not`() {
        val legacy =
            record(
                state = AlarmRecord.STATE_RINGING,
                sessionId = "11111111-2222-4333-8444-555555555555",
            )
        assertEquals(
            AlarmIdentityPolicy.deterministicSessionId("r1", 7L),
            AlarmIdentityPolicy.migratedV114RingingSessionId(legacy),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114RingingSessionId(
                legacy.copy(state = AlarmRecord.STATE_SCHEDULED),
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114RingingSessionId(
                legacy.copy(sessionId = "forged"),
            ),
        )
        assertNull(
            AlarmIdentityPolicy.migratedV114RingingSessionId(
                legacy.copy(deviceGeneration = "99999999-9999-4999-8999-999999999999"),
            ),
        )
    }

    private fun record(
        revision: Long = 7L,
        triggerAtEpochMs: Long = 1_000_000L,
        state: String = AlarmRecord.STATE_SCHEDULED,
        sessionId: String? = null,
        deviceGeneration: String? = null,
    ): AlarmRecord =
        AlarmRecord(
            reminderId = "r1",
            taskId = "t1",
            scheduleRevision = revision,
            deviceGeneration = deviceGeneration,
            triggerAtEpochMs = triggerAtEpochMs,
            title = "title",
            body = "body",
            localeTag = "en",
            vibrationEnabled = true,
            defaultSnoozeMinutes = 10,
            state = state,
            sessionId = sessionId,
        )

    private fun event(
        eventId: String,
        type: String,
        sessionId: String?,
        nextTriggerAtEpochMs: Long? = null,
        detailCode: String? = null,
        delayMillis: Long? = null,
        deviceGeneration: String? = null,
    ): AlarmEvent =
        AlarmEvent(
            eventId = eventId,
            reminderId = "r1",
            taskId = "t1",
            scheduleRevision = 7L,
            deviceGeneration = deviceGeneration,
            type = type,
            occurredAtEpochMs = 1_500_000L,
            nextTriggerAtEpochMs = nextTriggerAtEpochMs,
            sessionId = sessionId,
            detailCode = detailCode,
            delayMillis = delayMillis,
        )
}
