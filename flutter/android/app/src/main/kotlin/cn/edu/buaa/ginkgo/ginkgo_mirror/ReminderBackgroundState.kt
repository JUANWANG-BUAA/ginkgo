package cn.edu.buaa.ginkgo.ginkgo_mirror

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import java.util.UUID

/** All mutations run on ReminderQueue, including job completion and sign-out. */
internal object ReminderBackgroundState {
    const val JOB_ID = 7109
    @Volatile var foreground = false
    private fun prefs(context: Context) = context.getSharedPreferences("reminder-background-v1", 0)
    fun owner(context: Context): String? = prefs(context).getString("owner", null)
    fun summary(context: Context): Map<String, Any> {
        val prefs = prefs(context)
        return mapOf("enabled" to (configuration(context) != null),
            "scheduled" to (context.getSystemService(JobScheduler::class.java).getPendingJob(JOB_ID) != null),
            "lastRun" to prefs.getLong("lastRun", 0), "status" to (prefs.getString("status", null) ?: "pending"))
    }
    fun completed(context: Context, status: String) {
        check(status in listOf("updated", "sessionRequired", "storageUnavailable", "localSettings", "retryLater"))
        check(prefs(context).edit().putLong("lastRun", System.currentTimeMillis()).putString("status", status).commit())
    }
    fun configuration(context: Context): Map<String, Any>? {
        val prefs = prefs(context)
        val owner = prefs.getString("owner", null) ?: return null
        val generation = prefs.getString("generation", null) ?: return null
        if (!prefs.getBoolean("checkin", false) && !prefs.getBoolean("homework", false)) return null
        return mapOf("owner" to owner, "generation" to generation,
            "checkin" to prefs.getBoolean("checkin", false), "homework" to prefs.getBoolean("homework", false))
    }
    fun configure(context: Context, owner: String, checkin: Boolean, homework: Boolean) {
        val prefs = prefs(context)
        if (prefs.getString("owner", null) != owner || prefs.getBoolean("checkin", false) != checkin ||
            prefs.getBoolean("homework", false) != homework || !prefs.contains("generation")) {
            check(prefs.edit().putString("owner", owner).putBoolean("checkin", checkin)
                .putBoolean("homework", homework).putString("generation", UUID.randomUUID().toString())
                .remove("lastRun").remove("status").commit())
        }
        val jobs = context.getSystemService(JobScheduler::class.java)
        if (!checkin && !homework) jobs.cancel(JOB_ID)
        else if (jobs.getPendingJob(JOB_ID) == null) {
            check(jobs.schedule(JobInfo.Builder(JOB_ID, ComponentName(context, ReminderRefreshJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPeriodic(15 * 60 * 1000L).setPersisted(true).build()) == JobScheduler.RESULT_SUCCESS)
        }
    }
    fun clear(context: Context) {
        // Invalidate first, so even an already running job cannot publish.
        check(prefs(context).edit().clear().commit())
        context.getSystemService(JobScheduler::class.java).cancel(JOB_ID)
    }
}
