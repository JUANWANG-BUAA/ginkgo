package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Handles Android single-phone check-in QR acceleration:
 * 1. Overwrites a single app-owned PNG in MediaStore (`Pictures/Ginkgo/ginkgo_checkin_qr.png`)
 *    without requesting legacy broad storage permissions, keeping the latest QR at the top of album pickers.
 * 2. Probes and launches the official scanner host (智慧北航 `cn.edu.buaa.wxwork`, fallback `com.tencent.wework`).
 * 3. Hosts an optional silent ongoing notification action ("刷新码到相册") so the user can refresh
 *    the album QR in-place from the notification shade while staying inside 智慧北航's scanner screen.
 */
class CheckinQrGallerySaver(
    private val context: Context,
    private val channel: MethodChannel
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val FILE_NAME = "ginkgo_checkin_qr.png"
        private const val RELATIVE_DIR = "Ginkgo"
        private const val LIMIT = 4 * 1024 * 1024
        private val PNG_MAGIC = byteArrayOf(
            0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        )

        private const val IBUAA_PACKAGE = "cn.edu.buaa.wxwork"
        private const val WECOM_PACKAGE = "com.tencent.wework"

        private const val QUICK_CHANNEL_ID = "ginkgo_checkin_qr_helper"
        private const val QUICK_NOTIFICATION_ID = 4109
        const val ACTION_REFRESH_QR = "cn.edu.buaa.ginkgo.ACTION_REFRESH_CHECKIN_QR"
        private const val DEFAULT_STATUS = "在智慧北航扫一扫页下拉点下方按钮，秒刷新相册首图"

        @Volatile
        private var activeInstance: CheckinQrGallerySaver? = null

        fun dispatchRefreshFromNotification(context: Context) {
            val instance = activeInstance
            if (instance == null || instance.disposed) {
                cancelQuickNotification(context)
                return
            }
            instance.showOrUpdateQuickNotification("正在同步最新签到码…")
            instance.mainHandler.post {
                if (!instance.disposed) {
                    instance.channel.invokeMethod("refreshAndSaveFromNotification", null)
                }
            }
        }

        private fun cancelQuickNotification(context: Context) {
            try {
                val manager = context.getSystemService(NotificationManager::class.java)
                manager?.cancel(QUICK_NOTIFICATION_ID)
            } catch (_: Exception) {
            }
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var disposed = false

    init {
        activeInstance = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("unavailable", "二维码保存服务已关闭", null)
            return
        }
        when (call.method) {
            "savePng" -> handleSavePng(call, result)
            "probeScannerApp" -> result.success(probeScannerApp())
            "launchScannerApp" -> result.success(launchScannerApp())
            "showQuickNotification" -> {
                val statusText = call.argument<String>("statusText")
                result.success(showOrUpdateQuickNotification(statusText))
            }
            "dismissQuickNotification" -> {
                cancelQuickNotification(context)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleSavePng(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.size < PNG_MAGIC.size || bytes.size > LIMIT || !hasPngHeader(bytes)) {
            result.error("invalid", "二维码图像数据无效", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success("unsupported")
            return
        }
        executor.execute {
            val outcome = saveToMediaStoreQ(bytes)
            mainHandler.post {
                if (disposed) {
                    result.error("unavailable", "二维码保存服务已关闭", null)
                } else if (outcome) {
                    result.success("saved")
                } else {
                    result.error("save_failed", "无法写入系统相册", null)
                }
            }
        }
    }

    private fun probeScannerApp(): String {
        val pm = context.packageManager
        if (pm.getLaunchIntentForPackage(IBUAA_PACKAGE) != null) return "ibuaa"
        if (pm.getLaunchIntentForPackage(WECOM_PACKAGE) != null) return "wecom"
        return "none"
    }

    private fun launchScannerApp(): String {
        val pm = context.packageManager
        val candidates = listOf(IBUAA_PACKAGE to "ibuaa", WECOM_PACKAGE to "wecom")
        for ((pkg, label) in candidates) {
            val launch = pm.getLaunchIntentForPackage(pkg) ?: continue
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            return try {
                context.startActivity(launch)
                label
            } catch (_: Exception) {
                continue
            }
        }
        return "none"
    }

    private fun showOrUpdateQuickNotification(statusText: String?): String {
        val manager = context.getSystemService(NotificationManager::class.java)
            ?: return "unavailable"
        if (!manager.areNotificationsEnabled()) {
            return "permission_denied"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = manager.getNotificationChannel(QUICK_CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    QUICK_CHANNEL_ID,
                    "签到码快捷助手",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "在智慧北航扫码页下拉通知栏一键刷新相册首图"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            } else if (existing.importance == NotificationManager.IMPORTANCE_NONE) {
                return "permission_denied"
            }
        }

        val openApp = PendingIntent.getActivity(
            context,
            QUICK_NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val refreshIntent = PendingIntent.getBroadcast(
            context,
            QUICK_NOTIFICATION_ID + 1,
            Intent(context, CheckinQrActionReceiver::class.java).apply {
                action = ACTION_REFRESH_QR
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val body = statusText?.takeIf { it.isNotBlank() } ?: DEFAULT_STATUS
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, QUICK_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val action = Notification.Action.Builder(
            null,
            "刷新码到相册",
            refreshIntent
        ).build()
        val notification = builder
            .setSmallIcon(R.drawable.ic_reminder)
            .setContentTitle("签到码快捷助手")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp)
            .addAction(action)
            .build()
        return try {
            manager.notify(QUICK_NOTIFICATION_ID, notification)
            "shown"
        } catch (_: SecurityException) {
            "permission_denied"
        } catch (_: Exception) {
            "unavailable"
        }
    }

    private fun hasPngHeader(bytes: ByteArray): Boolean {
        for (i in PNG_MAGIC.indices) {
            if (bytes[i] != PNG_MAGIC[i]) return false
        }
        return true
    }

    private fun saveToMediaStoreQ(bytes: ByteArray): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val resolver = context.contentResolver
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val relativePath = "${Environment.DIRECTORY_PICTURES}/$RELATIVE_DIR"

        // Remove previous app-owned QR image(s) so repeated saves never clutter the album.
        try {
            resolver.delete(
                collection,
                "${MediaStore.MediaColumns.DISPLAY_NAME} = ?",
                arrayOf(FILE_NAME)
            )
        } catch (_: Exception) {
            // Scoped storage allows deleting rows created by this package; ignore if absent.
        }

        val nowMs = System.currentTimeMillis()
        val nowSec = nowMs / 1000L
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, FILE_NAME)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.DATE_ADDED, nowSec)
            put(MediaStore.MediaColumns.DATE_MODIFIED, nowSec)
            put(MediaStore.Images.Media.DATE_TAKEN, nowMs)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = try {
            resolver.insert(collection, values)
        } catch (_: Exception) {
            null
        } ?: return false

        val written = try {
            resolver.openOutputStream(uri, "wt")?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } != null
        } catch (_: Exception) {
            false
        }

        if (!written) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
            }
            return false
        }

        return try {
            val publish = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            resolver.update(uri, publish, null, null) >= 0
        } catch (_: Exception) {
            try {
                resolver.delete(uri, null, null)
            } catch (_: Exception) {
            }
            false
        }
    }

    fun dispose() {
        disposed = true
        if (activeInstance === this) {
            activeInstance = null
        }
        cancelQuickNotification(context)
        executor.shutdown()
    }
}

class CheckinQrActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != CheckinQrGallerySaver.ACTION_REFRESH_QR) return
        CheckinQrGallerySaver.dispatchRefreshFromNotification(context.applicationContext)
    }
}
