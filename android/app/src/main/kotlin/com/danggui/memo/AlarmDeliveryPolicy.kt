package com.danggui.memo

internal enum class AlarmDeliveryDecision {
    DELIVER,
    TOO_EARLY,
    MISSED,
}

internal enum class AlarmDispatchRoute {
    WAKEFUL_RECEIVER,
    DIRECT_FOREGROUND_SERVICE,
}

/** Pure timing rules shared by the service and local JVM tests. */
internal object AlarmDeliveryPolicy {
    const val MISSED_ALARM_GRACE_MILLIS = 15 * 60_000L

    /**
     * Android 7/7.1 use the platform's canonical alarm broadcast contract and
     * a bounded wakeful hand-off. Android 8+ can enter a foreground service
     * directly, avoiding an additional background-start transition.
     */
    fun dispatchRouteForSdk(sdkInt: Int): AlarmDispatchRoute =
        if (sdkInt >= 26) {
            AlarmDispatchRoute.DIRECT_FOREGROUND_SERVICE
        } else {
            AlarmDispatchRoute.WAKEFUL_RECEIVER
        }

    fun decide(triggerAtEpochMs: Long, nowEpochMs: Long): AlarmDeliveryDecision =
        when {
            nowEpochMs < triggerAtEpochMs -> AlarmDeliveryDecision.TOO_EARLY
            nowEpochMs - triggerAtEpochMs > MISSED_ALARM_GRACE_MILLIS ->
                AlarmDeliveryDecision.MISSED
            else -> AlarmDeliveryDecision.DELIVER
        }

    fun cutoffAtEpochMs(triggerAtEpochMs: Long): Long =
        triggerAtEpochMs + MISSED_ALARM_GRACE_MILLIS

    /**
     * Returns the shorter of the wall-clock recovery window and the monotonic hard limit.
     * The latter prevents a backwards wall-clock adjustment from extending a ringing session.
     */
    fun remainingRingingMillis(
        triggerAtEpochMs: Long,
        ringStartedElapsedRealtimeMs: Long?,
        nowEpochMs: Long,
        nowElapsedRealtimeMs: Long,
    ): Long {
        val wallRemaining = cutoffAtEpochMs(triggerAtEpochMs) - nowEpochMs
        val monotonicRemaining =
            ringStartedElapsedRealtimeMs
                ?.let { started -> started + MISSED_ALARM_GRACE_MILLIS - nowElapsedRealtimeMs }
                ?.coerceAtMost(MISSED_ALARM_GRACE_MILLIS)
                ?: MISSED_ALARM_GRACE_MILLIS
        return minOf(wallRemaining, monotonicRemaining)
    }

    fun isRingingExpired(
        triggerAtEpochMs: Long,
        ringStartedElapsedRealtimeMs: Long?,
        nowEpochMs: Long,
        nowElapsedRealtimeMs: Long,
    ): Boolean =
        remainingRingingMillis(
            triggerAtEpochMs = triggerAtEpochMs,
            ringStartedElapsedRealtimeMs = ringStartedElapsedRealtimeMs,
            nowEpochMs = nowEpochMs,
            nowElapsedRealtimeMs = nowElapsedRealtimeMs,
        ) <= 0L
}
