import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/date_util.dart';
import '../data/models/notice_item.dart';
import '../data/models/payment.dart';
import '../data/models/room.dart';
import '../data/repository/payment_repository.dart';
import '../data/repository/room_repository.dart';

/// 提醒引擎：根据房间 / 缴费数据 + info.gwt 配置，实时算出待办提醒。
///
/// 三类提醒：
///   1. rent   —— 本月房租未缴 / 即将欠费（提前 remind_days 天）
///   2. expire —— 租期即将到期（提前 expire_remind_days 天）
///   3. utility—— 水电费已产生但未收缴
class ReminderEngine {
  ReminderEngine._();

  /// 计算全部待提醒条目（内置通知中心直接使用）
  static Future<List<NoticeItem>> computeAll() async {
    final AppConfig cfg = AppConfig.instance;
    final List<Room> rooms = await RoomRepository.instance.all();
    final owed = await PaymentRepository.instance.latestUnsettledByRoom();
    final List<NoticeItem> list = <NoticeItem>[];

    final DateTime now = DateTime.now();
    final String period = DateUtil.currentPeriod;

    for (final Room room in rooms) {
      //================ 1. 租期到期提醒 ================
      final int? days = DateUtil.daysFromNow(room.expire);
      if (days != null) {
        if (days < 0) {
          list.add(NoticeItem(
            id: 'expire-${room.roomNo}-$period',
            type: 'expire',
            level: 'danger',
            roomNo: room.roomNo,
            title: '${room.roomNo} 租期已过期',
            body:
                '${room.tenant.isEmpty ? '暂无承租人' : room.tenant} 的租期已于 '
                '${room.expire} 到期（${DateUtil.humanDays(days)}），请及时续租或退租。',
          ));
        } else if (days <= cfg.expireRemindDays) {
          list.add(NoticeItem(
            id: 'expire-${room.roomNo}-$period',
            type: 'expire',
            level: days <= 3 ? 'danger' : 'warn',
            roomNo: room.roomNo,
            title: '${room.roomNo} 租期即将到期',
            body:
                '${room.tenant.isEmpty ? '暂无承租人' : room.tenant} 的租期 '
                '${room.expire} 到期，${DateUtil.humanDays(days)}。',
          ));
        }
      }

      //================ 2. 房租未缴提醒 ================
      // 周期口径：只有「收租月」才会生成应收流水；有未结清流水才提醒
      if (room.isOccupied && room.rent > 0) {
        final Payment? rentOwed = owed[room.roomNo]?[AppConstants.payTypeRent];
        if (rentOwed != null) {
          // 进入提醒窗口：每月账单日起 remindDays 天内提醒
          final int monthDay = now.day;
          if (monthDay >= 1 && monthDay <= cfg.remindDays) {
            list.add(NoticeItem(
              id: 'rent-${room.roomNo}-${rentOwed.period}',
              type: 'rent',
              level: monthDay >= cfg.remindDays ? 'danger' : 'warn',
              roomNo: room.roomNo,
              title: '${room.roomNo} 房租未缴',
              body:
                  '${room.tenant} 本期房租 ¥${rentOwed.due}，已收 ¥${rentOwed.paid}，'
                  '尚欠 ¥${rentOwed.due - rentOwed.paid}（账期 ${rentOwed.period}）。',
            ));
          }
        }
      }

      //================ 3. 水/电费未收提醒 ================
      // 周期口径：累计额未到期不提醒（还没到收的时候），
      // 满周期生成应收流水后提醒到收清为止（含旧版 utility 历史欠费）
      for (final String payType in <String>[
        AppConstants.payTypeWater,
        AppConstants.payTypeElec,
        AppConstants.payTypeUtility,
      ]) {
        final Payment? p = owed[room.roomNo]?[payType];
        if (p == null || p.due <= 0) continue;
        final String label = payType == AppConstants.payTypeWater
            ? '水费'
            : payType == AppConstants.payTypeElec
                ? '电费'
                : '水电费';
        list.add(NoticeItem(
          id: '$payType-${room.roomNo}-${p.period}',
          type: 'utility',
          level: 'warn',
          roomNo: room.roomNo,
          title: '${room.roomNo} $label未收缴',
          body:
              '$label ¥${p.due - p.paid} 待收'
              '${p.paid > 0 ? '（已收 ¥${p.paid}）' : ''}，账期 ${p.period}。',
        ));
      }
    }

    // 紧急的排前面
    list.sort((NoticeItem a, NoticeItem b) {
      if (a.level != b.level) return a.level == 'danger' ? -1 : 1;
      return a.roomNo.compareTo(b.roomNo);
    });
    return list;
  }

  /// 汇总统计（首页数据总览）
  static Future<HomeStat> computeHomeStat() async {
    final List<Room> rooms = await RoomRepository.instance.all();
    final int total = rooms.length;
    int occupied = 0, empty = 0;
    int expireSoon = 0;

    final int remindDays = AppConfig.instance.expireRemindDays;
    for (final Room room in rooms) {
      if (room.isOccupied) {
        occupied++;
      } else {
        empty++;
      }
      final int? days = DateUtil.daysFromNow(room.expire);
      if (days != null && days <= remindDays) expireSoon++;
    }

    // 应收/实收与缴费统计同口径：按当期 payments 流水聚合。
    // 房租只有收租月才有应收（年付周期内已预付不再重复计）；
    // 水电只有满周期结算时才有应收（未到期只累计、不计欠）。
    final List<Payment> cur =
        await PaymentRepository.instance.byPeriod(DateUtil.currentPeriod);
    int rentDue = 0, rentPaid = 0, utilityDue = 0, utilityUnpaid = 0;
    for (final Payment p in cur) {
      if (p.payType == AppConstants.payTypeRent) {
        rentDue += p.due;
        rentPaid += p.paid;
      } else if (p.payType == AppConstants.payTypeWater ||
          p.payType == AppConstants.payTypeElec ||
          p.payType == AppConstants.payTypeUtility) {
        utilityDue += p.due;
        if (!p.isSettled) utilityUnpaid += p.due - p.paid;
      }
    }

    final StatSummary stat = await PaymentRepository.instance.statSummary();

    return HomeStat(
      totalRooms: total,
      occupiedRooms: occupied,
      emptyRooms: empty,
      rentDue: rentDue,
      rentPaid: rentPaid,
      rentDebt: rentDue - rentPaid > 0 ? rentDue - rentPaid : 0,
      utilityDue: utilityDue,
      utilityUnpaid: utilityUnpaid,
      expireSoonRooms: expireSoon,
      period: stat.period,
      monthDue: stat.due,
      monthPaid: stat.paid,
      monthDebt: stat.debt,
    );
  }
}

/// 首页统计结果
class HomeStat {
  const HomeStat({
    required this.totalRooms,
    required this.occupiedRooms,
    required this.emptyRooms,
    required this.rentDue,
    required this.rentPaid,
    required this.rentDebt,
    required this.utilityDue,
    required this.utilityUnpaid,
    required this.expireSoonRooms,
    required this.period,
    required this.monthDue,
    required this.monthPaid,
    required this.monthDebt,
  });

  /// 房间总数
  final int totalRooms;

  /// 在租房间数
  final int occupiedRooms;

  /// 空置房间数
  final int emptyRooms;

  /// 本月房租应收
  final int rentDue;

  /// 本月房租实收
  final int rentPaid;

  /// 本月房租未收
  final int rentDebt;

  /// 本月水电费合计
  final int utilityDue;

  /// 本月水电费未收
  final int utilityUnpaid;

  /// 即将到期 / 已过期房间数
  final int expireSoonRooms;

  /// 当前账期
  final String period;

  /// 当期应收合计（含房租 + 水电）
  final int monthDue;

  /// 当期实收合计
  final int monthPaid;

  /// 当期欠费合计
  final int monthDebt;
}
