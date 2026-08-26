package com.danggui.memo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import java.util.concurrent.Executors

class AlarmRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in SUPPORTED_ACTIONS) return

        val pendingResult = goAsync()
        val applicationContext = context.applicationContext
        val wakeLock =
            applicationContext.getSystemService(PowerManager::class.java)
                .newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "${applicationContext.packageName}:alarm-recovery",
                ).apply {
                    setReferenceCounted(false)
                    acquire(RECOVERY_WAKE_LOCK_TIMEOUT_MILLIS)
                }
        executor.execute {
            try {
                val store = AlarmStore(applicationContext)
                when {
                    action in BOOT_ACTIONS ->
                        store.recoverAfterBoot(
                            bootToken = bootToken(applicationContext),
                            occurredAtEpochMs = System.currentTimeMillis(),
                        )
                    action == Intent.ACTION_MY_PACKAGE_REPLACED ->
                        store.recoverAfterPackageReplacement(
                            packageToken = packageToken(applicationContext),
                            occurredAtEpochMs = System.currentTimeMillis(),
                        )
                }
                AlarmScheduler(applicationContext).rescheduleAll()
            } catch (_: RuntimeException) {
                // Store writes are transactional; leave the last durable state for the next
                // boot, package, time-change, or app-start reconciliation attempt.
            } finally {
                if (wakeLock.isHeld) wakeLock.release()
                pendingResult.finish()
            }
        }
    }

    private fun bootToken(context: Context): String {
        val bootCount =
            runCatching {
                Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT)
            }.getOrNull()
        if (bootCount != null) return "boot-count:$bootCount"

        val approximateBootEpochMinutes =
            (System.currentTimeMillis() - SystemClock.elapsedRealtime()) / 60_000L
        return "boot-epoch-minute:$approximateBootEpochMinutes"
    }

    private fun packageToken(context: Context): String {
        val lastUpdateTime =
            runCatching {
                context.packageManager.getPackageInfo(context.packageName, 0).lastUpdateTime
            }.getOrDefault(0L)
        return "package-update:$lastUpdateTime"
    }

    companion object {
        private const val RECOVERY_WAKE_LOCK_TIMEOUT_MILLIS = 60_000L
        private val executor = Executors.newSingleThreadExecutor()
        private val SUPPORTED_ACTIONS =
            setOf(
                Intent.ACTION_LOCKED_BOOT_COMPLETED,
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED,
                "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
                "android.intent.action.QUICKBOOT_POWERON",
                "com.htc.intent.action.QUICKBOOT_POWERON",
            )
        private val BOOT_ACTIONS =
            setOf(
                Intent.ACTION_LOCKED_BOOT_COMPLETED,
                Intent.ACTION_BOOT_COMPLETED,
                "android.intent.action.QUICKBOOT_POWERON",
                "com.htc.intent.action.QUICKBOOT_POWERON",
            )
    }
}
