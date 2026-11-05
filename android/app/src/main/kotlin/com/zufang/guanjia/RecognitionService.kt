package com.zufang.guanjia

import android.app.*
import android.content.Intent
import android.os.*

/** Protect only user-started OCR work; never boot-start or restart stale work. */
class RecognitionService : Service() {
    private var wake: PowerManager.WakeLock? = null
    override fun onCreate() {
        super.onCreate()
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("ocr_tasks", "电表识别任务", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "ocr_tasks") else Notification.Builder(this)
        startForeground(1250, builder.setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle("正在识别电表").setContentText("可继续使用其他应用，完成后返回核对读数")
            .setContentIntent(open).setOngoing(true).build())
        wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK, "$packageName:ocr").apply { acquire(60 * 60 * 1000L) }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_NOT_STICKY
    override fun onBind(intent: Intent?) = null
    override fun onDestroy() {
        wake?.let { if (it.isHeld) it.release() }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
