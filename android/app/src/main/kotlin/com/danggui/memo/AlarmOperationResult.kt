package com.danggui.memo

/** Stable native outcomes. MethodChannel maps these names to stable error codes. */
internal enum class AlarmScheduleResult(val errorCode: String?) {
    SUCCESS(null),
    INVALID_TRIGGER_TIME("invalid_trigger_time"),
    EXACT_ALARM_PERMISSION_REQUIRED("exact_alarm_permission_required"),
    INACTIVE_DEVICE_GENERATION("inactive_device_generation"),
    STALE_SCHEDULE_REVISION("stale_schedule_revision"),
    BUSINESS_EVENT_CAPACITY_EXCEEDED("alarm_event_capacity_exceeded"),
    DURABLE_STORE_WRITE_FAILED("alarm_storage_failed"),
    SYSTEM_ALARM_INSTALL_FAILED("system_alarm_install_failed"),
    SYSTEM_ALARM_CANCEL_FAILED("system_alarm_cancel_failed"),
    DURABLE_COMMIT_FAILED("alarm_storage_failed"),
}

internal data class AlarmActionOutcome(
    val result: AlarmScheduleResult,
    val affectedCount: Int,
)
