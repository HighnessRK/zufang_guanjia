package com.zufang.guanjia.notify

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Process
import android.util.Log
import org.lsposed.hiddenapibypass.HiddenApiBypass

/**
 * HyperOS「Aurogon 校验门」：短暂切换 XMSF（小米推送服务框架）的网络规则，
 * 让系统在 notify 时走本地校验分支，从而接受第三方应用的超级岛参数。
 *
 * 移植自开源参考实现 Xiaomi-SuperIsland-Playground 的 XiaomiAurogonNetworkGate：
 *   - 通过 HiddenApiBypass 调用 ConnectivityManager 隐藏方法
 *     updateAurogonUidRule(uid, blocked)（HyperOS Aurogon / 灵动子系统）；
 *   - 只改 XMSF 这一个 UID 的规则，且发送后必须恢复，避免影响其他应用；
 *   - 任何一步失败都返回 false，由调用方降级为普通通知，绝不崩溃。
 */
class XiaomiAurogonGate(context: Context) {

    private val appContext: Context = context.applicationContext
    private val connectivityManager: ConnectivityManager? =
        appContext.getSystemService(ConnectivityManager::class.java)

    private var cachedXmsfUid: Int? = null
    private var cachedSupported: Boolean? = null
    private var blockedByThisInstance = false

    /** 设备是否具备校验门能力（XMSF 可见 + 隐藏 API 存在） */
    @Synchronized
    fun isSupported(): Boolean {
        cachedSupported?.let { return it }
        val uid = resolveXmsfUid()
        val method = hasAurogonMethod()
        val supported = connectivityManager != null && uid != null && method
        cachedSupported = supported
        Log.i(TAG, "Aurogon gate: supported=$supported xmsfUid=$uid method=$method")
        return supported
    }

    /** 打开 / 关闭 XMSF 网络规则，成功返回 true */
    @Synchronized
    fun setXmsfBlocked(blocked: Boolean): Boolean {
        val manager = connectivityManager ?: return false
        val uid = resolveXmsfUid() ?: return false
        if (!isSupported()) return false

        if (blocked) blockedByThisInstance = true
        return try {
            HiddenApiBypass.invoke(
                ConnectivityManager::class.java,
                manager,
                "updateAurogonUidRule",
                uid,
                blocked
            )
            if (!blocked) blockedByThisInstance = false
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Unable to ${if (blocked) "arm" else "restore"} XMSF validation", t)
            false
        }
    }

    /** 恢复本实例打开过的规则（幂等），返回是否恢复成功 */
    @Synchronized
    fun restoreIfNeeded(): Boolean = !blockedByThisInstance || setXmsfBlocked(false)

    private fun hasAurogonMethod(): Boolean = try {
        val method = HiddenApiBypass.getDeclaredMethod(
            ConnectivityManager::class.java,
            "updateAurogonUidRule",
            Int::class.javaPrimitiveType,
            Boolean::class.javaPrimitiveType
        )
        method.returnType == Void.TYPE
    } catch (t: Throwable) {
        Log.i(TAG, "HyperOS Aurogon API unavailable: $t")
        false
    }

    private fun resolveXmsfUid(): Int? {
        cachedXmsfUid?.let { return it }
        return try {
            val pm = appContext.packageManager
            val info: ApplicationInfo = if (Build.VERSION.SDK_INT >= 33) {
                pm.getApplicationInfo(XMSF_PACKAGE, PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(XMSF_PACKAGE, 0)
            }
            if (info.uid < Process.FIRST_APPLICATION_UID) {
                null
            } else {
                cachedXmsfUid = info.uid
                info.uid
            }
        } catch (t: Throwable) {
            Log.i(TAG, "XMSF is not visible on this device: $t")
            null
        }
    }

    companion object {
        private const val TAG = "FocusNotify"
        private const val XMSF_PACKAGE = "com.xiaomi.xmsf"
    }
}
