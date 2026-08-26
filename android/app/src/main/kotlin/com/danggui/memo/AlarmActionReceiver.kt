package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra(AlarmActions.EXTRA_REMINDER_ID)
        val scheduleRevision =
            if (intent.hasExtra(AlarmActions.EXTRA_SCHEDULE_REVISION)) {
                intent.getLongExtra(AlarmActions.EXTRA_SCHEDULE_REVISION, Long.MIN_VALUE)
            } else {
                null
            }
        val sessionId = intent.getStringExtra(AlarmActions.EXTRA_SESSION_ID)
        when (intent.action) {
            AlarmActions.ACTION_STOP ->
                AlarmActions.stop(
                    context = context,
                    reminderId = reminderId,
                    scheduleRevision = scheduleRevision,
                    sessionId = sessionId,
                    allowLegacyIdentity = sessionId == null,
                )
            AlarmActions.ACTION_SNOOZE -> {
                val minutes = intent.getIntExtra(AlarmActions.EXTRA_SNOOZE_MINUTES, 10)
                AlarmActions.snooze(
                    context = context,
                    reminderId = reminderId,
                    scheduleRevision = scheduleRevision,
                    sessionId = sessionId,
                    minutes = minutes,
                    allowLegacyIdentity = sessionId == null,
                )
            }
        }
    }
}
