package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmDirectBootMigrationPolicyTest {
    @Test
    fun `imported v114 sessions migrate before interruption recovery consumes them`() {
        assertEquals(
            listOf(
                AlarmDirectBootStartupStep.MIGRATE_V114_SESSION_IDENTITY,
                AlarmDirectBootStartupStep.RECOVER_IMPORTED_RINGING,
            ),
            AlarmDirectBootMigrationPolicy.startupSteps,
        )
        assertFalse(AlarmDirectBootMigrationPolicy.canRecoverImportedRinging(false))
        assertTrue(AlarmDirectBootMigrationPolicy.canRecoverImportedRinging(true))
    }

    @Test
    fun `locked empty device store cannot make later credential migration look complete`() {
        val lockedBoot =
            AlarmDirectBootMigrationPolicy.decide(
                credentialRecordCount = 0,
                credentialEventCount = 0,
            )
        assertFalse(lockedBoot.resetSessionMigrationMarker)
        assertFalse(lockedBoot.resetRecoveryMarkers)
        assertFalse(lockedBoot.recoverImportedRinging)

        val afterUnlock =
            AlarmDirectBootMigrationPolicy.decide(
                credentialRecordCount = 1,
                credentialEventCount = 1,
            )
        assertTrue(afterUnlock.resetSessionMigrationMarker)
        assertTrue(afterUnlock.resetRecoveryMarkers)
        assertTrue(afterUnlock.recoverImportedRinging)

        val resetState =
            AlarmDirectBootMigrationPolicy.applyCredentialImport(
                current =
                    AlarmDirectBootMarkerState(
                        sessionMigrationComplete = true,
                        bootRecoveryToken = "boot-count:7",
                        packageRecoveryToken = "package:old",
                        importedRecoveryPending = false,
                    ),
                decision = afterUnlock,
            )
        assertFalse(resetState.sessionMigrationComplete)
        assertNull(resetState.bootRecoveryToken)
        assertNull(resetState.packageRecoveryToken)
        assertTrue(resetState.importedRecoveryPending)
    }

    @Test
    fun `credential generation wins over provisional locked boot token only for actual import`() {
        val provisionalLegacy = AlarmGenerationPolicy.LEGACY_STORAGE_TOKEN
        val credentialGeneration = "11111111-1111-4111-8111-111111111111"

        assertEquals(
            credentialGeneration,
            AlarmDirectBootMigrationPolicy.selectActiveGenerationToken(
                deviceAlarmStatePresent = false,
                credentialAlarmStatePresent = true,
                deviceToken = provisionalLegacy,
                credentialToken = credentialGeneration,
            ),
        )
        assertEquals(
            provisionalLegacy,
            AlarmDirectBootMigrationPolicy.selectActiveGenerationToken(
                deviceAlarmStatePresent = false,
                credentialAlarmStatePresent = false,
                deviceToken = provisionalLegacy,
                credentialToken = credentialGeneration,
            ),
        )
    }
}
