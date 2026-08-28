package com.danggui.memo

/**
 * Pure active-generation rules shared by scheduling, delivery and recovery.
 *
 * A missing persisted token is deliberately interpreted as the legacy
 * generation so v1.1.4 alarms remain valid until Dart completes the first
 * v1.1.5 activation handshake. Once a UUID is activated, only records carrying
 * that exact canonical UUID may reach Android platform state.
 */
internal object AlarmGenerationPolicy {
    const val LEGACY_STORAGE_TOKEN = "legacy"
    const val INVALID_STORAGE_TOKEN = "invalid"

    fun storageToken(deviceGeneration: String?): String =
        if (deviceGeneration == null) {
            LEGACY_STORAGE_TOKEN
        } else {
            requireNotNull(AlarmIdentityPolicy.canonicalDeviceGeneration(deviceGeneration)) {
                "deviceGeneration must be a canonical UUID"
            }
        }

    fun restoredGeneration(storedToken: String?): String? {
        if (storedToken == null || storedToken == LEGACY_STORAGE_TOKEN) return null
        return AlarmIdentityPolicy.canonicalDeviceGeneration(storedToken)
    }

    fun normalizedStorageToken(storedToken: String?): String? {
        if (storedToken == null) return null
        if (storedToken == LEGACY_STORAGE_TOKEN) return LEGACY_STORAGE_TOKEN
        return AlarmIdentityPolicy.canonicalDeviceGeneration(storedToken)
    }

    fun recoveredStorageToken(
        primaryPresent: Boolean,
        primaryValue: String?,
        backupPresent: Boolean,
        backupValue: String?,
    ): String? =
        normalizedStorageToken(primaryValue)
            ?: normalizedStorageToken(backupValue)
            ?: if (!primaryPresent && !backupPresent) null else INVALID_STORAGE_TOKEN

    fun isRecoverable(storedToken: String?): Boolean = storedToken != INVALID_STORAGE_TOKEN

    fun isActive(storedToken: String?, candidateGeneration: String?): Boolean =
        (storedToken ?: LEGACY_STORAGE_TOKEN) == storageToken(candidateGeneration)

    fun recordsToRetire(
        records: Collection<AlarmRecord>,
        activeGeneration: String?,
    ): List<AlarmRecord> = records.filterNot { it.deviceGeneration == activeGeneration }

    fun recordsForActiveGeneration(
        records: Collection<AlarmRecord>,
        activeGeneration: String?,
    ): List<AlarmRecord> = records.filter { it.deviceGeneration == activeGeneration }

    fun eventsForActiveGeneration(
        events: Collection<AlarmEvent>,
        activeGeneration: String?,
    ): List<AlarmEvent> = events.filter { it.deviceGeneration == activeGeneration }
}
