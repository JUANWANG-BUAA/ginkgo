package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ReminderRearmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED)) return
        val pending = goAsync()
        ReminderQueue.worker.execute {
            try { ReminderScheduler(context.applicationContext).rearm() }
            catch (_: Exception) { android.util.Log.w("Ginkgo", "reminder rearm failed") }
            finally { pending.finish() }
        }
    }
}
