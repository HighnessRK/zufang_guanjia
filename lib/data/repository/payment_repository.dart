import 'package:sqflite/sqflite.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_util.dart';
import '../db/database_helper.dart';
import '../models/payment.dart';
import '../models/room.dart';
import 'room_repository.dart';

/// 缴费流水表（payments）数据访问层。
///
/// 【周期收缴引擎】房租年付 / 水季付 / 电智能（夏季月付·其余季付）
///   每次 APP 启动 / 进入首页时调用 [ensureCurrentPeriod]，对每个房间：
///   1. 【一次性迁移】旧版月度数据：把 rooms 实况结转进上期 utility 流水、
///      读数滚动，从切换月起进入周期累计语义；
///   2. 【房租】距上次房租流水满 rentCycle 个月才产生应收：
///      应收 = 月租 × 经过月数（年付即月租 × 12），非收租月不建流水；
///   3. 【水/电】rooms.water_fee / elec_fee 是**周期累计**（抄表页读数
///      curr − prev 天然累计，结算前不清零）；全楼层按「统一收水/收电
///      日期」全局日历同期到期：到达收缴日后所有房间的累计额同时生成
///      应收流水（应收 = 累计额）；电费智能模式夏季月付、其余季付；
///   4. 结算动作（编辑页「收水费 / 收电费」）调用 [settleUtility]：
///      流水置已结清 + 房间累计清零 + 该表读数滚动（下一周期从头累计）。
class PaymentRepository {
  PaymentRepository._();

  static final PaymentRepository instance = PaymentRepository._();

  //========================= 账期维护 =========================

  /// 保证当前账期的应收状态正确（一次性迁移 + 周期判定，幂等）
  Future<void> ensureCurrentPeriod(List<Room> rooms) async {
    final String now = DateUtil.currentPeriod;
    final AppConfig cfg = AppConfig.instance;

    for (final Room room in rooms) {
      await _migrateLegacyMonth(room, now);
      await _ensureRentCycle(room, now, cfg);
      await _ensureUtilityCycle(
          room, now, AppConstants.payTypeWater, room.waterFee, cfg);
      await _ensureUtilityCycle(
          room, now, AppConstants.payTypeElec, room.elecFee, cfg);
    }
  }

  /// 【一次性迁移】旧版月度账期数据：把 rooms 里的月度实况写入上期
  /// utility 流水，并把读数滚动到下期（从切换月起进入周期累计语义）
  Future<void> _migrateLegacyMonth(Room room, String now) async {
    final List<Payment> history = await byRoom(room.roomNo);
    String? lastPeriod;
    for (final Payment p in history) {
      if (p.payType == AppConstants.payTypeUtility) {
        if (lastPeriod == null || p.period.compareTo(lastPeriod) > 0) {
          lastPeriod = p.period;
        }
      }
    }

    // 首次使用（还没有任何流水）或仍处于当前账期，无需结转
    if (lastPeriod == null || lastPeriod.compareTo(now) >= 0) return;

    // 守卫：已有水/电独立周期流水 = 新引擎已接管该房间，
    // 严禁再次按旧月度语义滚动读数 / 清零累计（会毁掉周期数据）
    for (final Payment p in history) {
      if (p.payType == AppConstants.payTypeWater ||
          p.payType == AppConstants.payTypeElec) {
        return;
      }
    }

    // 1) 把上一账期水电流水补齐为最终金额（应收 = 当时的水电费合计）
    await upsert(Payment(
      roomNo: room.roomNo,
      payType: AppConstants.payTypeUtility,
      period: lastPeriod,
      due: room.utilityFee,
      paid: room.utilityPaid ? room.utilityFee : 0,
      isSettled: room.utilityPaid,
      payTime: room.utilityPaid ? DateUtil.formatDateTime(DateTime.now()) : null,
    ));

    // 2) 把上一账期房租流水补齐为最终实收
    //    口径：在租或本期有实收 → 应收 = 租金；纯空置且本期无流水 →
    //    不生成房租记录（空置房不产生房租欠款，与待办提醒一致）
    final bool rentRelevant = room.isOccupied || room.paid > 0;
    final bool hasRentRecord = history.any((Payment p) =>
        p.payType == AppConstants.payTypeRent && p.period == lastPeriod);
    if (rentRelevant || hasRentRecord) {
      await upsert(Payment(
        roomNo: room.roomNo,
        payType: AppConstants.payTypeRent,
        period: lastPeriod,
        due: rentRelevant ? room.rent.round() : 0,
        paid: room.paid,
        isSettled: !rentRelevant || room.paid >= room.rent,
        payTime: rentRelevant && room.paid >= room.rent
            ? DateUtil.formatDateTime(DateTime.now())
            : null,
      ));
    }

    // 3) rooms 表滚动抄表 + 清零本期
    await RoomRepository.instance.rollMeterToNextPeriod(room.roomNo);
    await RoomRepository.instance.rollRentToNextPeriod(room.roomNo);

    // 4) 同步内存对象，保证下面创建本期流水时金额正确（新账期应收从 0 开始）
    room.elecPrev = room.elecCurr;
    room.waterPrev = room.waterCurr;
    room.elecFee = 0;
    room.waterFee = 0;
    room.utilityFee = 0;
    room.utilityPaid = false;
    room.paid = 0;
  }

  /// 【房租周期】满 rentCycle 个月收一次；
  /// 应收 = 月租 × 经过月数 + 历史欠款（拖欠月不丢账）。
  /// 非收租月不产生流水（周期内已预付，避免每月重复欠租）。
  /// 多期拖欠在新行「并账」：旧未结清行关闭、欠款并入新应收，
  /// 全房同时只挂一条未结清房租流水，欠款入口唯一。
  Future<void> _ensureRentCycle(Room room, String now, AppConfig cfg) async {
    final List<Payment> history = await byRoom(room.roomNo);
    Payment? last;
    for (final Payment p in history) {
      if (p.payType == AppConstants.payTypeRent &&
          (last == null || p.period.compareTo(last.period) > 0)) {
        last = p;
      }
    }

    // 空置且无实收：不产生房租应收；历史遗留的本期欠款流水自愈归零
    if (!room.isOccupied && room.paid == 0) {
      if (last != null &&
          last.period == now &&
          !last.isSettled &&
          last.due > 0) {
        await upsert(Payment(
          roomNo: room.roomNo,
          payType: AppConstants.payTypeRent,
          period: now,
          due: 0,
          paid: 0,
          isSettled: true,
          payTime: DateUtil.formatDateTime(DateTime.now()),
        ));
      }
      return;
    }

    final String? lastP = last?.period;
    final int elapsed =
        lastP == null ? -1 : DateUtil.monthsBetween(lastP, now);
    // 到期判定：无历史（首次签约按整周期收）或已满一个周期
    final bool dueNow = lastP == null || elapsed >= cfg.rentCycle;
    if (!dueNow) {
      // 周期内非收租时点：把「实付」字段 / 收款面板录入的本周期实收
      // （rooms.paid 绝对值）同步进最近一条未结清应收流水。此前这里直接
      // return，周期内改实付、收款都不生效，欠款状态永远不变。
      if (last != null && !last.isSettled && last.due > 0) {
        final int paid = room.paid;
        final bool settled = paid >= last.due;
        if (last.paid != paid || last.isSettled != settled) {
          await upsert(Payment(
            roomNo: room.roomNo,
            payType: AppConstants.payTypeRent,
            period: last.period,
            due: last.due,
            paid: paid,
            isSettled: settled,
            payTime: settled
                ? (last.payTime ?? DateUtil.formatDateTime(DateTime.now()))
                : null,
          ));
        }
        // 收满即清零实收：下一收租周期不把旧收款项当预收
        if (settled && room.paid != 0) {
          room.paid = 0;
          await RoomRepository.instance.clearRentPaid(room.roomNo);
        }
      }
      return; // 非收租月：本期不另建房租流水
    }

    // 应收月数：首次按整周期；此后按实际经过月数（上限 120 个月防呆）
    final int months =
        lastP == null ? cfg.rentCycle : (elapsed > 120 ? 120 : elapsed);

    // 历史欠款：所有未结清 rent 行的未收部分并入本期应收
    int arrears = 0;
    for (final Payment p in history) {
      if (p.payType == AppConstants.payTypeRent &&
          !p.isSettled &&
          p.due > 0) {
        arrears += p.due - p.paid;
      }
    }

    // 【v1.1.1 修复精度】月租现在是小数（年付 7600 ÷ 12 = 633.333…），
    // 若直接 `room.rent * months` 存进整型应收，年付会变成 633×12 = 7596
    // 凭空少 4 元。这里先乘后四舍五入，整周期应收恒等于录入金额。
    final int dueAmt = (room.rent * months).round() + arrears;
    // 实付 = 本周期人工录入的累计实收（跨期收大额时对应合并后的应收）
    final int paidNow = room.paid;
    final bool settled = dueAmt > 0 && paidNow >= dueAmt;

    final Payment? cur =
        await find(room.roomNo, AppConstants.payTypeRent, now);
    if (cur == null) {
      // 并账：关闭旧未结清行（欠款已并入新应收，实收清零避免重复计）
      for (final Payment p in history) {
        if (p.payType == AppConstants.payTypeRent &&
            !p.isSettled &&
            p.due > 0 &&
            p.period != now) {
          await upsert(Payment(
            roomNo: room.roomNo,
            payType: AppConstants.payTypeRent,
            period: p.period,
            due: p.due,
            paid: 0,
            isSettled: true,
            payTime: p.payTime ?? DateUtil.formatDateTime(DateTime.now()),
          ));
        }
      }
      await insert(Payment(
        roomNo: room.roomNo,
        payType: AppConstants.payTypeRent,
        period: now,
        due: dueAmt,
        paid: paidNow,
        isSettled: settled,
        payTime: settled ? DateUtil.formatDateTime(DateTime.now()) : null,
      ));
      // 结清即清零实收：避免下一收租周期把旧收款项当成新预收
      if (settled && room.paid != 0) {
        room.paid = 0;
        await RoomRepository.instance.clearRentPaid(room.roomNo);
      }
    } else if (!cur.isSettled) {
      // 本期行已存在：只同步实收（应收保持创建时口径，避免重复并账）
      final bool curSettled = cur.due > 0 && paidNow >= cur.due;
      if (cur.paid != paidNow || cur.isSettled != curSettled) {
        await upsert(Payment(
          roomNo: room.roomNo,
          payType: AppConstants.payTypeRent,
          period: now,
          due: cur.due,
          paid: paidNow,
          isSettled: curSettled,
          payTime: curSettled
              ? (cur.payTime ?? DateUtil.formatDateTime(DateTime.now()))
              : null,
        ));
      }
      if (curSettled && room.paid != 0) {
        room.paid = 0;
        await RoomRepository.instance.clearRentPaid(room.roomNo);
      }
    }
  }

  /// 【水/电统一收缴】全楼层按全局日历同期到期：自「收水/收电日期」
  /// 锚点起每间隔若干个月为一个统一收缴日；到达收缴日后，所有房间的
  /// 周期累计额同时生成应收流水（不再按各房间自己的结算时间各算各的）。
  /// 收缴日之前持续累计不建流水；同一收缴期只建一条（幂等）。
  Future<void> _ensureUtilityCycle(Room room, String now, String payType,
      int accumulatedFee, AppConfig cfg) async {
    if (accumulatedFee <= 0) return;

    // 锚点：水 / 电各自的统一收缴日期
    final String anchorText = payType == AppConstants.payTypeWater
        ? cfg.waterCollectDate
        : cfg.elecCollectDate;
    final DateTime? anchor = DateUtil.parse(anchorText);
    if (anchor == null) return;

    // 今天之前最近的一个统一收缴日（智能电费按该日所处季节逐段取间隔）
    final DateTime? point =
        _latestCollectPoint(anchor, DateTime.now(), payType, cfg);
    if (point == null) return; // 锚点在未来，尚未开始统一收缴
    final String pointPeriod = DateUtil.period(point);

    final List<Payment> history = await byRoom(room.roomNo);

    // 幂等：该收缴期已有应收流水 → 不重复建
    final Payment? cur = await find(room.roomNo, payType, pointPeriod);
    if (cur != null && cur.due > 0) return;

    // 收缴日之后才建档的房间：不追溯欠费，从下一个统一收缴日起计
    bool hasAny = false;
    for (final Payment p in history) {
      if (p.payType == payType) {
        hasAny = true;
        break;
      }
    }
    if (!hasAny && pointPeriod.compareTo(now) < 0) return;

    // 旧未结清行的实收并入新应收（累计额已含旧期月份），旧行并账关闭。
    // 注：升级前的 due=0「周期基准」行若恰在收缴期账期上，会被整行覆盖
    // 为应收流水（upsert = REPLACE），天然完成新旧口径衔接。
    int carry = 0;
    for (final Payment p in history) {
      if (p.payType == payType &&
          !p.isSettled &&
          p.due > 0 &&
          p.period != pointPeriod) {
        carry += p.paid;
      }
    }
    await _closeArrears(room.roomNo, payType, pointPeriod);
    final bool settledNew = carry >= accumulatedFee;
    await upsert(Payment(
      roomNo: room.roomNo,
      payType: payType,
      period: pointPeriod,
      due: accumulatedFee,
      paid: carry,
      isSettled: settledNew,
      payTime: settledNew ? DateUtil.formatDateTime(DateTime.now()) : null,
    ));
  }

  /// 全楼层统一收缴日历：自锚点起按间隔逐点推进，返回今天（含）之前
  /// 最近的一个收缴日；锚点在未来返回 null（尚未开始统一收缴）。
  /// 水按固定间隔 [AppConfig.waterCycle] 推进；电按 [AppConfig.elecIntervalAt]
  /// 逐段取间隔（智能模式夏季月付、其余季付，夏冬交替时自然切换）。
  static DateTime? _latestCollectPoint(DateTime anchor, DateTime today,
      String payType, AppConfig cfg) {
    if (anchor.isAfter(today)) return null;
    int intervalAt(DateTime d) => payType == AppConstants.payTypeWater
        ? cfg.waterCycle
        : cfg.elecIntervalAt(d);
    DateTime d = anchor;
    for (int i = 0; i < 500; i++) {
      final DateTime next = DateUtil.addMonths(d, intervalAt(d));
      if (next.isAfter(today)) break;
      d = next;
    }
    return d;
  }

  /// 并账关闭某房间某类型更早的未结清应收流水（[keepPeriod] 除外）。
  /// 仅水电类使用：累计额已含旧期月份，旧行必须关闭避免重复计欠；
  /// 实收已并入新行，此处清零防止月报跨期双计。
  Future<void> _closeArrears(
      String roomNo, String payType, String keepPeriod) async {
    final List<Payment> history = await byRoom(roomNo);
    for (final Payment p in history) {
      if (p.payType == payType &&
          !p.isSettled &&
          p.due > 0 &&
          p.period != keepPeriod) {
        await upsert(Payment(
          roomNo: roomNo,
          payType: payType,
          period: p.period,
          due: p.due,
          paid: 0,
          isSettled: true,
          payTime: p.payTime ?? DateUtil.formatDateTime(DateTime.now()),
        ));
      }
    }
  }

  /// 结算一笔水/电费：流水置已结清 + 房间累计清零 + 该表读数滚动。
  /// [payType] 为 [AppConstants.payTypeWater] 或 [AppConstants.payTypeElec]。
  Future<void> settleUtility(String roomNo, String payType, int amount) async {
    final String now = DateUtil.currentPeriod;

    // 结算挂在「最近一条未结清应收流水」的账期上；没有则记当期
    final List<Payment> history = await byRoom(roomNo);
    String period = now;
    for (final Payment p in history) {
      if (p.payType == payType && p.due > 0 && !p.isSettled) {
        period = p.period;
        break;
      }
    }

    await upsert(Payment(
      roomNo: roomNo,
      payType: payType,
      period: period,
      due: amount,
      paid: amount,
      isSettled: true,
      payTime: DateUtil.formatDateTime(DateTime.now()),
    ));

    // 旧版月度 utility 历史欠费并账关闭：口径已切换到水/电独立行，
    // 否则历史欠费没有任何收缴入口、会永久挂在待收里
    for (final Payment p in history) {
      if (p.payType == AppConstants.payTypeUtility &&
          !p.isSettled &&
          p.due > 0) {
        await upsert(Payment(
          roomNo: roomNo,
          payType: AppConstants.payTypeUtility,
          period: p.period,
          due: p.due,
          paid: p.paid,
          isSettled: true,
          payTime: p.payTime ?? DateUtil.formatDateTime(DateTime.now()),
        ));
      }
    }

    await RoomRepository.instance.settleUtility(roomNo, payType);
  }

  /// 查询某房间某类型最近一条「未结清且应收>0」的流水
  Future<Payment?> latestUnsettled(String roomNo, String payType) async {
    final List<Payment> history = await byRoom(roomNo);
    for (final Payment p in history) {
      if (p.payType == payType && p.due > 0 && !p.isSettled) return p;
    }
    return null;
  }

  /// 全房间未结清水电费聚合：roomNo → 待收金额（due − paid 合计）。
  /// 含旧版月度 utility 未结清行（迁移遗留的历史欠费）。
  /// 抄表页徽章 / 房间列表 / 统计页的「待收」口径。
  Future<Map<String, int>> unsettledUtilityByRoom() async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      where: 'pay_type IN (?, ?, ?) AND is_settled = 0 AND due > 0',
      whereArgs: const <Object?>[
        AppConstants.payTypeWater,
        AppConstants.payTypeElec,
        AppConstants.payTypeUtility,
      ],
    );
    final Map<String, int> out = <String, int>{};
    for (final Map<String, Object?> r in rows) {
      final String no = r['room_no'] as String;
      final int due = (r['due'] as int?) ?? 0;
      final int paid = (r['paid'] as int?) ?? 0;
      out[no] = (out[no] ?? 0) + (due - paid);
    }
    return out;
  }

  /// 全房间未结清房租欠款聚合：roomNo → 欠款合计（due − paid 累加）。
  /// 房间列表 / 统计页的「欠租」口径（周期内已预付则查不到）。
  Future<Map<String, int>> unsettledRentByRoom() async {
    final Database db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      where: 'pay_type = ? AND is_settled = 0 AND due > 0',
      whereArgs: const <Object?>[AppConstants.payTypeRent],
      orderBy: 'period DESC',
    );
    final Map<String, int> out = <String, int>{};
    for (final Map<String, Object?> r in rows) {
      final String no = r['room_no'] as String;
      final int due = (r['due'] as int?) ?? 0;
      final int paid = (r['paid'] as int?) ?? 0;
      out[no] = (out[no] ?? 0) + (due - paid);
    }
    return out;
  }

  /// 同步某房间的房租流水到当前周期口径（编辑页保存时调用）
  Future<void> syncRent(Room room) async {
    await _ensureRentCycle(room, DateUtil.currentPeriod, AppConfig.instance);
  }

  /// 收款面板「收房租」：[amount] 为本次收款额（增量）。
  /// 以最近一条未结清应收流水的实收为基准累加（房间字段与流水在历史数据
  /// 中可能不同步，以流水为准），写回 rooms.paid 后走同一账期引擎同步/结清。
  Future<void> collectRent(String roomNo, int amount) async {
    if (amount <= 0) return;
    final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
    if (room == null) return;

    // 基准：未结清房租流水的已收部分；无流水（周期内预收）则用 rooms.paid
    int base = room.paid;
    final Payment? unsettled = await latestUnsettled(
        roomNo, AppConstants.payTypeRent);
    if (unsettled != null) base = unsettled.paid;

    final int paid = base + amount;
    await RoomRepository.instance.setRentPaid(roomNo, paid);
    room.paid = paid;
    await syncRent(room);
  }

  //========================= 增删改查 =========================

  /// 新增一条流水
  Future<void> insert(Payment payment) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tablePayments,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 按「房间 + 类型 + 账期」覆盖写入（存在则更新，不存在则新增）
  Future<void> upsert(Payment payment) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      AppConstants.tablePayments,
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 查询全部流水（按账期倒序）
  Future<List<Payment>> all() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      orderBy: 'period DESC, pay_type ASC, room_no ASC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// 按房间号查询历史流水
  Future<List<Payment>> byRoom(String roomNo) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      where: 'room_no = ?',
      whereArgs: <Object?>[roomNo],
      orderBy: 'period DESC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// 按账期查询
  Future<List<Payment>> byPeriod(String period) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      where: 'period = ?',
      whereArgs: <Object?>[period],
      orderBy: 'room_no ASC',
    );
    return rows.map(Payment.fromMap).toList();
  }

  /// 查询某房间某账期某类型的流水
  Future<Payment?> find(String roomNo, String payType, String period) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.query(
      AppConstants.tablePayments,
      where: 'room_no = ? AND pay_type = ? AND period = ?',
      whereArgs: <Object?>[roomNo, payType, period],
      limit: 1,
    );
    return rows.isEmpty ? null : Payment.fromMap(rows.first);
  }

  /// 删除流水
  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      AppConstants.tablePayments,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  //========================= 缴费统计 =========================

  /// 账期汇总统计
  Future<StatSummary> statSummary({String? period}) async {
    final String p = period ?? DateUtil.currentPeriod;
    final List<Payment> list = await byPeriod(p);
    int due = 0, paid = 0, settled = 0, unsettled = 0;
    for (final Payment item in list) {
      due += item.due;
      paid += item.paid;
      if (item.isSettled) {
        settled++;
      } else {
        unsettled++;
      }
    }
    return StatSummary(
      period: p,
      due: due,
      paid: paid,
      debt: due - paid > 0 ? due - paid : 0,
      settledCount: settled,
      unsettledCount: unsettled,
    );
  }

  /// 最近 N 个月的收支报表（用于首页折线/柱状概览）
  Future<List<StatSummary>> monthlyReport(int months) async {
    final List<StatSummary> result = <StatSummary>[];
    final DateTime now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final DateTime d = DateTime(now.year, now.month - i, 1);
      result.add(await statSummary(period: DateUtil.period(d)));
    }
    return result;
  }

  /// 【v1.1.3 · 租金报表】按账期区间 + 费用类型聚合。
  ///
  /// [from]/[to] 为 `yyyy-MM` 账期（字典序即时间序），含首尾；一条
  /// `GROUP BY pay_type` 聚合 SQL，比逐期 [statSummary] 循环快得多。
  Future<List<FeeTypeSum>> sumByTypeRange(String from, String to) async {
    final String a = from.compareTo(to) <= 0 ? from : to;
    final String b = from.compareTo(to) <= 0 ? to : from;
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT pay_type, SUM(due) AS due, SUM(paid) AS paid, '
      'COUNT(*) AS n, COUNT(DISTINCT room_no) AS rooms '
      'FROM ${AppConstants.tablePayments} '
      'WHERE period >= ? AND period <= ? '
      'GROUP BY pay_type ORDER BY pay_type',
      <Object?>[a, b],
    );
    return rows.map((Map<String, Object?> r) {
      final Object? due = r['due'], paid = r['paid'];
      final Object? n = r['n'], rooms = r['rooms'];
      return FeeTypeSum(
        payType: r['pay_type'] as String,
        due: due is int ? due : 0,
        paid: paid is int ? paid : 0,
        count: n is int ? n : 0,
        rooms: rooms is int ? rooms : 0,
      );
    }).toList();
  }
}

/// 汇总统计结果
class StatSummary {
  const StatSummary({
    required this.period,
    required this.due,
    required this.paid,
    required this.debt,
    required this.settledCount,
    required this.unsettledCount,
  });

  /// 账期
  final String period;

  /// 应收合计（元）
  final int due;

  /// 实收合计（元）
  final int paid;

  /// 欠费合计（元）
  final int debt;

  /// 已结清笔数
  final int settledCount;

  /// 未结清笔数
  final int unsettledCount;

  /// 结清率（0~1）
  double get settleRate {
    final int total = settledCount + unsettledCount;
    return total == 0 ? 0 : settledCount / total;
  }
}

/// 【v1.1.3 · 租金报表】单个费用类型的账期区间汇总。
class FeeTypeSum {
  const FeeTypeSum({
    required this.payType,
    required this.due,
    required this.paid,
    required this.count,
    required this.rooms,
  });

  /// 费用类型：rent / water / elec / utility（旧版水电合并口径）
  final String payType;

  /// 应收合计（元）
  final int due;

  /// 实收合计（元）
  final int paid;

  /// 流水笔数
  final int count;

  /// 覆盖房间数
  final int rooms;

  /// 欠费合计（元）
  int get debt => due - paid > 0 ? due - paid : 0;

  /// 中文标签
  String get label => switch (payType) {
        'rent' => '房租',
        'water' => '水费',
        'elec' => '电费',
        'utility' => '水电费',
        _ => payType,
      };
}
