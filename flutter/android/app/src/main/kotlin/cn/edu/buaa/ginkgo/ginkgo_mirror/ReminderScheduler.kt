package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/**
 * Local generic reminders only. Never reads the network or performs check-in.
 *
 * `replace` persists plans with a synchronous `commit()` and re-arms up to 60
 * alarms: that is disk and system-service work, so it runs on a single worker
 * thread and reports back on the main thread. Running it on the channel's
 * main thread would stall the UI on every reschedule.
 */
class ReminderScheduler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "summary") {
            val prefs = context.getSharedPreferences("local-reminders", 0)
            val manager = context.getSystemService(NotificationManager::class.java)
            result.success(mapOf("plans" to JSONArray(prefs.getString("plans", "[]")).length(),
                "delivered" to JSONObject(prefs.getString("delivered", "{}")).length(),
                "visible" to manager.activeNotifications.count { Build.VERSION.SDK_INT < 26 || it.notification.channelId == "campus-reminders-v1" }))
            return
        }
        if (call.method != "replace") { result.notImplemented(); return }
        val arguments = call.arguments
        worker.execute {
            val outcome = try {
                replace(arguments)
                null
            } catch (e: Exception) {
                e
            }
            main.post {
                if (outcome == null) result.success(null)
                else result.error("schedule_failed", "本地提醒排程失败", null)
            }
        }
    }

    private fun replace(callArguments: Any?) {
        val plans = callArguments as? List<*> ?: emptyList<Any>()
        val next = JSONArray()
        for (raw in plans.take(60)) {
            val plan = raw as? Map<*, *> ?: continue
            val key = plan["key"] as? String ?: continue
            val group = plan["group"] as? String ?: continue
            val at = (plan["at"] as? Number)?.toLong() ?: continue
            val expiry = (plan["expires"] as? Number)?.toLong() ?: continue
            if (!key.matches(Regex("[a-f0-9]{64}")) || group !in listOf("checkin", "homework", "course", "task") || expiry <= System.currentTimeMillis()) continue
            next.put(JSONObject().put("key", key).put("group", group).put("at", at).put("expires", expiry))
        }
        val prefs = context.getSharedPreferences("local-reminders", 0)
        val previous = JSONArray(prefs.getString("plans", "[]"))
        val alarms = context.getSystemService(AlarmManager::class.java)
        val notifications = context.getSystemService(NotificationManager::class.java)
        val keys = (0 until next.length()).map { next.getJSONObject(it).getString("key") }.toSet()
        for (i in 0 until previous.length()) {
            val old = previous.getJSONObject(i)
            val key = old.getString("key")
            alarms.cancel(pending(context, key))
            if (key !in keys) notifications.cancel(key, 0)
        }
        // Persist first; a stale/cancelled broadcast must never deliver a reminder.
        prefs.edit().putString("plans", next.toString()).commit()
        val delivered = JSONObject(prefs.getString("delivered", "{}"))
        val iterator = delivered.keys()
        val expired = mutableListOf<String>()
        while (iterator.hasNext()) { val key = iterator.next(); if (delivered.optLong(key) <= System.currentTimeMillis()) expired.add(key) }
        expired.forEach { delivered.remove(it) }
        prefs.edit().putString("delivered", delivered.toString()).commit()
        for (i in 0 until next.length()) {
            val plan = next.getJSONObject(i)
            val key = plan.getString("key")
            if (!delivered.has(key)) {
                // Inexact by design: no exact-alarm privilege or foreground service.
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                    maxOf(System.currentTimeMillis() + 1000, plan.getLong("at")), pending(context, key))
            }
        }
    }

    fun dispose() {
        worker.shutdown()
    }
    companion object {
        fun pending(context: Context, key: String): PendingIntent = PendingIntent.getBroadcast(
            context, 0, Intent(context, ReminderReceiver::class.java).apply {
                action = "cn.edu.buaa.ginkgo.reminder.$key"
                putExtra("key", key)
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val key = intent.getStringExtra("key") ?: return
        try {
            val prefs = context.getSharedPreferences("local-reminders", 0)
            val plans = JSONArray(prefs.getString("plans", "[]"))
            val plan = (0 until plans.length()).map { plans.getJSONObject(it) }.firstOrNull { it.optString("key") == key } ?: return
            val now = System.currentTimeMillis()
            if (plan.getLong("at") > now || plan.getLong("expires") <= now) return
            val delivered = JSONObject(prefs.getString("delivered", "{}"))
            if (delivered.has(key)) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (!manager.areNotificationsEnabled()) return
            val group = plan.getString("group")
            val channel = "campus-reminders-v1"
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                NotificationChannel(channel, "校园事项提醒", NotificationManager.IMPORTANCE_DEFAULT))
            val open = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
            val notification = builder.setSmallIcon(R.drawable.ic_reminder)
                .setContentTitle(when (group) {
                    "checkin" -> "签到已开放"
                    "course" -> "课程即将开始"
                    "task" -> "待办临近截止"
                    else -> "作业临近截止"
                })
                .setContentText(when (group) {
                    "checkin" -> "课程签到窗口已开放，请进入 Ginkgo 核对并手动签到。"
                    "course" -> "有课程即将开始，请进入 Ginkgo 查看时间与地点。"
                    "task" -> "有未完成待办进入截止提醒期，请进入 Ginkgo 查看。"
                    else -> "有未完成作业进入截止提醒期，请进入 Ginkgo 查看。"
                })
                .setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).build()
            // Mark before posting: repeated broadcasts/rescheduling must not notify twice.
            delivered.put(key, plan.getLong("expires"))
            prefs.edit().putString("delivered", delivered.toString()).commit()
            manager.notify(key, 0, notification)
        } catch (_: Exception) { android.util.Log.w("Ginkgo", "local reminder delivery failed") }
    }
}
