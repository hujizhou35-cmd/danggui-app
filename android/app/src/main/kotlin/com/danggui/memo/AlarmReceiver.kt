package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmScheduler.ACTION_FIRE_ALARM) return
        val reminderId = intent.getStringExtra(AlarmScheduler.EXTRA_REMINDER_ID) ?: return
        val scheduleRevision =
            intent.getLongExtra(AlarmScheduler.EXTRA_SCHEDULE_REVISION, Long.MIN_VALUE)
        val store = AlarmStore(context)
        val record =
            store.markRingingAndAppendFired(
                reminderId = reminderId,
                scheduleRevision = scheduleRevision,
                occurredAtEpochMs = System.currentTimeMillis(),
            ) ?: return
        val serviceIntent =
            Intent(context, AlarmRingingService::class.java).apply {
                action = AlarmRingingService.ACTION_REFRESH
            }
        val serviceStarted =
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }.getOrNull() != null
        if (!serviceStarted) {
            store.removeRingingAndAppendStopped(record)
        }
        context.sendBroadcast(
            Intent(AlarmActions.ACTION_SESSION_CHANGED).apply {
                setPackage(context.packageName)
            },
        )
    }
}
