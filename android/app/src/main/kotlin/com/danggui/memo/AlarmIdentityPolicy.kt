package com.danggui.memo

import java.util.UUID

/** Pure identity checks used to make repeated and stale actions harmless. */
internal object AlarmIdentityPolicy {
    /** Byte-for-byte equivalent to iOS DangguiAlarmIdentifier.platformID. */
    fun deterministicSessionId(
        reminderId: String,
        scheduleRevision: Long,
        deviceGeneration: String? = null,
    ): String {
        val canonicalGeneration = deviceGeneration?.let {
            requireNotNull(canonicalDeviceGeneration(it)) {
                "deviceGeneration must be a canonical UUID"
            }
        }
        val identity =
            if (canonicalGeneration == null) {
                "$reminderId\u001f$scheduleRevision"
            } else {
                "$reminderId\u001f$scheduleRevision\u001f$canonicalGeneration"
            }
        val bytes = identity.toByteArray(Charsets.UTF_8)
        val first = fnv1a64(bytes.asIterable(), 0xcbf29ce484222325UL)
        val second = fnv1a64(bytes.reversed(), 0x84222325cbf29ce4UL)
        val characters =
            (first.toString(16).padStart(16, '0') + second.toString(16).padStart(16, '0'))
                .toCharArray()
        characters[12] = '5'
        characters[16] = 'a'
        val compact = characters.concatToString()
        return listOf(
            compact.substring(0, 8),
            compact.substring(8, 12),
            compact.substring(12, 16),
            compact.substring(16, 20),
            compact.substring(20, 32),
        ).joinToString("-")
    }

    private fun fnv1a64(
        bytes: Iterable<Byte>,
        seed: ULong,
    ): ULong {
        var hash = seed
        bytes.forEach { byte ->
            hash = hash xor byte.toUByte().toULong()
            hash *= 0x100000001b3UL
        }
        return hash
    }

    fun matchesCurrent(
        recordReminderId: String,
        recordRevision: Long,
        recordSessionId: String?,
        requestedReminderId: String,
        requestedRevision: Long,
        requestedSessionId: String,
        recordLegacySessionId: String? = null,
    ): Boolean =
        recordReminderId == requestedReminderId &&
            recordRevision == requestedRevision &&
            recordSessionId != null &&
            (recordSessionId == requestedSessionId ||
                recordLegacySessionId == requestedSessionId)

    /**
     * Compatibility is deliberately limited to records created before sessions existed.
     * A missing session must never become a wildcard for a current ringing record.
     */
    fun matchesLegacy(
        recordReminderId: String,
        recordRevision: Long,
        recordSessionId: String?,
        requestedReminderId: String?,
        requestedRevision: Long?,
    ): Boolean =
        recordSessionId == null &&
            (requestedReminderId == null || recordReminderId == requestedReminderId) &&
            (requestedRevision == null || recordRevision == requestedRevision)

    fun hasCompleteCurrentIdentity(
        reminderId: String?,
        scheduleRevision: Long?,
        sessionId: String?,
    ): Boolean =
        !reminderId.isNullOrBlank() && scheduleRevision != null && !sessionId.isNullOrBlank()

    fun canReplace(
        currentRevision: Long?,
        currentGeneration: String?,
        candidateRevision: Long,
        candidateGeneration: String?,
    ): Boolean {
        if (currentRevision == null) return true
        if (candidateRevision != currentRevision) return candidateRevision > currentRevision
        // A v1.1.5 generation can replace legacy or another generated device
        // projection at the same business revision. Legacy callers must never
        // overwrite a generated projection after the upgrade.
        return candidateGeneration != null && candidateGeneration != currentGeneration
    }

    fun canonicalDeviceGeneration(value: String): String? {
        val trimmed = value.trim()
        if (trimmed != value) return null
        val parsed = runCatching { UUID.fromString(trimmed) }.getOrNull() ?: return null
        val canonical = parsed.toString()
        return canonical.takeIf { it.equals(trimmed, ignoreCase = true) }
    }

    /**
     * v1.1.4 used a random UUID for the lifetime of a ringing session.  The
     * v1.1.5 compare-and-swap contract is deterministic, but queued v1.1.4
     * native events must survive an application upgrade.  This policy is used
     * only by the one-shot private-store migration; live method-channel input
     * never passes through it.
     */
    fun migratedV114EventSessionId(
        event: AlarmEvent,
        records: Collection<AlarmRecord>,
        events: Collection<AlarmEvent>,
    ): String? {
        if (
            event.reminderId.isBlank() ||
                event.taskId.isBlank() ||
                event.scheduleRevision <= 0L ||
                event.deviceGeneration != null ||
                !isUuid(event.eventId)
        ) {
            return null
        }
        val expected = deterministicSessionId(event.reminderId, event.scheduleRevision)

        val sameLegacySession: (AlarmEvent) -> Boolean = { candidate ->
            candidate.reminderId == event.reminderId &&
                candidate.taskId == event.taskId &&
                candidate.scheduleRevision == event.scheduleRevision &&
                candidate.sessionId == event.sessionId &&
                candidate.sessionId?.let(::isUuid) == true
        }
        val hasDeliveredPair = events.any { it.type == "delivered" && sameLegacySession(it) }
        return when (event.type) {
            "delivered" -> {
                val hasRingingRecord =
                    records.any { record ->
                        record.reminderId == event.reminderId &&
                            record.taskId == event.taskId &&
                            record.scheduleRevision == event.scheduleRevision &&
                            record.deviceGeneration == null &&
                            record.state == AlarmRecord.STATE_RINGING &&
                            record.sessionId == event.sessionId &&
                            record.sessionId?.let(::isUuid) == true
                    }
                val hasTerminalPair =
                    events.any { candidate ->
                        (candidate.type == "stopped" || candidate.type == "snoozed") &&
                            sameLegacySession(candidate)
                    }
                if (hasRingingRecord || hasTerminalPair) expected else null
            }
            "stopped" -> {
                val recognisedTerminal =
                    event.sessionId?.let(::isUuid) == true &&
                        event.detailCode in
                        setOf(null, "automatic_cutoff", "system_interruption", "replaced_by_schedule")
                if (hasDeliveredPair || recognisedTerminal) expected else null
            }
            "snoozed" -> {
                val successor =
                    records.any { record ->
                        record.reminderId == event.reminderId &&
                        record.taskId == event.taskId &&
                        record.scheduleRevision == event.scheduleRevision + 1L &&
                        record.deviceGeneration == null &&
                        record.state == AlarmRecord.STATE_SCHEDULED &&
                            event.nextTriggerAtEpochMs != null &&
                            record.triggerAtEpochMs == event.nextTriggerAtEpochMs
                    }
                val recognisedSnooze =
                    event.sessionId?.let(::isUuid) == true &&
                        event.snoozeMinutes?.let { it in 1..(24 * 60) } == true
                if (successor && (hasDeliveredPair || recognisedSnooze)) expected else null
            }
            "missed" -> {
                val recognisableRecoveryEvent =
                    (event.sessionId == null || event.sessionId == expected) &&
                        event.detailCode == "recovery_window_expired" &&
                        event.delayMillis != null &&
                        event.delayMillis > AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS
                if (recognisableRecoveryEvent) expected else null
            }
            else -> null
        }
    }

    fun migratedV114RingingSessionId(record: AlarmRecord): String? =
        if (
            record.state == AlarmRecord.STATE_RINGING &&
                record.scheduleRevision > 0L &&
                record.deviceGeneration == null &&
                record.sessionId?.let(::isUuid) == true
        ) {
            deterministicSessionId(record.reminderId, record.scheduleRevision)
        } else {
            null
        }

    private fun isUuid(value: String): Boolean {
        val parsed = runCatching { UUID.fromString(value) }.getOrNull() ?: return false
        return parsed.toString().equals(value, ignoreCase = true)
    }
}
