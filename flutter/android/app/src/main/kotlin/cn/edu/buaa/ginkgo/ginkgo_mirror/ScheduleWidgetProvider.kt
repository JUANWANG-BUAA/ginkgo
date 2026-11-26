package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 4x2 home-screen widget showing the next class time and classroom from the
 * active account's last synced today snapshot. Cleared automatically on sign-out.
 */
class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    companion object {
        private const val PREFS_NAME = "ginkgo-schedule-widget"
        private const val KEY_PAYLOAD = "today_payload"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, ScheduleWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val views = buildViews(context)
            for (id in ids) manager.updateAppWidget(id, views)
        }

        fun saveToday(context: Context, payloadJson: String) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_PAYLOAD, payloadJson)
                .apply()
            updateAll(context)
        }

        fun clear(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_PAYLOAD)
                .apply()
            updateAll(context)
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_schedule_today)
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("ginkgo_destination", "schedule")
            }
            val pending = PendingIntent.getActivity(
                context,
                4021,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_PAYLOAD, null)
            if (raw.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_header, "Ginkgo 今日课表")
                views.setTextViewText(R.id.widget_badge, "")
                views.setTextViewText(R.id.widget_primary_title, "打开 Ginkgo 同步课表")
                views.setTextViewText(R.id.widget_primary_detail, "登录后将自动在桌面显示下一节课")
                views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
                return views
            }

            try {
                val root = JSONObject(raw)
                val date = root.optString("date", "")
                val coursesJson = root.optJSONArray("courses") ?: JSONArray()
                val tz = TimeZone.getTimeZone("Asia/Shanghai")
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = tz }.format(Date())
                val nowHm = SimpleDateFormat("HH:mm", Locale.US).apply { timeZone = tz }.format(Date())

                views.setTextViewText(
                    R.id.widget_header,
                    if (date.isNotEmpty()) "今日课表 · ${date.removePrefix(todayStr.take(5))}" else "Ginkgo 今日课表",
                )

                if (date.isNotEmpty() && date != todayStr) {
                    views.setTextViewText(R.id.widget_badge, "待更新")
                    views.setTextViewText(R.id.widget_primary_title, "轻触刷新今日课表")
                    views.setTextViewText(R.id.widget_primary_detail, "上次同步日期：$date")
                    views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
                    return views
                }

                val courses = (0 until coursesJson.length()).map { coursesJson.getJSONObject(it) }
                if (courses.isEmpty()) {
                    views.setTextViewText(R.id.widget_badge, "0 节课")
                    views.setTextViewText(R.id.widget_primary_title, "今天没有排课")
                    views.setTextViewText(R.id.widget_primary_detail, "点击查看本周完整课表")
                    views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
                    return views
                }

                val upcoming = courses.filter { course ->
                    val end = extractEndTime(course.optString("time", ""))
                    end == null || end >= nowHm
                }

                if (upcoming.isEmpty()) {
                    views.setTextViewText(R.id.widget_badge, "共 ${courses.size} 节")
                    views.setTextViewText(R.id.widget_primary_title, "今日课程已全部结束")
                    views.setTextViewText(R.id.widget_primary_detail, "轻触查看明日及本周课表")
                    views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
                    return views
                }

                val next = upcoming.first()
                views.setTextViewText(R.id.widget_badge, "余 ${upcoming.size} 节")
                views.setTextViewText(R.id.widget_primary_title, next.optString("name", "课程"))
                val detailParts = listOfNotNull(
                    next.optString("time", "").takeIf { it.isNotEmpty() },
                    next.optString("place", "").takeIf { it.isNotEmpty() },
                )
                views.setTextViewText(
                    R.id.widget_primary_detail,
                    detailParts.joinToString(" · ").ifEmpty { "点击查看教室详情" },
                )

                if (upcoming.size > 1) {
                    val second = upcoming[1]
                    val secondParts = listOfNotNull(
                        second.optString("time", "").takeIf { it.isNotEmpty() },
                        second.optString("name", "").takeIf { it.isNotEmpty() },
                        second.optString("place", "").takeIf { it.isNotEmpty() },
                    )
                    views.setTextViewText(R.id.widget_secondary_line, "随后：${secondParts.joinToString(" · ")}")
                    views.setViewVisibility(R.id.widget_secondary_line, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
                }
            } catch (_: Exception) {
                views.setTextViewText(R.id.widget_primary_title, "点击查看今日课表")
                views.setTextViewText(R.id.widget_primary_detail, "打开 Ginkgo 刷新数据")
                views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
            }
            return views
        }

        private fun extractEndTime(timeRange: String): String? {
            val matches = Regex("""\d{2}:\d{2}""").findAll(timeRange).map { it.value }.toList()
            return matches.lastOrNull()
        }
    }
}

class ScheduleWidgetChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "syncToday" -> {
                val payload = call.arguments as? String
                if (payload != null) ScheduleWidgetProvider.saveToday(context, payload)
                result.success(null)
            }
            "clear" -> {
                ScheduleWidgetProvider.clear(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
