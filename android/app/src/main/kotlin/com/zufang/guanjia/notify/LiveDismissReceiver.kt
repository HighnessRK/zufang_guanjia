package com.zufang.guanjia.notify

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Live Update（Android 16 晋升常驻通知）的退出回调。
 *
 * 同一个 PendingIntent 同时挂在通知的 deleteIntent（用户左滑划掉）和
 * 「取消关注」Action 上。系统要求：用户拒绝过的 Live Update 不得在下一次
 * 更新时复活，否则用户会撤销应用的晋升权限。
 *
 * 收到回调后：
 *   1. 在 SharedPreferences 记录"已划掉"，[NotificationHelper.postLive]
 *      在非 restart 的常规刷新里会跳过发送；
 *   2. 兜底取消一次通知（取消不存在的通知是空操作）。
 *
 * 记录会在两种情况下清除：用户手动重启测试（restart=true）或用户重新打开
 * 应用（MainActivity.onResume）。
 */
class LiveDismissReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LiveUpdate"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            NotificationHelper.markLiveDismissed(context)
            val id = intent.getIntExtra(NotificationHelper.EXTRA_LIVE_ID, -1)
            if (id >= 0) {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                manager?.cancel(id)
            }
            Log.i(TAG, "live update dismissed by user (id=$id)")
        } catch (t: Throwable) {
            Log.w(TAG, "LiveDismissReceiver failed: $t")
        }
    }
}
