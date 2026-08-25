package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getStringExtra(AlarmActions.EXTRA_REMINDER_ID)
        when (intent.action) {
            AlarmActions.ACTION_STOP -> AlarmActions.stop(context, reminderId)
            AlarmActions.ACTION_SNOOZE -> {
                val minutes = intent.getIntExtra(AlarmActions.EXTRA_SNOOZE_MINUTES, 10)
                AlarmActions.snooze(context, reminderId, minutes)
            }
        }
    }
}
