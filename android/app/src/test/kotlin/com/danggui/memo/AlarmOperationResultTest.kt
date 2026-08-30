package com.danggui.memo

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AlarmOperationResultTest {
    @Test
    fun `success has no MethodChannel error code`() {
        assertNull(AlarmScheduleResult.SUCCESS.errorCode)
    }

    @Test
    fun `permission install cancel and storage errors are stable`() {
        assertEquals(
            "exact_alarm_permission_required",
            AlarmScheduleResult.EXACT_ALARM_PERMISSION_REQUIRED.errorCode,
        )
        assertEquals(
            "system_alarm_install_failed",
            AlarmScheduleResult.SYSTEM_ALARM_INSTALL_FAILED.errorCode,
        )
        assertEquals(
            "system_alarm_cancel_failed",
            AlarmScheduleResult.SYSTEM_ALARM_CANCEL_FAILED.errorCode,
        )
        assertEquals(
            "alarm_event_capacity_exceeded",
            AlarmScheduleResult.BUSINESS_EVENT_CAPACITY_EXCEEDED.errorCode,
        )
        assertEquals(
            "inactive_device_generation",
            AlarmScheduleResult.INACTIVE_DEVICE_GENERATION.errorCode,
        )
        assertEquals(
            "alarm_storage_failed",
            AlarmScheduleResult.DURABLE_COMMIT_FAILED.errorCode,
        )
    }
}
