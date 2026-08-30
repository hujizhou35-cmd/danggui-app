package com.danggui.memo

internal data class AlarmDirectBootMigrationDecision(
    val resetSessionMigrationMarker: Boolean,
    val resetRecoveryMarkers: Boolean,
    val recoverImportedRinging: Boolean,
)

internal data class AlarmDirectBootMarkerState(
    val sessionMigrationComplete: Boolean,
    val bootRecoveryToken: String?,
    val packageRecoveryToken: String?,
    val importedRecoveryPending: Boolean,
)

internal enum class AlarmDirectBootStartupStep {
    MIGRATE_V114_SESSION_IDENTITY,
    RECOVER_IMPORTED_RINGING,
}

/** Pure ordering rule for credential -> device protected alarm migration. */
internal object AlarmDirectBootMigrationPolicy {
    val startupSteps: List<AlarmDirectBootStartupStep> =
        listOf(
            AlarmDirectBootStartupStep.MIGRATE_V114_SESSION_IDENTITY,
            AlarmDirectBootStartupStep.RECOVER_IMPORTED_RINGING,
        )

    fun canRecoverImportedRinging(sessionIdentityMigrationSucceeded: Boolean): Boolean =
        sessionIdentityMigrationSucceeded

    fun decide(
        credentialRecordCount: Int,
        credentialEventCount: Int,
    ): AlarmDirectBootMigrationDecision {
        val importedAlarmState = credentialRecordCount > 0 || credentialEventCount > 0
        return AlarmDirectBootMigrationDecision(
            resetSessionMigrationMarker = importedAlarmState,
            resetRecoveryMarkers = importedAlarmState,
            recoverImportedRinging = importedAlarmState,
        )
    }

    /**
     * A locked boot may create empty device-protected metadata before the
     * credential store becomes readable. When actual alarm state is later
     * imported into an otherwise empty device store, its ownership token wins
     * over that provisional metadata.
     */
    fun selectActiveGenerationToken(
        deviceAlarmStatePresent: Boolean,
        credentialAlarmStatePresent: Boolean,
        deviceToken: String?,
        credentialToken: String?,
    ): String? =
        if (!deviceAlarmStatePresent && credentialAlarmStatePresent) {
            credentialToken ?: deviceToken
        } else {
            deviceToken ?: credentialToken
        }

    fun applyCredentialImport(
        current: AlarmDirectBootMarkerState,
        decision: AlarmDirectBootMigrationDecision,
    ): AlarmDirectBootMarkerState =
        current.copy(
            sessionMigrationComplete =
                if (decision.resetSessionMigrationMarker) {
                    false
                } else {
                    current.sessionMigrationComplete
                },
            bootRecoveryToken =
                if (decision.resetRecoveryMarkers) null else current.bootRecoveryToken,
            packageRecoveryToken =
                if (decision.resetRecoveryMarkers) null else current.packageRecoveryToken,
            importedRecoveryPending =
                current.importedRecoveryPending || decision.recoverImportedRinging,
        )
}
