package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Only opens the current app's public system settings. No device identifiers. */
class SystemSettingsHandler(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object { const val NOTIFICATION_REQUEST = 7211 }
    private var permissionResult: MethodChannel.Result? = null
    private val preferences = activity.getSharedPreferences("system-preferences", 0)

    private fun notificationPermission(): String {
        val enabled = Build.VERSION.SDK_INT < 24 ||
            activity.getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        if (enabled && (Build.VERSION.SDK_INT < 33 ||
                activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)) {
            return "granted"
        }
        return if (Build.VERSION.SDK_INT >= 33 &&
            !preferences.getBoolean("notification-requested", false)) "notRequested" else "denied"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "notificationPermission" -> result.success(notificationPermission())
            "requestNotifications" -> {
                if (Build.VERSION.SDK_INT < 33 || notificationPermission() == "granted") {
                    result.success(notificationPermission())
                } else if (permissionResult != null) {
                    result.error("busy", "权限请求正在进行", null)
                } else {
                    permissionResult = result
                    preferences.edit().putBoolean("notification-requested", true).apply()
                    activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST)
                }
            }
            "openNotifications" -> open(
                if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                else appSettings(),
                result,
            )
            "openAppSettings" -> open(appSettings(), result)
            "shareProject" -> open(
                Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT,
                        "Ginkgo · 北航校园工作台\n校园日常，从容有序\nhttps://juanwang-buaa.github.io/ginkgo/")
                }, "分享 Ginkgo"), result,
            )
            else -> result.notImplemented()
        }
    }

    private fun appSettings() = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.parse("package:${activity.packageName}"))

    private fun open(intent: Intent, result: MethodChannel.Result) {
        try {
            activity.startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != NOTIFICATION_REQUEST) return false
        permissionResult?.success(notificationPermission())
        permissionResult = null
        return true
    }
}
