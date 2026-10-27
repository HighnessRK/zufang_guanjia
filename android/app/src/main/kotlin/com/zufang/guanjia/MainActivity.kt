package com.zufang.guanjia

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.zufang.guanjia.notify.FocusNotificationHelper
import com.zufang.guanjia.notify.NotificationHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

/**
 * 主 Activity：承载 Flutter 引擎，并通过 MethodChannel 暴露原生能力。
 *
 * 暴露给 Dart 的方法：
 *   systemInfo           查询设备信息（厂商 / 型号 / 系统版本 / 是否小米）
 *   requestNotifyPermission  申请 Android 13+ 通知权限
 *   focusStatus          查询超级岛状态（协议版本 / 岛支持 / 焦点权限）
 *   showNotification     发送系统通知（可选焦点通知增强）
 *   cancelNotification   取消一条通知
 *   cancelAll            取消全部通知
 *   backup               备份数据库 + info.gwt 并分享
 *   pickBackupFile       弹出系统文件选择器选择备份包
 *   restore              用备份包覆盖数据库 + info.gwt
 *   shareImage           系统分享一张图片（电子收据转发微信等）
 *   saveImageToGallery   保存 PNG 到系统相册（Pictures/租房管家）
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "com.zufang.guanjia/native"
        private const val REQ_NOTIFY = 1001
        private const val REQ_PICK_BACKUP = 1002
        private const val REQ_STORAGE = 1003
        private const val TAG = "FocusNotify"
    }

    private var methodChannel: MethodChannel? = null

    /** 等待文件选择结果的 Dart 回调 */
    private var pendingPickResult: MethodChannel.Result? = null

    override fun onResume() {
        super.onResume()
        // 用户主动打开应用 = 重新关注：清除 Live Update 的"已划掉"记录，
        // 下一次定时刷新会恢复进度通知（否则划掉一次就永远不回来了）
        NotificationHelper.clearLiveDismissed(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 通知渠道初始化
        NotificationHelper.ensureChannels(this)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "configureUpdateSchedule" -> {
                    UpdateScheduler.configure(this,
                        call.argument<Boolean>("enabled") ?: true,
                        call.argument<String>("source") ?: "gitee",
                        call.argument<String>("version") ?: "0")
                    result.success(null)
                }

                //==================== 设备信息 ====================
                "systemInfo" -> {
                    val map = HashMap<String, Any>()
                    map["manufacturer"] = Build.MANUFACTURER ?: ""
                    map["model"] = Build.MODEL ?: ""
                    map["brand"] = Build.BRAND ?: ""
                    map["androidVersion"] = Build.VERSION.RELEASE ?: ""
                    map["sdkInt"] = Build.VERSION.SDK_INT
                    map["isXiaomi"] = FocusNotificationHelper.isXiaomiDevice()
                    result.success(map)
                }

                //==================== 通知权限 ====================
                "requestNotifyPermission" -> {
                    result.success(requestNotifyPermission())
                }

                //==================== 应用内更新：调起系统安装器 ====================
                "installApk" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("ENOENT", "APK 文件不存在", path)
                            return@setMethodCallHandler
                        }
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                uri, "application/vnd.android.package-archive"
                            )
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_ACTIVITY_NEW_TASK
                            )
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL", e.message, null)
                    }
                }

                //==================== 超级岛 / 焦点通知状态 ====================
                "focusStatus" -> {
                    // canShowFocus 是 provider call（耗时操作），整组查询放到后台线程
                    Thread {
                        val map = HashMap<String, Any>()
                        map["isXiaomi"] = FocusNotificationHelper.isXiaomiDevice()
                        map["protocol"] = FocusNotificationHelper.focusProtocolVersion(this)
                        map["supportIsland"] = FocusNotificationHelper.isSupportIsland()
                        map["hasFocusPermission"] =
                            FocusNotificationHelper.hasFocusPermission(this)
                        map["xmsfGate"] = FocusNotificationHelper.isXmsfGateReady(this)
                        map["ready"] = FocusNotificationHelper.isReadyForSuperIsland(this)
                        // Android 16 Live Update 能力（实验室 Beta 诊断用）
                        map.putAll(NotificationHelper.liveCapabilities(this))
                        Log.i(TAG, "focusStatus = $map")
                        runOnUiThread { result.success(map) }
                    }.start()
                }

                //==================== 发送通知 ====================
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val bigText = call.argument<String>("bigText")
                    val channelId = call.argument<String>("channelId")
                        ?: NotificationHelper.CHANNEL_GENERAL
                    val focus = call.argument<Boolean>("focus") ?: false
                    val ongoing = call.argument<Boolean>("ongoing") ?: false
                    val live = call.argument<Boolean>("live") ?: false
                    val restart = call.argument<Boolean>("restart") ?: false
                    val progress = call.argument<Int>("progress") ?: 0
                    val progressMax = call.argument<Int>("progressMax") ?: 100
                    val criticalText = call.argument<String>("criticalText")

                    if (live) {
                        // Android 16 Live Updates：同一 id 原地更新进度
                        NotificationHelper.postLive(
                            context = this,
                            id = id,
                            title = title,
                            body = body,
                            progress = progress,
                            progressMax = progressMax,
                            criticalText = criticalText,
                            restart = restart
                        )
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    // 焦点通知开启时，把渠道换成焦点渠道以获得更高展示优先级
                    val channel = if (focus) {
                        NotificationHelper.CHANNEL_FOCUS
                    } else {
                        channelId
                    }

                    // 仅下载渠道渲染进度条（其余通知 progress 恒为 0，
                    // 直传会把每条普通提醒画成 0% 进度条 → 传 -1 表示无进度）
                    val postProgress =
                        if (channel == NotificationHelper.CHANNEL_DOWNLOAD) progress else -1

                    NotificationHelper.post(
                        context = this,
                        id = id,
                        channelId = channel,
                        title = title,
                        body = body,
                        bigText = bigText,
                        ongoing = ongoing,
                        progress = postProgress,
                        progressMax = progressMax
                    )
                    result.success(null)
                }

                //==================== 取消通知 ====================
                "cancelNotification" -> {
                    NotificationHelper.cancel(this, call.argument<Int>("id") ?: 0)
                    result.success(null)
                }

                "cancelAll" -> {
                    NotificationHelper.cancelAll(this)
                    result.success(null)
                }

                //==================== 备份 ====================
                "backup" -> {
                    try {
                        val dbPath = call.argument<String>("dbPath") ?: ""
                        val configPath = call.argument<String>("configPath") ?: ""
                        val name = doBackup(dbPath, configPath)
                        result.success(name)
                    } catch (e: Exception) {
                        result.error("BACKUP_FAILED", e.message, null)
                    }
                }

                //==================== 备份（只写文件，不弹分享）====================
                // MCP create_backup / 数据管理页「生成备份文件」用：返回 zip 完整路径
                "backupToFile" -> {
                    try {
                        val dbPath = call.argument<String>("dbPath") ?: ""
                        val configPath = call.argument<String>("configPath") ?: ""
                        val out = writeBackupZip(dbPath, configPath)
                        result.success(out.absolutePath)
                    } catch (e: Exception) {
                        result.error("BACKUP_FAILED", e.message, null)
                    }
                }

                //==================== 列出备份 zip ====================
                // dirPath 为空 → 列应用备份目录；否则列指定目录（如小米互传）
                // 返回 [{name,path,size,modified}]，按修改时间倒序
                "listBackups" -> {
                    Thread {
                        val dirPath = call.argument<String>("dirPath") ?: ""
                        val list = listBackupZips(dirPath)
                        runOnUiThread { result.success(list) }
                    }.start()
                }

                //==================== 备份 / 数据目录路径 ====================
                // appBackupDir = 应用私有外部备份目录；miShareDir = 小米互传目录
                "backupDirs" -> {
                    val map = HashMap<String, Any>()
                    map["appBackupDir"] =
                        File(getExternalFilesDir(null), "backup").absolutePath
                    map["miShareDir"] = miShareDir().absolutePath
                    map["miShareExists"] = miShareDir().exists()
                    map["downloadDir"] =
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        ).absolutePath
                    result.success(map)
                }

                //==================== 存储读取权限 ====================
                // Android 11+ 读共享下载目录（小米互传 zip）需「所有文件访问」；
                // Android 10 走 READ_EXTERNAL_STORAGE 运行时申请。
                "hasStorageAccess" -> {
                    result.success(hasStorageAccess())
                }

                "requestStorageAccess" -> {
                    result.success(requestStorageAccess())
                }

                //==================== 选择备份包 ====================
                "pickBackupFile" -> {
                    pendingPickResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/zip"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "*/*"))
                    }
                    startActivityForResult(intent, REQ_PICK_BACKUP)
                }

                //==================== 恢复 ====================
                "restore" -> {
                    try {
                        val sourcePath = call.argument<String>("sourcePath") ?: ""
                        val dbPath = call.argument<String>("dbPath") ?: ""
                        val configPath = call.argument<String>("configPath") ?: ""
                        val ok = doRestore(sourcePath, dbPath, configPath)
                        result.success(ok)
                    } catch (e: Exception) {
                        result.error("RESTORE_FAILED", e.message, null)
                    }
                }

                //==================== 电子收据：分享图片 ====================
                // wechat=true 先直启微信分享页，未装微信回落系统分享面板
                "shareImage" -> {
                    try {
                        val path = call.argument<String>("path") ?: ""
                        val toWeChat = call.argument<Boolean>("wechat") ?: false
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("ENOENT", "图片文件不存在", path)
                            return@setMethodCallHandler
                        }
                        val uri: Uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        var done = false
                        if (toWeChat) {
                            try {
                                val wx = Intent(send).apply {
                                    setClassName(
                                        "com.tencent.mm",
                                        "com.tencent.mm.ui.tools.ShareImgUI"
                                    )
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(wx)
                                done = true
                            } catch (_: Throwable) {
                                done = false
                            }
                        }
                        if (!done) {
                            startActivity(
                                Intent.createChooser(send, "转发收据").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                            )
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE", e.message, null)
                    }
                }

                //==================== 电子收据：保存到相册 ====================
                // MediaStore Pictures/租房管家；Android 10+ 无需任何存储权限
                "saveImageToGallery" -> {
                    Thread {
                        try {
                            val path = call.argument<String>("path") ?: ""
                            saveImageToGallery(path)
                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("GALLERY", e.message, null)
                            }
                        }
                    }.start()
                }

                else -> result.notImplemented()
            }
        }
    }

    //========================= 通知权限 =========================

    /**
     * 申请通知权限：Android 13+ 需要运行时申请，低版本直接放行
     */
    private fun requestNotifyPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true

        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) return true

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQ_NOTIFY
        )
        // 以实际授权结果为准，这里先返回 true 让 Dart 不阻塞流程
        return true
    }

    //========================= 备份 / 恢复 =====================

    /**
     * 备份：把 rental.db + info.gwt 打成 zip，放到应用外部私有目录并调起系统分享
     *
     * @return 备份文件名
     */
    private fun doBackup(dbPath: String, configPath: String): String {
        val outFile = writeBackupZip(dbPath, configPath)

        // 调起系统分享，用户可发到微信 / 网盘 / 本地文件
        try {
            val uri: Uri = FileProvider.getUriForFile(
                this, "$packageName.fileprovider", outFile
            )
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "application/zip"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(
                Intent.createChooser(send, "保存租房管家备份").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        } catch (_: Throwable) {
            // 分享失败不影响备份文件已生成
        }

        return outFile.name
    }

    /**
     * 保存 PNG 到系统相册：MediaStore 写入 Pictures/租房管家。
     * Android 10+ 走 RELATIVE_PATH + IS_PENDING，无需任何存储运行时权限。
     */
    private fun saveImageToGallery(path: String) {
        val file = File(path)
        if (!file.exists()) throw IllegalArgumentException("图片文件不存在: $path")

        val values = ContentValues().apply {
            put(
                MediaStore.Images.Media.DISPLAY_NAME,
                "收据_${SimpleDateFormat(
                    "yyyyMMdd_HHmmss", Locale.getDefault()
                ).format(Date())}.png"
            )
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/租房管家"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
        ) ?: throw IllegalStateException("无法写入相册")

        resolver.openOutputStream(uri)?.use { out ->
            FileInputStream(file).use { input -> input.copyTo(out) }
        } ?: throw IllegalStateException("无法打开输出流")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
    }

    /**
     * 只写备份 zip 到应用外部备份目录（不弹分享）——
     * MCP 的 create_backup 与数据管理页「生成备份文件」共用
     */
    private fun writeBackupZip(dbPath: String, configPath: String): File {
        val dir = File(getExternalFilesDir(null), "backup")
        if (!dir.exists()) dir.mkdirs()

        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val outFile = File(dir, "zufang_guanjia_backup_$stamp.zip")

        ZipOutputStream(FileOutputStream(outFile)).use { zos ->
            putFileIntoZip(zos, File(dbPath), "rental.db")
            putFileIntoZip(zos, File(configPath), "info.gwt")
        }
        return outFile
    }

    /**
     * 小米互传备份目录：内部存储/Download/MiShare
     * （小米互传 / 超级终端互传默认的接收路径）
     */
    private fun miShareDir(): File {
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        return File(downloads, "MiShare")
    }

    /**
     * 列出目录下的备份 zip，按修改时间倒序（最新在前）。
     *
     * @param dirPath 空串 → 应用备份目录；否则解析该路径
     * （读不到时回落应用备份目录），目录不存在 / 无权限返回空列表
     * @return [{name, path, size, modified}]
     */
    private fun listBackupZips(dirPath: String): List<Map<String, Any>> {
        val dir = if (dirPath.isBlank()) {
            File(getExternalFilesDir(null), "backup")
        } else {
            File(dirPath)
        }
        if (!dir.isDirectory) return emptyList()

        val files = dir.listFiles { f ->
            f.isFile && f.extension.equals("zip", ignoreCase = true)
        } ?: return emptyList()

        return files
            .sortedByDescending { it.lastModified() }
            .map { f ->
                val map = HashMap<String, Any>()
                map["name"] = f.name
                map["path"] = f.absolutePath
                map["size"] = f.length()
                map["modified"] = f.lastModified()
                map
            }
    }

    //========================= 存储读取权限 =====================

    /**
     * 是否已能读共享存储（Download/MiShare 等）：
     *   Android 11+ → Environment.isExternalStorageManager()
     *   Android 10  → READ_EXTERNAL_STORAGE 运行时授权
     *   Android 9-  → 安装时授权，恒为 true
     */
    private fun hasStorageAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * 申请共享存储读取权限（拉起「所有文件访问」设置页 / 运行时授权）。
     * 返回 true 表示已发起申请（或低版本本就具备）。
     */
    private fun requestStorageAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                )
                true
            } catch (_: Throwable) {
                // 部分 ROM 无该细分设置页 → 退回「所有文件访问」总设置
                try {
                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                    true
                } catch (_: Throwable) {
                    false
                }
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (hasStorageAccess()) return true
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
            REQ_STORAGE
        )
        return true
    }

    /**
     * 把单个文件写入 zip
     */
    private fun putFileIntoZip(zos: ZipOutputStream, file: File, entryName: String) {
        if (!file.exists()) return
        zos.putNextEntry(ZipEntry(entryName))
        FileInputStream(file).use { input ->
            input.copyTo(zos)
        }
        zos.closeEntry()
    }

    /**
     * 恢复：解压备份包，把 rental.db / info.gwt 覆盖回去
     */
    private fun doRestore(sourcePath: String, dbPath: String, configPath: String): Boolean {
        val source = File(sourcePath)
        if (!source.exists()) return false

        var dbBytes: ByteArray? = null
        var cfgBytes: ByteArray? = null

        ZipInputStream(FileInputStream(source)).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val bytes = zis.readBytes()
                when (entry.name) {
                    "rental.db" -> dbBytes = bytes
                    "info.gwt" -> cfgBytes = bytes
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }

        val db = dbBytes ?: return false

        // 先做最小完整性校验，再以临时文件替换；损坏/伪造 zip 不得破坏当前数据。
        if (db.size < 100 || !db.copyOfRange(0, 16).contentEquals(
                "SQLite format 3\u0000".toByteArray(Charsets.US_ASCII))) return false
        val dbFile = File(dbPath)
        val dbTemp = File(dbPath + ".restore.tmp")
        val cfgFile = if (configPath.isNotBlank()) File(configPath) else null
        val cfgTemp = cfgFile?.let { File(it.path + ".restore.tmp") }
        try {
            dbTemp.writeBytes(db)
            if (cfgBytes != null && cfgTemp != null) cfgTemp.writeBytes(cfgBytes!!)
            if (!dbTemp.renameTo(dbFile)) return false
            if (cfgTemp != null && !cfgTemp.renameTo(cfgFile!!)) return false
        } finally {
            dbTemp.delete()
            cfgTemp?.delete()
        }
        return true
    }

    //========================= 文件选择回调 =====================

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQ_PICK_BACKUP) {
            val result = pendingPickResult
            pendingPickResult = null

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
                return
            }

            try {
                val uri: Uri = data.data!!
                // 把 content:// 流复制到缓存文件，方便 Dart / 原生统一按路径读取
                val tmp = File(cacheDir, "restore_backup.zip")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(tmp).use { output -> input.copyTo(output) }
                }
                result?.success(tmp.absolutePath)
            } catch (e: Exception) {
                result?.error("PICK_FAILED", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
    }
}
