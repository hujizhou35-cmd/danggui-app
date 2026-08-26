package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Test

class AlarmDeliveryPolicyTest {
    @Test
    fun `delivery at trigger is accepted`() {
        assertEquals(
            AlarmDeliveryDecision.DELIVER,
            AlarmDeliveryPolicy.decide(triggerAtEpochMs = 1_000L, nowEpochMs = 1_000L),
        )
    }

    @Test
    fun `delivery through fifteen minute boundary is accepted`() {
        val trigger = 10_000L
        assertEquals(
            AlarmDeliveryDecision.DELIVER,
            AlarmDeliveryPolicy.decide(
                triggerAtEpochMs = trigger,
                nowEpochMs = trigger + AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS,
            ),
        )
    }

    @Test
    fun `delivery after fifteen minute boundary is missed`() {
        val trigger = 10_000L
        assertEquals(
            AlarmDeliveryDecision.MISSED,
            AlarmDeliveryPolicy.decide(
                triggerAtEpochMs = trigger,
                nowEpochMs = trigger + AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS + 1L,
            ),
        )
    }

    @Test
    fun `early service invocation cannot mark an alarm ringing`() {
        assertEquals(
            AlarmDeliveryDecision.TOO_EARLY,
            AlarmDeliveryPolicy.decide(triggerAtEpochMs = 10_001L, nowEpochMs = 10_000L),
        )
    }

    @Test
    fun `cutoff uses the same recovery window`() {
        assertEquals(
            10_000L + AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS,
            AlarmDeliveryPolicy.cutoffAtEpochMs(10_000L),
        )
    }

    @Test
    fun `backwards wall clock cannot extend monotonic hard cutoff`() {
        val startedElapsed = 50_000L
        assertEquals(
            0L,
            AlarmDeliveryPolicy.remainingRingingMillis(
                triggerAtEpochMs = 1_000_000L,
                ringStartedElapsedRealtimeMs = startedElapsed,
                nowEpochMs = 900_000L,
                nowElapsedRealtimeMs =
                    startedElapsed + AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS,
            ),
        )
    }

    @Test
    fun `late delivery keeps only remaining wall clock window`() {
        val grace = AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS
        assertEquals(
            1_000L,
            AlarmDeliveryPolicy.remainingRingingMillis(
                triggerAtEpochMs = 10_000L,
                ringStartedElapsedRealtimeMs = 5_000L,
                nowEpochMs = 10_000L + grace - 1_000L,
                nowElapsedRealtimeMs = 5_000L,
            ),
        )
    }
}
