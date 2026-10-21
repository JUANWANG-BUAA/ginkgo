package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Verification runs off the UI thread and never installs without system UI. */
class UpdateInstaller(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var busy = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "install") { result.notImplemented(); return }
        val digest = call.argument<String>("sha256") ?: ""
        val version = call.argument<String>("version") ?: ""
        if (!digest.matches(Regex("[a-f0-9]{64}")) || version.isBlank() || busy) {
            result.success("invalid")
            return
        }
        busy = true
        worker.execute {
            val apk = File(activity.cacheDir, "updates/$digest.apk")
            val valid = try { verify(apk, digest, version) } catch (_: Exception) { false }
            main.post {
                busy = false
                if (!valid || activity.isFinishing || activity.isDestroyed) {
                    result.success("invalid")
                    return@post
                }
                try {
                    if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}")))
                        result.success("permission")
                    } else {
                        val uri = FileProvider.getUriForFile(activity,
                            "${activity.packageName}.updates", apk)
                        activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success("opened")
                    }
                } catch (_: Exception) {
                    result.success("failed")
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners
            else info.signatures
        return signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray())
                .joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private fun verify(file: File, expected: String, version: String): Boolean {
        if (!file.isFile || file.length() !in 1..268_435_456) return false
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        if (digest.digest().joinToString("") { "%02x".format(it) } != expected) return false
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES
            else PackageManager.GET_SIGNATURES
        val installed = activity.packageManager.getPackageInfo(activity.packageName, flags)
        val archive = activity.packageManager.getPackageArchiveInfo(file.path, flags) ?: return false
        if (archive.packageName != activity.packageName || archive.versionName != version) return false
        val oldCode = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        val newCode = if (Build.VERSION.SDK_INT >= 28) archive.longVersionCode else archive.versionCode.toLong()
        val ownSignatures = signatures(installed)
        return newCode > oldCode && ownSignatures.isNotEmpty() && signatures(archive) == ownSignatures
    }
}
