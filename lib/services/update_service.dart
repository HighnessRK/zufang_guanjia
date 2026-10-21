import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import 'native_bridge.dart';

/// 远端最新版本信息（GitHub / Gitee Release 解析结果）
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.source,
    this.apkUrl,
    this.apkSize,
    this.pageUrl = '',
  });

  /// 语义化版本号（可能带 v 前缀，比较前会剥掉）
  final String version;

  /// Release tag（如 v1.0.0）
  final String tag;

  /// Release 说明正文（更新日志）
  final String notes;

  /// 'github' / 'gitee'
  final String source;

  /// APK 匿名可下载直链
  final String? apkUrl;

  /// APK 体积（字节）
  final int? apkSize;

  /// Release 页面地址（直链不可用时兜底跳转浏览器）
  final String pageUrl;
}

/// 应用内更新服务：检查 GitHub / Gitee 最新 Release、下载 APK、调起系统安装。
///
/// 仅在「自动检查更新」（启动时静默）或「关于 → 检查更新」时联网，
/// 其余功能全部本地运行。
class UpdateService {
  UpdateService._();

  /// 版本比较：a > b → 1 / 相等 → 0 / a < b → -1。
  /// 容忍 v 前缀与位数差异（1.0 == 1.0.0）。
  static int compareVersion(String a, String b) {
    final List<int> pa = _parseVersion(a);
    final List<int> pb = _parseVersion(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  static List<int> _parseVersion(String v) {
    final String clean = v.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final List<int> out = <int>[0, 0, 0];
    final List<String> parts = clean.split(RegExp(r'[.+-]'));
    for (int i = 0; i < parts.length && i < 3; i++) {
      out[i] = int.tryParse(RegExp(r'^\d+').stringMatch(parts[i]) ?? '') ?? 0;
    }
    return out;
  }

  /// 检查当前下载源的最新版本；无 Release / 网络失败返回 null
  static Future<UpdateInfo?> checkLatest() async {
    try {
      return await (AppConfig.instance.updateSource == 'github'
          ? _checkGitHub()
          : _checkGitee());
    } catch (_) {
      return null;
    }
  }

  /// GitHub：GET /repos/{owner}/{repo}/releases/latest
  static Future<UpdateInfo?> _checkGitHub() async {
    final Uri uri = Uri.parse(
        'https://api.github.com/repos/${AppConstants.updateRepoGitHubOwner}'
        '/${AppConstants.updateRepoName}/releases/latest');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github+json');
      // GitHub API 强制要求 User-Agent
      request.headers.set('User-Agent', 'zufang-guanjia-updater');
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return null;
      final String body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final String tag = (json['tag_name'] ?? '') as String;
      if (tag.isEmpty) return null;
      final List<dynamic>? assets = json['assets'] as List<dynamic>?;
      return UpdateInfo(
        version: tag,
        tag: tag,
        notes: (json['body'] ?? '') as String,
        source: 'github',
        apkUrl: _pickApkUrl(assets),
        apkSize: _pickApkSize(assets),
        pageUrl: (json['html_url'] ?? '') as String,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Gitee：GET /repos/{owner}/{repo}/releases（取非草稿的最高版本）
  static Future<UpdateInfo?> _checkGitee() async {
    final Uri uri = Uri.parse(
        'https://gitee.com/api/v5/repos/${AppConstants.updateRepoGiteeOwner}'
        '/${AppConstants.updateRepoName}/releases?per_page=50');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'zufang-guanjia-updater');
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) return null;
      final String body = await response.transform(utf8.decoder).join();
      final List<dynamic> list = jsonDecode(body) as List<dynamic>;
      Map<String, dynamic>? best;
      for (final dynamic e in list) {
        final Map<String, dynamic> m = e as Map<String, dynamic>;
        if (m['draft'] == true || m['prerelease'] == true) continue;
        final String tag = (m['tag_name'] ?? '') as String;
        if (tag.isEmpty) continue;
        if (best == null ||
            compareVersion(
                    tag, (best['tag_name'] ?? '') as String) >
                0) {
          best = m;
        }
      }
      if (best == null) return null;
      final String tag = (best['tag_name'] ?? '') as String;
      // Gitee 附件字段在 assets / attachments 间有过变动，双兜底
      final List<dynamic>? assets = (best['assets'] as List<dynamic>?) ??
          (best['attachments'] as List<dynamic>?);
      return UpdateInfo(
        version: tag,
        tag: tag,
        notes: (best['body'] ?? best['name'] ?? '') as String,
        source: 'gitee',
        apkUrl: _pickApkUrl(assets),
        apkSize: _pickApkSize(assets),
        pageUrl: (best['html_url'] ?? '') as String,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// 从 Release 附件列表里挑体积最大的 .apk 直链
  static String? _pickApkUrl(List<dynamic>? assets) {
    String? url;
    int best = -1;
    for (final dynamic a in assets ?? const <dynamic>[]) {
      final Map<String, dynamic> m = a as Map<String, dynamic>;
      final String name = ((m['name'] ?? '') as String).toLowerCase();
      if (!name.endsWith('.apk')) continue;
      final String u = (m['browser_download_url'] ??
          m['download_url'] ??
          '') as String;
      final int size = (m['size'] as num?)?.toInt() ?? 0;
      if (u.isNotEmpty && size > best) {
        best = size;
        url = u;
      }
    }
    return url;
  }

  static int? _pickApkSize(List<dynamic>? assets) {
    for (final dynamic a in assets ?? const <dynamic>[]) {
      final Map<String, dynamic> m = a as Map<String, dynamic>;
      final String name = ((m['name'] ?? '') as String).toLowerCase();
      if (!name.endsWith('.apk')) continue;
      return (m['size'] as num?)?.toInt();
    }
    return null;
  }

  /// 下载 APK 到应用缓存目录（FileProvider 已覆盖 cache/）；
  /// [onProgress] 上报 0.0~1.0。
  static Future<File> downloadApk(
      String url, void Function(double progress) onProgress) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final int total = response.contentLength;
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/zufang_guanjia_update.apk');
      final IOSink sink = file.openWrite();
      int received = 0;
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            onProgress((received / total).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (total > 0 && received < total) {
        throw const HttpException('下载不完整');
      }
      onProgress(1.0);
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// 调起系统安装器安装已下载的 APK
  static Future<void> installApk(String path) =>
      NativeBridge.installApk(path);
}
