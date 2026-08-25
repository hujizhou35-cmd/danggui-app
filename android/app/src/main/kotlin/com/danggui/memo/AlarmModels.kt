package com.danggui.memo

import org.json.JSONObject
import java.util.UUID

internal data class AlarmRecord(
    val reminderId: String,
    val taskId: String,
    val scheduleRevision: Long,
    val triggerAtEpochMs: Long,
    val title: String,
    val body: String,
    val localeTag: String,
    val vibrationEnabled: Boolean,
    val defaultSnoozeMinutes: Int,
    val state: String = STATE_SCHEDULED,
) {
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("reminderId", reminderId)
            put("taskId", taskId)
            put("scheduleRevision", scheduleRevision)
            put("triggerAtEpochMs", triggerAtEpochMs)
            put("title", title)
            put("body", body)
            put("localeTag", localeTag)
            put("vibrationEnabled", vibrationEnabled)
            put("defaultSnoozeMinutes", defaultSnoozeMinutes)
            put("state", state)
        }

    fun toMap(): Map<String, Any> =
        mapOf(
            "reminderId" to reminderId,
            "taskId" to taskId,
            "scheduleRevision" to scheduleRevision,
            "triggerAtEpochMs" to triggerAtEpochMs,
            "title" to title,
            "body" to body,
            "localeTag" to localeTag,
            "vibrationEnabled" to vibrationEnabled,
            "defaultSnoozeMinutes" to defaultSnoozeMinutes,
            "state" to state,
        )

    companion object {
        const val STATE_SCHEDULED = "scheduled"
        const val STATE_RINGING = "ringing"

        fun fromJson(json: JSONObject): AlarmRecord =
            AlarmRecord(
                reminderId = json.getString("reminderId"),
                taskId = json.optString("taskId"),
                scheduleRevision = json.optLong("scheduleRevision"),
                triggerAtEpochMs = json.getLong("triggerAtEpochMs"),
                title = json.optString("title"),
                body = json.optString("body"),
                localeTag = json.optString("localeTag"),
                vibrationEnabled = json.optBoolean("vibrationEnabled", true),
                defaultSnoozeMinutes = json.optInt("defaultSnoozeMinutes", 10).coerceIn(1, 24 * 60),
                state = json.optString("state", STATE_SCHEDULED),
            )
    }
}

internal data class AlarmEvent(
    val eventId: String = UUID.randomUUID().toString(),
    val reminderId: String,
    val taskId: String,
    val scheduleRevision: Long,
    val type: String,
    val occurredAtEpochMs: Long = System.currentTimeMillis(),
    val snoozeMinutes: Int? = null,
    val nextTriggerAtEpochMs: Long? = null,
) {
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("eventId", eventId)
            put("reminderId", reminderId)
            put("taskId", taskId)
            put("scheduleRevision", scheduleRevision)
            put("type", type)
            put("occurredAtEpochMs", occurredAtEpochMs)
            snoozeMinutes?.let { put("snoozeMinutes", it) }
            nextTriggerAtEpochMs?.let { put("nextTriggerAtEpochMs", it) }
        }

    fun toMap(): Map<String, Any> = buildMap {
        put("eventId", eventId)
        put("reminderId", reminderId)
        put("taskId", taskId)
        put("scheduleRevision", scheduleRevision)
        put("type", type)
        put("occurredAtEpochMs", occurredAtEpochMs)
        snoozeMinutes?.let { put("snoozeMinutes", it) }
        nextTriggerAtEpochMs?.let { put("nextTriggerAtEpochMs", it) }
    }

    companion object {
        fun fromJson(json: JSONObject): AlarmEvent =
            AlarmEvent(
                eventId = json.getString("eventId"),
                reminderId = json.getString("reminderId"),
                taskId = json.optString("taskId"),
                scheduleRevision = json.optLong("scheduleRevision"),
                type = json.getString("type"),
                occurredAtEpochMs = json.optLong("occurredAtEpochMs"),
                snoozeMinutes = json.optIntOrNull("snoozeMinutes"),
                nextTriggerAtEpochMs = json.optLongOrNull("nextTriggerAtEpochMs"),
            )
    }
}

private fun JSONObject.optIntOrNull(name: String): Int? =
    if (has(name) && !isNull(name)) getInt(name) else null

private fun JSONObject.optLongOrNull(name: String): Long? =
    if (has(name) && !isNull(name)) getLong(name) else null
