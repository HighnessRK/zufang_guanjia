package com.zufang.guanjia

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.zufang.guanjia.notify.NotificationHelper
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar
import java.util.concurrent.Executors
import java.util.concurrent.Future

/** 原生定时器不依赖 Flutter 引擎存活；省电策略下允许系统延迟执行。 */
object UpdateScheduler {
    private const val PREFS = "update_schedule"
    private const val REQUEST = 914
    const val JOB = 914
    fun configure(context: Context, enabled: Boolean, source: String, version: String) {
        context.getSharedPreferences(PREFS, 0).edit()
            .putBoolean("enabled", enabled).putString("source", source)
            .putString("version", version).apply()
        schedule(context)
    }
    fun enabled(context: Context) = context.getSharedPreferences(PREFS, 0)
        .getBoolean("enabled", false)

    fun schedule(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val intent = PendingIntent.getBroadcast(context, REQUEST,
            Intent(context, UpdateAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        alarm.cancel(intent)
        if (!enabled(context)) {
            context.getSystemService(JobScheduler::class.java).cancel(JOB)
            return
        }
        val now = System.currentTimeMillis()
        val next = Calendar.getInstance().apply {
            set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            set(Calendar.HOUR_OF_DAY, 9)
            if (timeInMillis <= now) set(Calendar.HOUR_OF_DAY, 21)
            if (timeInMillis <= now) { add(Calendar.DAY_OF_YEAR, 1); set(Calendar.HOUR_OF_DAY, 9) }
        }
        // 不申请不必要的精确闹钟权限；Doze 下系统可能推迟至维护窗口。
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, intent)
    }

    fun check(context: Context) {
        if (!enabled(context)) return
        val prefs = context.getSharedPreferences(PREFS, 0)
        val github = prefs.getString("source", "gitee") == "github"
        val address = if (github)
            "https://api.github.com/repos/HighnessRK/zufang_guanjia/releases/latest"
        else "https://gitee.com/api/v5/repos/HighnesssRK/zufang_guanjia/releases?per_page=50"
        val connection = URL(address).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 15000; connection.readTimeout = 15000
            connection.setRequestProperty("User-Agent", "zufang-guanjia-updater")
            if (connection.responseCode != 200) return
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val release = if (github) JSONObject(body) else {
                val list = JSONArray(body)
                (0 until list.length()).map { list.getJSONObject(it) }
                    .filter { !it.optBoolean("draft") && !it.optBoolean("prerelease") }
                    .maxWithOrNull { a, b -> compare(a.optString("tag_name"), b.optString("tag_name")) }
                    ?: return
            }
            val version = release.optString("tag_name").removePrefix("v").removePrefix("V")
            if (version.isEmpty() || compare(version, prefs.getString("version", "0")!!) <= 0) return
            if (!enabled(context) || Thread.currentThread().isInterrupted) return
            NotificationHelper.ensureChannels(context)
            NotificationHelper.post(context, 1014, NotificationHelper.CHANNEL_GENERAL,
                "发现新版本 V$version", "点击打开应用，查看更新说明并下载安装", null, false)
        } finally { connection.disconnect() }
    }
    private fun compare(a: String, b: String): Int {
        fun parts(s: String) = s.trim().removePrefix("v").removePrefix("V")
            .split('.', '+', '-').take(3).map { it.toIntOrNull() ?: 0 }
        val x = parts(a); val y = parts(b)
        for (i in 0..2) {
            val cmp = (x.getOrElse(i) { 0 }).compareTo(y.getOrElse(i) { 0 })
            if (cmp != 0) return cmp
        }
        return 0
    }
}

class UpdateAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        UpdateScheduler.schedule(context)
        if (!UpdateScheduler.enabled(context) || intent.action != null) return
        context.getSystemService(JobScheduler::class.java).schedule(
            JobInfo.Builder(UpdateScheduler.JOB, ComponentName(context, UpdateCheckJob::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setBackoffCriteria(30 * 60 * 1000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
    }
}

class UpdateCheckJob : JobService() {
    private val executor = Executors.newSingleThreadExecutor()
    private var task: Future<*>? = null
    override fun onStartJob(params: JobParameters): Boolean {
        task = executor.submit {
            var retry = false
            try { UpdateScheduler.check(this) } catch (_: Exception) { retry = true }
            if (!Thread.currentThread().isInterrupted) jobFinished(params, retry)
        }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { task?.cancel(true); return true }
    override fun onDestroy() { executor.shutdownNow(); super.onDestroy() }
}
