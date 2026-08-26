package com.danggui.memo

/** Pure identity checks used to make repeated and stale actions harmless. */
internal object AlarmIdentityPolicy {
    fun matchesCurrent(
        recordReminderId: String,
        recordRevision: Long,
        recordSessionId: String?,
        requestedReminderId: String,
        requestedRevision: Long,
        requestedSessionId: String,
    ): Boolean =
        recordReminderId == requestedReminderId &&
            recordRevision == requestedRevision &&
            recordSessionId != null &&
            recordSessionId == requestedSessionId

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

    fun canReplace(currentRevision: Long?, candidateRevision: Long): Boolean =
        currentRevision == null || candidateRevision > currentRevision
}
