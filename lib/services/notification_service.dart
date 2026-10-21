import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../data/models/notice_item.dart';
import 'native_bridge.dart';
import 'reminder_engine.dart';

/// 三端通知调度中心：
///   1. APP 内置通知中心（[notices] 列表，界面实时消费）；
///   2. 通用 Android 系统通知（渠道分级、大文本、可常驻）；
///   3. Android 16 Live Update「本期收款进度」晋升常驻通知
///      （低版本 / 不支持时自动降级为普通进度通知）。
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// 内置通知中心数据源（UI 通过 ValueListenableBuilder 监听）
  final ValueNotifier<List<NoticeItem>> notices =
      ValueNotifier<List<NoticeItem>>(<NoticeItem>[]);

  /// 未读数量
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// 是否已完成初始化
  bool _inited = false;

  //========================= 初始化 ==========================

  /// 启动时调用一次
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    final AppConfig cfg = AppConfig.instance;

    // Android 13+ 需要运行时申请通知权限
    if (cfg.notifyEnabled) {
      await NativeBridge.requestNotifyPermission();
    }

    // 首次检查
    await refresh();
  }

  //========================= 刷新提醒 ========================

  /// 重新计算提醒，并按配置推送系统通知 / 焦点通知
  Future<void> refresh() async {
    final AppConfig cfg = AppConfig.instance;
    final List<NoticeItem> list = await ReminderEngine.computeAll();
    notices.value = list;
    _updateUnread(list);

    if (!cfg.notifyEnabled) return;

    // 分类归集，避免刷屏：每类最多推送一条汇总
    final List<NoticeItem> rent = _pick(list, 'rent');
    final List<NoticeItem> expire = _pick(list, 'expire');
    final List<NoticeItem> utility = _pick(list, 'utility');

    if (rent.isNotEmpty) {
      await _push(
        id: AppConstants.notifyIdRent,
        channelId: AppConstants.channelRent,
        title: '房租提醒（${rent.length} 条）',
        body: rent.first.body,
        bigText: rent.map((NoticeItem e) => '• ${e.title}\n  ${e.body}').join('\n'),
      );
    } else {
      await NativeBridge.cancelNotification(AppConstants.notifyIdRent);
    }

    if (expire.isNotEmpty) {
      await _push(
        id: AppConstants.notifyIdExpire,
        channelId: AppConstants.channelRent,
        title: '租期提醒（${expire.length} 条）',
        body: expire.first.body,
        bigText:
            expire.map((NoticeItem e) => '• ${e.title}\n  ${e.body}').join('\n'),
      );
    } else {
      await NativeBridge.cancelNotification(AppConstants.notifyIdExpire);
    }

    if (utility.isNotEmpty) {
      await _push(
        id: AppConstants.notifyIdUtility,
        channelId: AppConstants.channelUtility,
        title: '水电费提醒（${utility.length} 条）',
        body: utility.first.body,
        bigText:
            utility.map((NoticeItem e) => '• ${e.title}\n  ${e.body}').join('\n'),
      );
    } else {
      await NativeBridge.cancelNotification(AppConstants.notifyIdUtility);
    }

    // Android 16 Live Updates：「本期收款进度」晋升常驻通知。
    // 同一 id 原地更新（状态栏芯片 / 通知栏置顶 / 锁屏醒目位，
    // 需 Android 16 QPR1；低版本降级为普通进度通知，永不阻塞提醒主流程）。
    if (cfg.focusEnabled) {
      final HomeStat stat = await ReminderEngine.computeHomeStat();
      final int due = stat.monthDue;
      if (due > 0) {
        final int paid = stat.monthPaid;
        final int remain = due > paid ? due - paid : 0;
        int pct = (paid * 100 / due).round();
        if (pct > 100) pct = 100;
        if (pct < 0) pct = 0;
        await NativeBridge.showNotification(
          id: AppConstants.notifyIdLive,
          channelId: AppConstants.channelLive,
          title: '本期收款进度',
          body: '已收 ¥$paid · 应收 ¥$due'
              '${remain > 0 ? ' · 欠 ¥$remain' : ' · 已结清'}',
          live: true,
          progress: pct,
          progressMax: 100,
          criticalText: '$pct%',
        );
      } else {
        await NativeBridge.cancelNotification(AppConstants.notifyIdLive);
      }
      // 清理旧版本残留的焦点通知（1099）
      await NativeBridge.cancelNotification(AppConstants.notifyIdFocus);
    } else {
      await NativeBridge.cancelNotification(AppConstants.notifyIdLive);
    }
  }

  /// 推送单条系统通知
  Future<void> _push({
    required int id,
    required String channelId,
    required String title,
    required String body,
    String? bigText,
  }) {
    return NativeBridge.showNotification(
      id: id,
      channelId: channelId,
      title: title,
      body: body,
      bigText: bigText,
    );
  }

  //==================== 应用内更新下载通知 ====================

  /// 下载新版本中：常驻进度通知（通知栏与弹窗同步显示百分比）
  static Future<void> showUpdateProgress(String version, int percent) {
    return NativeBridge.showNotification(
      id: AppConstants.notifyIdUpdate,
      channelId: AppConstants.channelDownload,
      title: '正在下载 租房管家 v$version',
      body: '$percent%',
      progress: percent,
      progressMax: 100,
      ongoing: true,
    );
  }

  /// 下载完成：通知栏提示已就绪（点击拉起应用后即可安装）
  static Future<void> showUpdateDone(String version) {
    return NativeBridge.showNotification(
      id: AppConstants.notifyIdUpdate,
      channelId: AppConstants.channelDownload,
      title: '租房管家 v$version 已下载完成',
      body: '点击通知回到应用，点击「安装」完成升级',
      bigText: '新版本 v$version 已下载到本地。\n'
          '回到应用后在更新弹窗中点击「安装」即可完成升级。',
    );
  }

  /// 取消 / 清除更新下载通知
  static Future<void> cancelUpdateNotification() {
    return NativeBridge.cancelNotification(AppConstants.notifyIdUpdate);
  }

  /// 内置通知中心标记已读
  Future<void> markRead(NoticeItem item) async {
    await AppConfig.instance.markNoticeRead(item.id);
    _updateUnread(notices.value);
  }

  /// 全部标记已读
  Future<void> markAllRead() async {
    await AppConfig.instance
        .markAllNoticeRead(notices.value.map((NoticeItem e) => e.id).toList());
    _updateUnread(notices.value);
  }

  /// 更新未读计数
  void _updateUnread(List<NoticeItem> list) {
    int n = 0;
    for (final NoticeItem e in list) {
      if (!AppConfig.instance.isNoticeRead(e.id)) n++;
    }
    unreadCount.value = n;
  }

  /// 取某一类的提醒
  List<NoticeItem> _pick(List<NoticeItem> list, String type) =>
      list.where((NoticeItem e) => e.type == type).toList();
}
