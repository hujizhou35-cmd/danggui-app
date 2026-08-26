package com.danggui.memo

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmIdentityPolicyTest {
    @Test
    fun `matching revision and session accepts current action`() {
        assertTrue(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, "s1", "r1", 7L, "s1"),
        )
    }

    @Test
    fun `stale revision cannot stop a newer alarm`() {
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 8L, "s2", "r1", 7L, "s2"),
        )
    }

    @Test
    fun `stale session cannot snooze a restarted alarm`() {
        assertFalse(
            AlarmIdentityPolicy.matchesCurrent("r1", 7L, "s2", "r1", 7L, "s1"),
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
    fun `replacement must advance revision`() {
        assertTrue(AlarmIdentityPolicy.canReplace(7L, 8L))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, 7L))
        assertFalse(AlarmIdentityPolicy.canReplace(7L, 6L))
    }
}
