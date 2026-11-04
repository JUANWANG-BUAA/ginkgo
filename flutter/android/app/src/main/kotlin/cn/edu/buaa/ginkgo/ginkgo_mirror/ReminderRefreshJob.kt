package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.job.JobParameters
import android.app.job.JobService
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One bounded headless engine per periodic job; no Activity or password login. */
class ReminderRefreshJob : JobService() {
    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    @Volatile private var running: JobParameters? = null
    private var channel: MethodChannel? = null
    private val timeout = Runnable { finish() }

    override fun onStartJob(params: JobParameters): Boolean {
        if (ReminderBackgroundState.foreground || running != null) return false
        running = params
        ReminderQueue.worker.execute {
            val config = try { ReminderBackgroundState.configuration(applicationContext) }
                catch (_: Exception) { null }
            main.post {
                if (running !== params) return@post
                if (config == null || ReminderBackgroundState.foreground) { finish(); return@post }
                try {
                    GinkgoNativeRuntime.initialize(applicationContext)
                    val loader = FlutterInjector.instance().flutterLoader()
                    loader.startInitialization(applicationContext)
                    loader.ensureInitializationComplete(applicationContext, null)
                    val worker = FlutterEngine(applicationContext)
                    engine = worker
                    channel = MethodChannel(worker.dartExecutor.binaryMessenger, "cn.edu.buaa.ginkgo/reminder-background").also { bridge ->
                        bridge.setMethodCallHandler { call, result ->
                            when (call.method) {
                                "begin" -> result.success(config)
                                "finish" -> {
                                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                                    ReminderQueue.worker.execute {
                                        try {
                                            val current = ReminderBackgroundState.configuration(applicationContext)
                                            if (running === params && !ReminderBackgroundState.foreground && current == config &&
                                                args["generation"] == config["generation"]) {
                                                val groups = args["groups"] as? List<*> ?: emptyList<Any>()
                                                check(groups.all { (it == "checkin" && config["checkin"] == true) ||
                                                    (it == "homework" && config["homework"] == true) })
                                                ReminderScheduler(applicationContext).merge(groups, args["plans"])
                                                ReminderBackgroundState.completed(applicationContext, args["status"] as? String ?: "retryLater")
                                            }
                                        } catch (_: Exception) {
                                            android.util.Log.w("Ginkgo", "background reminder scheduling failed")
                                        } finally {
                                            main.post {
                                                result.success(null)
                                                main.post { if (running === params) finish() }
                                            }
                                        }
                                    }
                                }
                                else -> result.notImplemented()
                            }
                        }
                    }
                    main.postDelayed(timeout, 120_000)
                    worker.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        "package:ginkgo_mirror/infrastructure/background_reminders.dart",
                        "runBackgroundReminders"))
                } catch (_: Throwable) { finish() }
            }
        }
        return true
    }

    private fun close() {
        main.removeCallbacks(timeout)
        running = null
        channel?.setMethodCallHandler(null)
        channel = null
        engine?.destroy()
        engine = null
    }
    private fun finish() {
        val params = running ?: return
        close()
        // Do not hot-loop authentication failures; the periodic policy retries later.
        jobFinished(params, false)
    }
    override fun onStopJob(params: JobParameters): Boolean {
        if (running === params) close()
        return false
    }
    override fun onDestroy() { close(); super.onDestroy() }
}
