package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

/** User-selected SAF capabilities only. No arbitrary URI or storage permission. */
class HomeworkFileSaver(private val activity: MainActivity) : MethodChannel.MethodCallHandler {
    companion object {
        const val REQUEST = 47319
        const val LIMIT = 20 * 1024 * 1024
        private const val TTL = 30 * 60 * 1000L
    }
    private data class Selection(val uri: Uri, val mime: String, val createdAt: Long)
    private var pending: MethodChannel.Result? = null
    private var pendingMime = "application/octet-stream"
    private val selected = mutableMapOf<String, Selection>()
    private val saved = linkedMapOf<String, Selection>()
    private val executor = Executors.newSingleThreadExecutor()
    private var writing = false
    private var disposed = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        prune()
        if (disposed) { result.error("unavailable", "文件服务已关闭", null); return }
        when (call.method) {
            "select" -> select(call, result)
            "commit" -> commit(call, result)
            "discard" -> {
                val token = call.argument<String>("token")
                selected.remove(token); saved.remove(token)
                result.success(null)
            }
            "open" -> open(call, result)
            // Legacy all-in-one native save is intentionally removed: the Dart
            // compatibility wrapper also goes through select -> guard -> commit.
            else -> result.notImplemented()
        }
    }

    private fun select(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null || writing) { result.error("busy", "文件操作进行中", null); return }
        val name = call.argument<String>("name")
        if (name.isNullOrBlank() || name.length > 240 || name.any { it.isISOControl() || it == '/' || it.code == 92 }) {
            result.error("invalid", "文件名称无效", null); return
        }
        // Keep only the current uncommitted selection. Previous saved capabilities
        // remain usable for explicit Open buttons for at most TTL / 16 entries.
        selected.clear()
        pending = result
        pendingMime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(
            name.substringAfterLast('.', "").lowercase()
        ) ?: "application/octet-stream"
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = pendingMime
                putExtra(Intent.EXTRA_TITLE, name)
            }, REQUEST)
        } catch (_: Exception) {
            pending = null
            result.error("unavailable", "无法选择保存位置", null)
        }
    }

    fun onResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        if (disposed || resultCode != Activity.RESULT_OK) { result.success(null); return true }
        val uri = data?.data
        if (uri == null || uri.scheme != "content") {
            result.error("invalid", "保存位置无效", null); return true
        }
        val token = UUID.randomUUID().toString()
        selected[token] = Selection(uri, pendingMime, android.os.SystemClock.elapsedRealtime())
        // Never return a URI: only this one-use picker capability can be committed.
        result.success(token)
        return true
    }

    private fun commit(call: MethodCall, result: MethodChannel.Result) {
        if (writing) { result.error("busy", "文件操作进行中", null); return }
        val token = call.argument<String>("token")
        val selection = selected.remove(token) // consume before any async work
        val content = call.argument<ByteArray>("bytes")
        if (token == null || selection == null || content == null || content.size > LIMIT) {
            result.error("invalid", "文件保存操作已失效", null); return
        }
        writing = true
        executor.execute {
            val ok = try {
                activity.contentResolver.openOutputStream(selection.uri, "wt")?.use { it.write(content) } != null
            } catch (_: Exception) { false }
            activity.runOnUiThread {
                writing = false
                if (disposed) { result.error("unavailable", "文件服务已关闭", null); return@runOnUiThread }
                if (ok) {
                    saved[token] = selection
                    prune()
                    result.success(null)
                } else result.error("save_failed", "无法保存文件", null)
            }
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val selection = saved[call.argument<String>("token")]
        if (selection == null) { result.success("unavailable"); return }
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(selection.uri, selection.mime)
                clipData = ClipData.newRawUri("已保存文件", selection.uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
            result.success("opened")
        } catch (_: android.content.ActivityNotFoundException) {
            result.success("unsupported")
        } catch (_: Exception) { result.success("unavailable") }
    }

    private fun prune() {
        val cutoff = android.os.SystemClock.elapsedRealtime() - TTL
        selected.entries.removeAll { it.value.createdAt < cutoff }
        saved.entries.removeAll { it.value.createdAt < cutoff }
        while (saved.size > 16) saved.remove(saved.keys.first())
    }

    fun dispose() {
        disposed = true
        selected.clear(); saved.clear()
        pending?.success(null); pending = null
        executor.shutdown()
    }
}
