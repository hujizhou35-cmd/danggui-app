package com.danggui.memo

internal enum class AlarmRecoveryDecision {
    EXPIRE,
    RETAIN_DURABLE,
    INSTALL,
}

internal enum class AlarmDurableState {
    PENDING,
    SCHEDULED,
    CANCEL_PENDING,
    REMOVED,
}

/** Pure durable-state rules used by recovery and local JVM tests. */
internal object AlarmTransactionPolicy {
    private const val STATE_SCHEDULED = "scheduled"
    private const val STATE_PENDING = "pending"

    fun recoveryDecision(
        triggerAtEpochMs: Long,
        nowEpochMs: Long,
        exactAlarmAllowed: Boolean,
    ): AlarmRecoveryDecision =
        when {
            triggerAtEpochMs < nowEpochMs - AlarmDeliveryPolicy.MISSED_ALARM_GRACE_MILLIS ->
                AlarmRecoveryDecision.EXPIRE
            !exactAlarmAllowed -> AlarmRecoveryDecision.RETAIN_DURABLE
            else -> AlarmRecoveryDecision.INSTALL
        }

    fun canRearm(state: String): Boolean =
        state == STATE_SCHEDULED || state == STATE_PENDING

    fun afterScheduleAttempt(
        systemInstallSucceeded: Boolean,
        durableCommitSucceeded: Boolean,
    ): AlarmDurableState =
        if (systemInstallSucceeded && durableCommitSucceeded) {
            AlarmDurableState.SCHEDULED
        } else {
            AlarmDurableState.PENDING
        }

    fun afterCancelAttempt(
        systemCancelSucceeded: Boolean,
        durableFinalizeSucceeded: Boolean,
    ): AlarmDurableState =
        if (systemCancelSucceeded && durableFinalizeSucceeded) {
            AlarmDurableState.REMOVED
        } else {
            AlarmDurableState.CANCEL_PENDING
        }
}
