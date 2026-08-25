package com.danggui.memo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

internal object AlarmChannels {
    fun ensureRingingChannel(context: Context, localeTag: String? = null): NotificationChannel? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val manager = context.getSystemService(NotificationManager::class.java)
        val textContext = AlarmLocale.contextFor(context, localeTag)
        val channel =
            NotificationChannel(
                AlarmRingingService.CHANNEL_ID,
                textContext.getString(R.string.alarm_channel_name),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = textContext.getString(R.string.alarm_channel_description)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
        manager.createNotificationChannel(channel)
        return manager.getNotificationChannel(AlarmRingingService.CHANNEL_ID) ?: channel
    }
}
