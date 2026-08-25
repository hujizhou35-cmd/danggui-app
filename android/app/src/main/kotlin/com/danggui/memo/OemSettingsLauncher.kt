package com.danggui.memo

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

internal class OemSettingsLauncher(private val activity: Activity) {
    data class LaunchResult(
        val opened: Boolean,
        val target: String,
        val requiresManualConfirmation: Boolean = true,
    ) {
        fun toMap(): Map<String, Any> =
            mapOf(
                "opened" to opened,
                "target" to target,
                "requiresManualConfirmation" to requiresManualConfirmation,
            )
    }

    fun hasDedicatedTarget(): Boolean = dedicatedTargets().any(::canResolve)

    fun open(): LaunchResult {
        for (target in dedicatedTargets().filter(::canResolve)) {
            val launched =
                start(target, "${target.component?.packageName}/${target.component?.className}")
            if (launched.opened) return launched
        }

        val batteryIntent =
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        if (canResolve(batteryIntent)) return start(batteryIntent, "batteryOptimizationSettings")

        val appDetails =
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}"),
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        return start(appDetails, "applicationDetails")
    }

    private fun dedicatedTargets(): List<Intent> {
        val manufacturer = "${Build.MANUFACTURER} ${Build.BRAND}".lowercase()
        val candidates =
            when {
                listOf("xiaomi", "redmi", "poco").any(manufacturer::contains) ->
                    listOf(
                        component(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity",
                        ),
                        component(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.permissions.PermissionsEditorActivity",
                        ),
                    )
                listOf("huawei", "honor", "hihonor").any(manufacturer::contains) ->
                    listOf(
                        component(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                        ),
                        component(
                            "com.hihonor.systemmanager",
                            "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                        ),
                        component(
                            "com.huawei.systemmanager",
                            "com.huawei.systemmanager.optimize.process.ProtectActivity",
                        ),
                        component(
                            "com.hihonor.systemmanager",
                            "com.hihonor.systemmanager.optimize.process.ProtectActivity",
                        ),
                    )
                listOf("oppo", "oneplus", "realme").any(manufacturer::contains) ->
                    listOf(
                        component(
                            "com.coloros.safecenter",
                            "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                        ),
                        component(
                            "com.oplus.safecenter",
                            "com.oplus.safecenter.startupapp.StartupAppListActivity",
                        ),
                    )
                listOf("vivo", "iqoo").any(manufacturer::contains) ->
                    listOf(
                        component(
                            "com.vivo.permissionmanager",
                            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                        ),
                        component(
                            "com.iqoo.secure",
                            "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                        ),
                    )
                manufacturer.contains("samsung") ->
                    listOf(
                        component(
                            "com.samsung.android.lool",
                            "com.samsung.android.sm.ui.battery.BatteryActivity",
                        ),
                    )
                else -> emptyList()
            }
        return candidates.map { intent ->
            intent.apply {
                putExtra("package_name", activity.packageName)
                putExtra("packageName", activity.packageName)
                putExtra("pkg", activity.packageName)
                putExtra("extra_pkgname", activity.packageName)
                data = Uri.parse("package:${activity.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        }
    }

    private fun component(packageName: String, className: String): Intent =
        Intent().setComponent(ComponentName(packageName, className))

    private fun canResolve(intent: Intent): Boolean =
        intent.resolveActivity(activity.packageManager) != null

    private fun start(intent: Intent, target: String): LaunchResult =
        try {
            activity.startActivity(intent)
            LaunchResult(opened = true, target = target)
        } catch (_: Exception) {
            LaunchResult(opened = false, target = target)
        }
}
