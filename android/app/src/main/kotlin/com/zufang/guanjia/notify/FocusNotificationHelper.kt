package com.zufang.guanjia.notify

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.text.htmlEncode
import com.zufang.guanjia.R
import org.json.JSONObject

/**
 * 小米澎湃OS / HyperOS「焦点通知 → 超级岛」适配层。
 *
 * ┌──────────────────────────────────────────────────────────────────────┐
 * │ 实现依据（官方文档 + 开源参考 Xiaomi-SuperIsland-Playground）        │
 * │                                                                      │
 * │ 1. OS3 超级岛走 FocusTemplateV3 模板：                                │
 * │    根节点 type = "...FocusTemplateFactory.V3" + param_v2；           │
 * │    参数结构、字段名全部对齐参考实现中已在真机验证的构建代码。          │
 * │ 2. 通过 XMSF 校验门发送（关键差异）：                                 │
 * │    发送前用 HyperOS 隐藏 API updateAurogonUidRule 短暂阻断 XMSF      │
 * │    网络 220ms，让系统走本地校验分支接受岛参数，发送后立即恢复。       │
 * │    该流程由 [postWithValidation] 在后台线程执行。                     │
 * │ 3. 查询接口（均为官方 API）：                                        │
 * │    - Settings.System "notification_focus_protocol"：                │
 * │      0=不支持 1=OS1 2=OS2 3=OS3 超级岛模板；                        │
 * │    - SystemProperties "persist.sys.feature.island"：是否支持岛；     │
 * │    - provider call "canShowFocus"：本应用焦点通知权限是否开启。      │
 * │ 4. 设计原则：能上岛就上岛，不能就安全降级为普通通知，绝不崩溃、      │
 * │    绝不影响普通通知的正常送达。                                      │
 * └──────────────────────────────────────────────────────────────────────┘
 */
object FocusNotificationHelper {

    private const val TAG = "FocusNotify"

    // ====== 对齐参考实现与本机系统真实样例的协议常量 ======
    // 根节点 type（FocusTemplateFactory.V3）经本机 dumpsys 对比系统热点样例后弃用：
    // 系统自己的岛 payload 没有根 type，疑似带 type 会走平台模板注册校验。
    private const val FOCUS_PARAM = "miui.focus.param"
    private const val FOCUS_PICS = "miui.focus.pics"
    private const val LOGO_KEY = "miui.focus.pic_island_logo"
    private const val PRIMARY_KEY = "miui.focus.pic_island_primary"
    private const val SECONDARY_KEY = "miui.focus.pic_island_secondary"
    /** 本机系统真实使用的岛图片 key（热点岛实测） */
    private const val PIC_KEY = "miui.focus.pic_summay"
    private const val BUSINESS_NAME = "custom_island"
    private const val ACCENT = "#3482FF"
    private const val MAX_FOCUS_PARAMETER_BYTES = 3072
    private const val XMSF_VALIDATION_WINDOW_MS = 220L
    private const val FOCUS_TIMEOUT_MINUTES = 120
    private const val ISLAND_TIMEOUT_SECONDS = 7200

    /** Aurogon 校验门（进程内单例，方法内部有同步） */
    @Volatile
    private var gate: XiaomiAurogonGate? = null

    private fun gate(context: Context): XiaomiAurogonGate =
        gate ?: synchronized(this) {
            gate ?: XiaomiAurogonGate(context).also { gate = it }
        }

    /** 焦点通知协议版本：0=不支持 1=OS1 2=OS2 3=OS3 超级岛 */
    fun focusProtocolVersion(context: Context): Int = try {
        Settings.System.getInt(
            context.contentResolver,
            "notification_focus_protocol",
            0
        )
    } catch (_: Throwable) {
        0
    }

    /** 系统是否支持超级岛（persist.sys.feature.island） */
    fun isSupportIsland(): Boolean = try {
        val clazz = Class.forName("android.os.SystemProperties")
        val method = clazz.getDeclaredMethod(
            "getBoolean",
            String::class.java,
            Boolean::class.javaPrimitiveType
        )
        val value = method.invoke(null, "persist.sys.feature.island", false)
        value as? Boolean ?: false
    } catch (_: Throwable) {
        false
    }

    /** 岛功能属性：true=开启 false=关闭 null=查询失败（参考实现将 null 视为可用） */
    private fun islandFeature(): Boolean? = try {
        val clazz = Class.forName("android.os.SystemProperties")
        val method = clazz.getDeclaredMethod(
            "getBoolean",
            String::class.java,
            Boolean::class.javaPrimitiveType
        )
        method.invoke(null, "persist.sys.feature.island", false) as? Boolean
    } catch (_: Throwable) {
        null
    }

    /**
     * 本应用焦点通知权限是否开启（官方接口，provider call 属耗时操作，
     * 调用方应放到后台线程）。任何异常按未开启处理。
     */
    fun hasFocusPermission(context: Context): Boolean = try {
        val uri = Uri.parse("content://miui.statusbar.notification.public")
        val extras = Bundle().apply { putString("package", context.packageName) }
        val bundle = context.contentResolver.call(uri, "canShowFocus", null, extras)
        bundle?.getBoolean("canShowFocus", false) ?: false
    } catch (_: Throwable) {
        false
    }

    /** XMSF 校验门是否可用（Aurogon 隐藏 API 存在 + XMSF 可见） */
    fun isXmsfGateReady(context: Context): Boolean = try {
        isXiaomiDevice() && gate(context).isSupported()
    } catch (_: Throwable) {
        false
    }

    /**
     * 能否真正上超级岛 —— 判定口径与参考实现 detectCapability 一致：
     * 小米设备 + 协议 >= 3 + XMSF 校验门可用 + 岛功能未被明确关闭。
     */
    fun isReadyForSuperIsland(context: Context): Boolean = try {
        isXiaomiDevice() &&
                focusProtocolVersion(context) >= 3 &&
                gate(context).isSupported() &&
                islandFeature() != false
    } catch (_: Throwable) {
        false
    }

    /**
     * 带 XMSF 校验的发送流程（必须在后台线程调用）：
     * 阻断 XMSF → notify → 等待 220ms 校验窗口 → 恢复规则。
     *
     * 任何一步失败都降级为普通发送，保证通知一定送达。
     */
    fun postWithValidation(
        context: Context,
        manager: NotificationManager,
        id: Int,
        notification: Notification
    ): Boolean {
        val g = gate(context)
        return try {
            val ready = isReadyForSuperIsland(context)
            if (ready && g.isSupported() && g.setXmsfBlocked(true)) {
                try {
                    manager.notify(id, notification)
                    try {
                        Thread.sleep(XMSF_VALIDATION_WINDOW_MS)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                    Log.i(TAG, "postWithValidation: island posted (id=$id)")
                    true
                } finally {
                    if (!g.restoreIfNeeded()) {
                        Log.e(TAG, "HyperOS did not confirm XMSF validation restoration")
                    }
                }
            } else {
                Log.i(TAG, "postWithValidation: plain notify (id=$id, ready=$ready)")
                manager.notify(id, notification)
                true
            }
        } catch (t: Throwable) {
            Log.w(TAG, "postWithValidation failed, fallback: $t")
            try {
                manager.notify(id, notification)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    /**
     * 给通知附加超级岛 / 焦点通知参数。
     * 非小米设备 / 协议不支持 / 任何异常都安全忽略（保持普通通知形态）。
     *
     * @return 是否成功附加了焦点参数
     */
    fun applyFocus(
        context: Context,
        builder: NotificationCompat.Builder,
        title: String,
        body: String
    ): Boolean {
        return try {
            if (!isXiaomiDevice()) {
                Log.i(TAG, "applyFocus: skip, not a xiaomi/redmi/poco device")
                return false
            }
            val protocol = focusProtocolVersion(context)
            if (protocol <= 0) {
                Log.i(TAG, "applyFocus: skip, focus protocol unsupported (protocol=$protocol)")
                return false
            }

            val extras = Bundle()
            val param: String
            if (protocol >= 3) {
                // OS3 超级岛：FocusTemplateV3 模板 + 岛图片 + 首帧浮出参数
                val icon = Icon.createWithResource(context, R.mipmap.ic_launcher)
                val pics = Bundle().apply {
                    putParcelable(PIC_KEY, icon) // 系统实测存在的 key
                    putParcelable(LOGO_KEY, icon)
                    putParcelable(PRIMARY_KEY, icon)
                    putParcelable(SECONDARY_KEY, icon)
                }
                extras.putBundle(FOCUS_PICS, pics)
                extras.putBoolean("miui.island.updateNoFloat", false)
                extras.putBoolean("miui.island.firstFloat", true)
                extras.putBoolean("miui.enableFloat", true)
                param = buildFocusV3(context, title, body)
            } else if (protocol >= 2) {
                // OS2：param_v2 通用岛模板 + 图片 Bundle
                val icon = Icon.createWithResource(context, R.drawable.ic_notification)
                val pics = Bundle()
                pics.putParcelable("miui.focus.pic_imageText", icon)
                pics.putParcelable("miui.focus.pic_ticker", icon)
                pics.putParcelable("miui.focus.pic_aod", icon)
                extras.putBundle(FOCUS_PICS, pics)
                param = buildParamV2(context, title, body)
            } else {
                // OS1：旧版焦点协议字段
                extras.putString("miui.focus.ticker", body)
                extras.putString("miui.focus.title", title)
                extras.putString("miui.focus.icon_id", "ic_notification")
                param = buildParamOs1(title, body)
            }
            extras.putString(FOCUS_PARAM, param)
            Log.i(TAG, "applyFocus: protocol=$protocol param=$param")
            builder.addExtras(extras)
            true
        } catch (t: Throwable) {
            // 任何异常都不影响普通通知的发送
            Log.w(TAG, "applyFocus failed: $t")
            false
        }
    }

    /**
     * 构建 OS3 超级岛参数 JSON（对齐本机系统真实样例）。
     *
     * 依据本机 dumpsys 抓取的系统热点岛 payload 修正：
     *   根节点不带 type（系统自己的岛 payload 就没有，带 type 疑似触发平台模板注册校验）
     *   bigIslandArea = { imageTextInfoLeft{type,picInfo}, textInfo{...} }（textInfo 平级）
     *   param_island   = { islandProperty, dismissIsland, bigIslandArea, smallIslandArea }
     *   图片 key 用系统实测存在的 miui.focus.pic_summay
     */
    private fun buildFocusV3(context: Context, title: String, body: String): String {
        return try {
            val content = body.ifBlank { " " }

            // 下拉通知中心（参考实现 TEXT_TWO 模板）
            val baseInfo = JSONObject()
                .put("type", 2)
                .put("title", title.htmlEncode())
                .put("content", content.htmlEncode())
                .put("showDivider", false)
                .put("colorTitle", ACCENT)
                .put("colorTitleDark", ACCENT)

            // 大岛区域：对齐本机系统自带热点岛 dumpsys 抓到的真实结构
            // （imageTextInfoLeft 只放 type+picInfo，textInfo 是它的兄弟节点；
            //   注意 pic key 用系统实测存在的 miui.focus.pic_summay）
            val picInfo = JSONObject().put("type", 1).put("pic", PIC_KEY)
            val bigIsland = JSONObject().apply {
                put(
                    "imageTextInfoLeft",
                    JSONObject().put("type", 1).put("picInfo", picInfo)
                )
                put("textInfo", JSONObject().apply {
                    put("title", title.ifBlank { " " })
                    put("content", content)
                    put("useHighLight", false)
                })
            }
            val smallIsland = JSONObject().put("picInfo", picInfo)

            // 岛属性：字段集对齐系统热点样例（islandProperty + dismissIsland）
            val island = JSONObject().apply {
                put("islandProperty", 1) // INFORMATION
                put("dismissIsland", false)
                put("bigIslandArea", bigIsland)
                put("smallIslandArea", smallIsland)
            }

            // 基础 / 交互数据（本机热点样例：无根 type，业务字段保留）
            val v2 = JSONObject()
                .put("protocol", 1)
                .put("business", BUSINESS_NAME)
                .put("ticker", title)
                .put("tickerPic", PIC_KEY)
                .put("aodTitle", title)
                .put("aodPic", PIC_KEY)
                .put("updatable", true) // 非 updatable 会被系统当一次性通知点完即消
                .put("reopen", "close")
                .put("enableFloat", true) // 首帧允许浮出
                .put("islandFirstFloat", true)
                .put("timeout", FOCUS_TIMEOUT_MINUTES)
                .put("baseInfo", baseInfo)
                .put("param_island", island)

            // 注意：本机系统自带的岛 payload（热点）根节点没有 type 字段，
            // 疑似根 type 会走"平台注册模板"校验导致第三方被拒，
            // 因此这里只发 {"param_v2":{...}}
            val payload = JSONObject()
                .put("param_v2", v2)
                .toString()
            if (payload.toByteArray(Charsets.UTF_8).size > MAX_FOCUS_PARAMETER_BYTES) {
                Log.w(TAG, "focus payload exceeds $MAX_FOCUS_PARAMETER_BYTES bytes")
            }
            payload
        } catch (_: Throwable) {
            "{}"
        }
    }

    /**
     * 构建 OS2 的 param_v2 JSON（超级岛大岛 / 小岛 / 状态栏 / 息屏）。
     *
     * 字段依据官方「模版接入示例」：
     *   protocol/business/enableFloat/updatable 交互能力
     *   ticker + tickerPic   状态栏滚动文案与图标
     *   aodTitle + aodPic    息屏显示
     *   param_island         岛数据（大岛 A 区图文 / 小岛图标）
     *   baseInfo             焦点通知内容（下拉通知中心展示）
     */
    private fun buildParamV2(context: Context, title: String, body: String): String {
        return try {
            val label = appLabel(context)

            // 大岛 A 区：品牌小标题 + 主标题 + 内容
            val islandText = JSONObject().apply {
                put("frontTitle", label)
                put("title", title)
                put("content", body)
                put("useHighLight", false)
            }
            val pic = JSONObject().apply {
                put("type", 1)
                put("pic", "miui.focus.pic_imageText")
            }
            val imageTextLeft = JSONObject().apply {
                put("type", 1)
                put("picInfo", pic)
                put("miui.focus.paramtextInfo", islandText)
            }
            val bigIsland = JSONObject().apply {
                put("imageTextInfoLeft", imageTextLeft)
                put("picInfo", pic)
            }
            val smallIsland = JSONObject().apply { put("picInfo", pic) }
            val island = JSONObject().apply {
                put("islandProperty", 1)
                put("islandTimeout", ISLAND_TIMEOUT_SECONDS)
                put("bigIslandArea", bigIsland)
                put("smallIslandArea", smallIsland)
            }
            val baseInfo = JSONObject().apply {
                put("title", title)
                put("content", body)
                put("type", 2)
            }
            val v2 = JSONObject().apply {
                put("protocol", 1)
                put("business", "rent_remind") // 运营场景（数据统计）
                put("enableFloat", true)
                put("updatable", true)
                put("timeout", FOCUS_TIMEOUT_MINUTES)
                put("filterWhenNoPermission", false) // 无焦点权限时降级为普通通知
                put("ticker", body)
                put("tickerPic", "miui.focus.pic_ticker")
                put("aodTitle", "$label $title")
                put("aodPic", "miui.focus.pic_aod")
                put("param_island", island)
                put("baseInfo", baseInfo)
            }
            JSONObject().apply { put("param_v2", v2) }.toString()
        } catch (_: Throwable) {
            "{}"
        }
    }

    /** OS1 旧版焦点参数（text1/text2 通用文本位） */
    private fun buildParamOs1(title: String, body: String): String {
        return try {
            val json = JSONObject()
            json.put("type", 1)
            json.put("template", "rent_remind")
            val param = JSONObject()
            param.put("text1", title)
            param.put("text2", body)
            json.put("param", param)
            json.toString()
        } catch (_: Throwable) {
            "{}"
        }
    }

    /** 应用显示名（岛文案的品牌小标题） */
    private fun appLabel(context: Context): String = try {
        context.applicationInfo.loadLabel(context.packageManager).toString()
    } catch (_: Throwable) {
        "租房管家"
    }

    /** 是否当前设备为小米 / Redmi / POCO */
    fun isXiaomiDevice(): Boolean {
        val manufacturer = Build.MANUFACTURER ?: ""
        return manufacturer.equals("Xiaomi", ignoreCase = true) ||
                manufacturer.equals("Redmi", ignoreCase = true) ||
                manufacturer.equals("POCO", ignoreCase = true)
    }
}
