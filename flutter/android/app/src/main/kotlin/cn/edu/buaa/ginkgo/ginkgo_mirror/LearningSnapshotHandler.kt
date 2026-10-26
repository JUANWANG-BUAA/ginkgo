package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.Context
import android.content.pm.ApplicationInfo
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** App-private, opt-in storage. Install on a background task queue, never log content. */
class LearningSnapshotHandler(context: Context) : MethodChannel.MethodCallHandler {
    // Fail closed in signed public builds until the storage review is complete.
    private val developmentEnabled = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    private val preferences = context.getSharedPreferences("ginkgo-learning-snapshot-consent-v1", Context.MODE_PRIVATE)
    private val store = SecureSnapshotStore(context)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (!developmentEnabled && call.method in setOf("enable", "load", "save")) {
                throw IllegalStateException()
            }
            when (call.method) {
                "enabled" -> result.success(developmentEnabled && preferences.getBoolean("enabled", false))
                "enable" -> {
                    // Enabling requires the Dart confirmation flow. No school query here.
                    if (!preferences.edit().putBoolean("enabled", true).commit()) throw IllegalStateException()
                    result.success(null)
                }
                "load" -> {
                    if (!preferences.getBoolean("enabled", false)) throw IllegalStateException()
                    result.success(store.load())
                }
                "save" -> {
                    if (!preferences.getBoolean("enabled", false)) throw IllegalStateException()
                    val bytes = call.arguments as? ByteArray ?: throw IllegalArgumentException()
                    store.save(bytes)
                    result.success(null)
                }
                "clear" -> {
                    // Fail closed before attempting deletion; never load surviving ciphertext.
                    if (!preferences.edit().putBoolean("enabled", false).commit()) throw IllegalStateException()
                    store.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("snapshot_unavailable", "安全快照操作未完成，请重试或保持关闭", null)
        }
    }
}
