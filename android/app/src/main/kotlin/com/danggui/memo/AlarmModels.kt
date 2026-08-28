package com.danggui.memo

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal data class AlarmRecord(
    val reminderId: String,
    val taskId: String,
    val scheduleRevision: Long,
    val deviceGeneration: String? = null,
    val triggerAtEpochMs: Long,
    val title: String,
    val body: String,
    val localeTag: String,
    val vibrationEnabled: Boolean,
    val defaultSnoozeMinutes: Int,
    val state: String = STATE_SCHEDULED,
    val sessionId: String? = null,
    val legacySessionId: String? = null,
    val ringStartedElapsedRealtimeMs: Long? = null,
    /**
     * A scheduled-pending record stores capacity reservations here. A
     * terminal-pending record stores the exact terminal event that must be
     * retried after output is stopped. The latter is a safety tombstone and is
     * deliberately not counted as an occupied outbox slot until it is flushed.
     */
    val reservedBusinessEvents: List<AlarmEvent> = emptyList(),
) {
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("reminderId", reminderId)
            put("taskId", taskId)
            put("scheduleRevision", scheduleRevision)
            deviceGeneration?.let { put("deviceGeneration", it) }
            put("triggerAtEpochMs", triggerAtEpochMs)
            put("title", title)
            put("body", body)
            put("localeTag", localeTag)
            put("vibrationEnabled", vibrationEnabled)
            put("defaultSnoozeMinutes", defaultSnoozeMinutes)
            put("state", state)
            sessionId?.let { put("sessionId", it) }
            legacySessionId?.let { put("legacySessionId", it) }
            ringStartedElapsedRealtimeMs?.let { put("ringStartedElapsedRealtimeMs", it) }
            if (reservedBusinessEvents.isNotEmpty()) {
                put(
                    "reservedBusinessEvents",
                    JSONArray(reservedBusinessEvents.map(AlarmEvent::toJson)),
                )
            }
        }

    fun toMap(): Map<String, Any> =
        buildMap {
            put("platformId", platformId)
            put("reminderId", reminderId)
            put("taskId", taskId)
            put("scheduleRevision", scheduleRevision)
            put("revision", scheduleRevision)
            deviceGeneration?.let { put("deviceGeneration", it) }
            put("triggerAtEpochMs", triggerAtEpochMs)
            put("title", title)
            put("body", body)
            put("localeTag", localeTag)
            put("vibrationEnabled", vibrationEnabled)
            put("defaultSnoozeMinutes", defaultSnoozeMinutes)
            put("state", state)
            sessionId?.let { put("sessionId", it) }
            ringStartedElapsedRealtimeMs?.let { put("ringStartedElapsedRealtimeMs", it) }
        }

    val platformId: String
        get() =
            if (deviceGeneration == null) {
                "$reminderId:$scheduleRevision"
            } else {
                "$reminderId:$scheduleRevision:$deviceGeneration"
            }

    companion object {
        const val STATE_SCHEDULED = "scheduled"
        const val STATE_PENDING = "pending"
        const val STATE_RINGING = "ringing"
        const val STATE_CANCEL_PENDING = "cancel_pending"
        const val STATE_TERMINAL_PENDING = "terminal_pending"

        fun fromJson(json: JSONObject): AlarmRecord =
            AlarmRecord(
                reminderId = json.getString("reminderId"),
                taskId = json.optString("taskId"),
                scheduleRevision = json.optLong("scheduleRevision"),
                deviceGeneration = json.optDeviceGeneration(),
                triggerAtEpochMs = json.getLong("triggerAtEpochMs"),
                title = json.optString("title"),
                body = json.optString("body"),
                localeTag = json.optString("localeTag"),
                vibrationEnabled = json.optBoolean("vibrationEnabled", true),
                defaultSnoozeMinutes = json.optInt("defaultSnoozeMinutes", 10).coerceIn(1, 24 * 60),
                state = json.optString("state", STATE_SCHEDULED),
                sessionId = json.optStringOrNull("sessionId"),
                legacySessionId = json.optStringOrNull("legacySessionId"),
                ringStartedElapsedRealtimeMs =
                    json.optLongOrNull("ringStartedElapsedRealtimeMs"),
                reservedBusinessEvents = json.optAlarmEvents("reservedBusinessEvents"),
            )
    }
}

internal data class AlarmEvent(
    val eventId: String = UUID.randomUUID().toString(),
    val reminderId: String,
    val taskId: String,
    val scheduleRevision: Long,
    val deviceGeneration: String? = null,
    val type: String,
    val occurredAtEpochMs: Long = System.currentTimeMillis(),
    val snoozeMinutes: Int? = null,
    val nextTriggerAtEpochMs: Long? = null,
    val sessionId: String? = null,
    val detailCode: String? = null,
    val delayMillis: Long? = null,
) {
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("eventId", eventId)
            put("reminderId", reminderId)
            put("taskId", taskId)
            put("scheduleRevision", scheduleRevision)
            deviceGeneration?.let { put("deviceGeneration", it) }
            put("type", type)
            put("occurredAtEpochMs", occurredAtEpochMs)
            snoozeMinutes?.let { put("snoozeMinutes", it) }
            nextTriggerAtEpochMs?.let { put("nextTriggerAtEpochMs", it) }
            sessionId?.let { put("sessionId", it) }
            detailCode?.let { put("detailCode", it) }
            delayMillis?.let { put("delayMillis", it) }
        }

    fun toMap(): Map<String, Any> = buildMap {
        put("eventId", eventId)
        put("reminderId", reminderId)
        put("taskId", taskId)
        put("scheduleRevision", scheduleRevision)
        deviceGeneration?.let { put("deviceGeneration", it) }
        put("type", type)
        put("occurredAtEpochMs", occurredAtEpochMs)
        snoozeMinutes?.let { put("snoozeMinutes", it) }
        nextTriggerAtEpochMs?.let { put("nextTriggerAtEpochMs", it) }
        sessionId?.let { put("sessionId", it) }
        detailCode?.let { put("detailCode", it) }
        delayMillis?.let { put("delayMillis", it) }
    }

    companion object {
        fun fromJson(json: JSONObject): AlarmEvent =
            AlarmEvent(
                eventId = json.getString("eventId"),
                reminderId = json.getString("reminderId"),
                taskId = json.optString("taskId"),
                scheduleRevision = json.optLong("scheduleRevision"),
                deviceGeneration = json.optDeviceGeneration(),
                type = json.getString("type"),
                occurredAtEpochMs = json.optLong("occurredAtEpochMs"),
                snoozeMinutes = json.optIntOrNull("snoozeMinutes"),
                nextTriggerAtEpochMs = json.optLongOrNull("nextTriggerAtEpochMs"),
                sessionId = json.optStringOrNull("sessionId"),
                detailCode = json.optStringOrNull("detailCode"),
                delayMillis = json.optLongOrNull("delayMillis"),
            )
    }
}

private fun JSONObject.optIntOrNull(name: String): Int? =
    if (has(name) && !isNull(name)) getInt(name) else null

private fun JSONObject.optLongOrNull(name: String): Long? =
    if (has(name) && !isNull(name)) getLong(name) else null

private fun JSONObject.optStringOrNull(name: String): String? =
    if (has(name) && !isNull(name)) getString(name).takeIf(String::isNotBlank) else null

private fun JSONObject.optDeviceGeneration(): String? {
    val raw = optStringOrNull("deviceGeneration") ?: return null
    return requireNotNull(AlarmIdentityPolicy.canonicalDeviceGeneration(raw)) {
        "Stored deviceGeneration is not a canonical UUID."
    }
}

private fun JSONObject.optAlarmEvents(name: String): List<AlarmEvent> {
    if (!has(name) || isNull(name)) return emptyList()
    val values = getJSONArray(name)
    return buildList {
        repeat(values.length()) { index ->
            add(AlarmEvent.fromJson(values.getJSONObject(index)))
        }
    }
}
