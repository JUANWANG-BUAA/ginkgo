package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Overwrites a single app-owned PNG in MediaStore (`Pictures/Ginkgo/ginkgo_checkin_qr.png`)
 * without requesting legacy broad storage permissions. Replacing the previous app-owned row
 * prevents gallery clutter and keeps the fresh QR code at the top of album pickers.
 */
class CheckinQrGallerySaver(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val FILE_NAME = "ginkgo_checkin_qr.png"
        private const val RELATIVE_DIR = "Ginkgo"
        private const val LIMIT = 4 * 1024 * 1024
        private val PNG_MAGIC = byteArrayOf(
            0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        )
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var disposed = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("unavailable", "二维码保存服务已关闭", null)
            return
        }
        if (call.method != "savePng") {
            result.notImplemented()
            return
        }
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
        executor.shutdown()
    }
}
