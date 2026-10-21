package com.zufang.guanjia.notify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import com.zufang.guanjia.MainActivity
import com.zufang.guanjia.R

/**
 * 通知工具类：统一创建通知渠道、构建并发送 Android 系统通知。
 *
 * 渠道划分（对应不同业务，方便用户在系统设置里分别开关）：
 *   general_notice  通用提醒
 *   rent_remind     房租 / 租期到期提醒
 *   utility_remind  水电费提醒
 *   focus_notice    澎湃OS 焦点通知
 *   live_notice_v1  Android 16 Live Updates（收款进度芯片）
 */
object NotificationHelper {

    const val CHANNEL_GENERAL = "general_notice"
    const val CHANNEL_RENT = "rent_remind"
    const val CHANNEL_UTILITY = "utility_remind"
    const val CHANNEL_FOCUS = "focus_notice_v2"
    const val CHANNEL_LIVE = "live_notice_v1"

    //==================== Live Updates 状态 ====================
    private const val TAG = "LiveUpdate"
    private const val LIVE_PREFS = "live_update_state"
    private const val LIVE_KEY = "rent_progress"
    private const val LIVE_TIMEOUT_MS = 6 * 60 * 60 * 1000L // 6 小时兜底过期
    private const val BRAND_COLOR = 0xFF3482FF.toInt()

    /** dismissIntent 携带的通知 ID */
    const val EXTRA_LIVE_ID = "live_notification_id"

    /** 划掉 / 取消关注广播 */
    const val ACTION_LIVE_DISMISSED = "com.zufang.guanjia.LIVE_UPDATE_DISMISSED"

    /**
     * 创建全部通知渠道（Android 8.0+ 必须先建渠道才能发通知）
     */
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channels = listOf(
            NotificationChannel(
                CHANNEL_GENERAL,
                "通用提醒",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "租房管家通用消息提醒" },

            NotificationChannel(
                CHANNEL_RENT,
                "房租与租期提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "房租未缴、租期即将到期的提醒" },

            NotificationChannel(
                CHANNEL_UTILITY,
                "水电费提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "水电费未收缴的提醒" },

            // 焦点渠道对齐官方参考实现：默认优先级、静音、不上角标、
            // 锁屏可见（岛由系统渲染，不需要横幅声音）
            NotificationChannel(
                CHANNEL_FOCUS,
                "焦点通知",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "澎湃OS / HyperOS 超级岛提醒"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },

            // Live Update 渠道：低重要度 + 静音 + 无角标。
            // 进度会频繁原地更新，任何提示音/震动都会变成骚扰，
            // 也是晋升被系统拒的常见原因（IMPORTANCE_MIN 不能晋升）。
            NotificationChannel(
                CHANNEL_LIVE,
                "动态进度 Live Update",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Android 16 Live Updates：本期收款进度芯片"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )

        manager.createNotificationChannels(channels)
    }

    /**
     * 构建一条系统通知
     *
     * @param channelId 渠道 ID
     * @param title     标题
     * @param body      正文（折叠态）
     * @param bigText   展开后的大文本，可为空
     * @param ongoing   是否常驻（不可滑动删除）
     */
    fun build(
        context: Context,
        channelId: String,
        title: String,
        body: String,
        bigText: String?,
        ongoing: Boolean
    ): Notification {
        ensureChannels(context)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(if (bigText.isNullOrBlank()) body else bigText)
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(!ongoing)
            .setOngoing(ongoing)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())

        if (ongoing) {
            builder.setCategory(NotificationCompat.CATEGORY_REMINDER)
        } else {
            builder.setCategory(NotificationCompat.CATEGORY_EVENT)
        }

        // 澎湃OS / HyperOS 焦点通知 → 超级岛增强
        val focusApplied =
            FocusNotificationHelper.applyFocus(context, builder, title, body)
        if (focusApplied) {
            // 与官方参考实现一致：岛通知常驻 + 限时自动移除；
            // updatable/reopen 负责"点击打开应用后岛不消失"
            builder.setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setAutoCancel(false)
                .setColor(0xFF3482FF.toInt()) // 品牌色，同时作为岛高亮色参考
                .setTimeoutAfter(120 * 60_000L) // 120 分钟后自动移除
                .setCategory(NotificationCompat.CATEGORY_STATUS)
        }

        // 点击通知 / 岛时打开 APP
        try {
            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(
                context,
                0,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setContentIntent(pi)
        } catch (_: Throwable) {
            // 打不开也不影响通知送达
        }

        return builder.build()
    }

    /**
     * 发送一条通知
     */
    fun post(
        context: Context,
        id: Int,
        channelId: String,
        title: String,
        body: String,
        bigText: String?,
        ongoing: Boolean
    ) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notification = build(context, channelId, title, body, bigText, ongoing)
        if (notification.extras.containsKey("miui.focus.param")) {
            // 带焦点参数 → 后台线程走 XMSF 校验通道（220ms 窗口后恢复规则），
            // 校验门不可用或任何失败都会自动降级为普通发送
            Thread {
                FocusNotificationHelper.postWithValidation(
                    context, manager, id, notification
                )
            }.start()
        } else {
            manager.notify(id, notification)
        }
    }

    /**
     * 发送 / 原地更新一条 Live Update（Android 16 晋升常驻进度通知）。
     *
     * 始终使用同一个 [id] 调用即为"原地更新"；[restart] = true 视为新的
     * 生命周期开始，清除用户此前的"已划掉"记录（对应官方 start 事件），
     * 常规刷新传 false（update 事件，已划掉则跳过，避免复活用户拒绝的通知）。
     *
     * 任何异常都不会影响其它通知：失败时降级为普通常驻进度通知。
     */
    fun postLive(
        context: Context,
        id: Int,
        title: String,
        body: String,
        progress: Int,
        progressMax: Int,
        criticalText: String?,
        restart: Boolean
    ) {
        ensureChannels(context)
        try {
            if (restart) clearLiveDismissed(context)
            if (isLiveDismissed(context)) {
                Log.i(TAG, "postLive skipped: user dismissed earlier (id=$id)")
                return
            }
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val dismiss = liveDismissIntent(context, id)
            val notification =
                if (Build.VERSION.SDK_INT >= 36) {
                    buildLive36(
                        context, title, body, progress, progressMax, criticalText, dismiss
                    )
                } else {
                    buildLiveCompat(context, title, body, progress, progressMax, dismiss)
                }

            if (Build.VERSION.SDK_INT >= 36) {
                // 两个晋升闸门的实时诊断：
                //   promotable   —— 通知本身是否合格（不含用户设置）
                //   canPost 用户是否在系统里打开了本应用的 Live Update 开关
                Log.i(
                    TAG,
                    "postLive id=$id progress=$progress/$progressMax " +
                        "promotable=${notification.hasPromotableCharacteristics()} " +
                        "canPostPromoted=${manager.canPostPromotedNotifications()}"
                )
            } else {
                Log.i(TAG, "postLive id=$id progress=$progress/$progressMax (API<36 降级)")
            }
            manager.notify(id, notification)
        } catch (t: Throwable) {
            Log.w(TAG, "postLive failed, fallback: $t")
            try {
                val fallback = buildLiveCompat(
                    context, title, body, progress, progressMax,
                    liveDismissIntent(context, id)
                )
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .notify(id, fallback)
            } catch (_: Throwable) {
                // 再失败就放弃，绝不影响提醒主流程
            }
        }
    }

    /**
     * API 36+：晋升常驻通知（Android 16 QPR1 上呈现为 Live Update：
     * 状态栏芯片 + 通知栏置顶 + 锁屏醒目位）。
     *
     * 晋升条件（缺一不可）：常驻、有 contentTitle、标准/进度类样式、
     * 渠道非 IMPORTANCE_MIN、非 colorized、无自定义 contentView、非组摘要。
     */
    @RequiresApi(36)
    private fun buildLive36(
        context: Context,
        title: String,
        body: String,
        progress: Int,
        progressMax: Int,
        criticalText: String?,
        dismiss: PendingIntent
    ): Notification {
        val builder = Notification.Builder(context, CHANNEL_LIVE)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setLargeIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
            .setColor(BRAND_COLOR)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_STATUS)
            .setDeleteIntent(dismiss)
            // 给用户明确的退出方式（官方对"非用户主动发起"类内容的建议）
            .addAction(Notification.Action.Builder(null, "取消关注", dismiss).build())
            // 兜底：生命周期异常结束时自动过期，不永久钉住
            .setTimeoutAfter(LIVE_TIMEOUT_MS)
            .setStyle(
                Notification.ProgressStyle()
                    .setProgress(progress)
                    .setProgressSegments(
                        listOf(Notification.ProgressStyle.Segment(progressMax))
                    )
            )

        // 状态栏小芯片文案（建议 ≤7 字符，如 "65%"）
        if (!criticalText.isNullOrBlank()) {
            builder.setShortCriticalText(criticalText)
        }

        // 申请晋升。setRequestPromotedOngoing / EXTRA_REQUEST_PROMOTED_ONGOING
        // 是 API 36.1（QPR1）才加入的，compileSdk 36 下用 extras 字符串键
        // 等价达成（36.0 上被忽略，36.1+ 生效）。
        builder.addExtras(Bundle().apply {
            putBoolean("android.requestPromotedOngoing", true)
        })

        launchPendingIntent(context)?.let { builder.setContentIntent(it) }
        return builder.build()
    }

    /** API 36 以下：普通常驻进度通知（仍原地更新，但系统不会晋升） */
    private fun buildLiveCompat(
        context: Context,
        title: String,
        body: String,
        progress: Int,
        progressMax: Int,
        dismiss: PendingIntent
    ): Notification =
        NotificationCompat.Builder(context, CHANNEL_LIVE)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setColor(BRAND_COLOR)
            .setProgress(progressMax, progress, false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setDeleteIntent(dismiss)
            .addAction(0, "取消关注", dismiss)
            .setTimeoutAfter(LIVE_TIMEOUT_MS)
            .apply { launchPendingIntent(context)?.let { setContentIntent(it) } }
            .build()

    /** 点击通知打开 APP */
    private fun launchPendingIntent(context: Context): PendingIntent? = try {
        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        PendingIntent.getActivity(
            context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    } catch (_: Throwable) {
        null
    }

    //==================== Live Update 划掉状态 ====================

    private fun livePrefs(context: Context) =
        context.getSharedPreferences(LIVE_PREFS, Context.MODE_PRIVATE)

    fun isLiveDismissed(context: Context): Boolean = try {
        livePrefs(context).getBoolean(LIVE_KEY, false)
    } catch (_: Throwable) {
        false
    }

    fun markLiveDismissed(context: Context) {
        try {
            livePrefs(context).edit().putBoolean(LIVE_KEY, true).apply()
        } catch (_: Throwable) {
        }
    }

    fun clearLiveDismissed(context: Context) {
        try {
            livePrefs(context).edit().remove(LIVE_KEY).apply()
        } catch (_: Throwable) {
        }
    }

    private fun liveDismissIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, LiveDismissReceiver::class.java)
            .setAction(ACTION_LIVE_DISMISSED)
            .putExtra(EXTRA_LIVE_ID, id)
        return PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Live Update 能力诊断（供实验室 Beta 弹窗展示）。
     *
     * 返回：liveApi36 / liveQpr1 / livePromotable / liveCanPost / liveDismissed
     */
    fun liveCapabilities(context: Context): HashMap<String, Any> {
        val m = HashMap<String, Any>()
        m["liveDismissed"] = isLiveDismissed(context)
        if (Build.VERSION.SDK_INT < 36) {
            m["liveApi36"] = false
            return m
        }
        m["liveApi36"] = true
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 用户总开关（Android 16 新增）
        m["liveCanPost"] = try {
            manager.canPostPromotedNotifications()
        } catch (_: Throwable) {
            false
        }

        // 是否 Android 16 QPR1（36.1）+：晋升 API 只在 36.1 存在，反射探测最准
        m["liveQpr1"] = try {
            val boolType = Boolean::class.javaPrimitiveType!!
            Notification.Builder::class.java.getMethod(
                "setRequestPromotedOngoing", boolType
            )
            true
        } catch (_: Throwable) {
            false
        }

        // 通知本身是否满足晋升条件（用与生产完全一致的构建路径探测）
        m["livePromotable"] = try {
            buildLive36(
                context, "本期收款进度", "探测", 0, 100, "0%",
                liveDismissIntent(context, -1)
            ).hasPromotableCharacteristics()
        } catch (_: Throwable) {
            false
        }
        return m
    }

    /**
     * 取消一条通知
     */
    fun cancel(context: Context, id: Int) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(id)
    }

    /**
     * 取消全部通知
     */
    fun cancelAll(context: Context) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancelAll()
    }
}
