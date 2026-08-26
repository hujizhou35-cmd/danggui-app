package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmTransactionPolicyTest {
    @Test
    fun `permission loss retains pending durable record`() {
        assertEquals(
            AlarmRecoveryDecision.RETAIN_DURABLE,
            AlarmTransactionPolicy.recoveryDecision(
                triggerAtEpochMs = 20_000L,
                nowEpochMs = 10_000L,
                exactAlarmAllowed = false,
            ),
        )
    }

    @Test
    fun `pending transaction is installed when permission returns`() {
        assertEquals(
            AlarmRecoveryDecision.INSTALL,
            AlarmTransactionPolicy.recoveryDecision(
                triggerAtEpochMs = 20_000L,
                nowEpochMs = 10_000L,
                exactAlarmAllowed = true,
            ),
        )
    }

    @Test
    fun `expired transaction is terminal even without permission`() {
        assertEquals(
            AlarmRecoveryDecision.EXPIRE,
            AlarmTransactionPolicy.recoveryDecision(
                triggerAtEpochMs = 10_000L,
                nowEpochMs =
                    10_000L + AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS + 1L,
                exactAlarmAllowed = false,
            ),
        )
    }

    @Test
    fun `cancel tombstone can never be rearmed`() {
        assertTrue(AlarmTransactionPolicy.canRearm("pending"))
        assertTrue(AlarmTransactionPolicy.canRearm("scheduled"))
        assertFalse(AlarmTransactionPolicy.canRearm("cancel_pending"))
    }

    @Test
    fun `one install or commit failure keeps pending state`() {
        assertEquals(
            AlarmDurableState.PENDING,
            AlarmTransactionPolicy.afterScheduleAttempt(
                systemInstallSucceeded = false,
                durableCommitSucceeded = false,
            ),
        )
        assertEquals(
            AlarmDurableState.PENDING,
            AlarmTransactionPolicy.afterScheduleAttempt(
                systemInstallSucceeded = true,
                durableCommitSucceeded = false,
            ),
        )
        assertEquals(
            AlarmDurableState.SCHEDULED,
            AlarmTransactionPolicy.afterScheduleAttempt(
                systemInstallSucceeded = true,
                durableCommitSucceeded = true,
            ),
        )
    }

    @Test
    fun `cancel stays tombstoned until system and durable retirement succeed`() {
        assertEquals(
            AlarmDurableState.CANCEL_PENDING,
            AlarmTransactionPolicy.afterCancelAttempt(
                systemCancelSucceeded = false,
                durableFinalizeSucceeded = false,
            ),
        )
        assertEquals(
            AlarmDurableState.CANCEL_PENDING,
            AlarmTransactionPolicy.afterCancelAttempt(
                systemCancelSucceeded = true,
                durableFinalizeSucceeded = false,
            ),
        )
        assertEquals(
            AlarmDurableState.REMOVED,
            AlarmTransactionPolicy.afterCancelAttempt(
                systemCancelSucceeded = true,
                durableFinalizeSucceeded = true,
            ),
        )
    }
}
