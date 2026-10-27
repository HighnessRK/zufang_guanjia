import '../core/constants/app_constants.dart';
import '../core/config/app_config.dart';
import '../core/utils/date_util.dart';
import '../data/models/payment.dart';
import '../data/models/receipt.dart';
import '../data/models/room.dart';
import '../data/repository/payment_repository.dart';
import '../data/repository/receipt_repository.dart';
import '../data/repository/room_repository.dart';

/// 电子收据生成（v1.1.3）。
///
/// 口径：金额取该房间该账期的 **payments 应收流水**（water / elec；
/// 旧版合并口径 utility 整笔并入合计）；**当前账期**额外带上水 / 电
/// 用量与单价快照（来自 rooms 读数 + 计费参数），历史账期只有金额。
class ReceiptService {
  ReceiptService._();

  /// 生成并落库（同房同期覆盖旧收据），返回收据快照。
  ///
  /// 该房间该账期没有任何水电费用时抛出 [StateError]，由调用方提示。
  static Future<Receipt> generate(String roomNo, String period,
      {String kind = 'utility', String? start, String? end}) async {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(period) ||
        !['utility', 'rent', 'water', 'elec'].contains(kind)) {
      throw StateError('收据账期或类型无效');
    }
    if (start != null && end != null &&
        (DateTime.tryParse(start) == null || DateTime.tryParse(end) == null ||
         DateTime.parse(end).isBefore(DateTime.parse(start)))) {
      throw StateError('账期结束日期不能早于开始日期');
    }
    final Receipt? receipt = await build(roomNo, period,
        kind: kind, start: start, end: end);
    if (receipt == null) {
      throw StateError('该房间该账期暂无已收款，收据只能按实收金额开具');
    }
    return ReceiptRepository.instance.issue(receipt);
  }

  /// 构造收据快照（不落库）；无任何水电费用返回 null
  static Future<Receipt?> build(String roomNo, String period,
      {String kind = 'utility', int sequence = 1, String? start, String? end}) async {
    final PaymentRepository payments = PaymentRepository.instance;
    if (kind == 'rent') {
      final Payment? rent = await payments.find(roomNo, AppConstants.payTypeRent, period);
      if (rent == null || rent.paid <= 0) return null;
      final room = await RoomRepository.instance.byRoomNo(roomNo);
      return _make(roomNo: roomNo, period: period, waterFee: 0, elecFee: 0,
          total: rent.paid, kind: kind, sequence: sequence, start: start, end: end,
          tenant: room?.tenant ?? '');
    }

    // 金额：优先 water / elec 分开口径；两者皆无再看旧版合并口径 utility
    final Payment? w =
        await payments.find(roomNo, AppConstants.payTypeWater, period);
    final Payment? e =
        await payments.find(roomNo, AppConstants.payTypeElec, period);
    int waterFee = kind == 'elec' ? 0 : w?.paid ?? 0;
    int elecFee = kind == 'water' ? 0 : e?.paid ?? 0;
    if (kind == 'utility' && waterFee <= 0 && elecFee <= 0) {
      final Payment? u =
          await payments.find(roomNo, AppConstants.payTypeUtility, period);
      if (u != null && u.paid > 0) {
        // 旧版「水电费」合并口径：整笔放合计，明细行由收据卡按合并样式展示
        waterFee = 0;
        elecFee = 0;
        final int total = u.paid;
        return _make(
          roomNo: roomNo,
          period: period,
          waterFee: waterFee,
          elecFee: elecFee,
          total: total,
          kind: kind, sequence: sequence, start: start, end: end,
        );
      }
    }

    final int total = waterFee + elecFee;
    if (total <= 0) {
      return null;
    }

    // 当前账期才有读数快照；历史账期 rooms 里已是新一期读数，不可借用。
    // 租户名两种情况都取房间当前主租户。
    int? waterUse, elecUse;
    double? waterPrice, elecPrice;
    int? waterPrev, waterCurr, elecPrev, elecCurr;
    String tenant = '';
    final Room? hit = await RoomRepository.instance.byRoomNo(roomNo);
    if (hit != null) {
      tenant = hit.tenant;
      // 收款后读数可能已滚动；只有当前累计额仍与实收一致时才能
      // 使用 rooms 读数，不能给历史实收套上下一期读数。
      if (period == DateUtil.currentPeriod &&
          hit.waterFee == waterFee && hit.elecFee == elecFee) {
        waterPrev = hit.waterPrev;
        waterCurr = hit.waterCurr;
        elecPrev = hit.elecPrev;
        elecCurr = hit.elecCurr;
        waterUse = waterCurr - waterPrev;
        elecUse = elecCurr - elecPrev;
        if (waterUse < 0) waterUse = 0;
        if (elecUse < 0) elecUse = 0;
        waterPrice = AppConfig.instance.waterPrice;
        elecPrice = AppConfig.instance.elecPrice;
      }
    }

    return _make(
      roomNo: roomNo,
      period: period,
      waterFee: waterFee,
      elecFee: elecFee,
      total: total,
      waterUse: waterUse,
      elecUse: elecUse,
      waterPrice: waterPrice,
      elecPrice: elecPrice,
      waterPrev: waterPrev,
      waterCurr: waterCurr,
      elecPrev: elecPrev,
      elecCurr: elecCurr,
      tenant: tenant,
      kind: kind, sequence: sequence, start: start, end: end,
    );
  }

  static Receipt _make({
    required String roomNo,
    required String period,
    required int waterFee,
    required int elecFee,
    required int total,
    int? waterUse,
    int? elecUse,
    double? waterPrice,
    double? elecPrice,
    int? waterPrev,
    int? waterCurr,
    int? elecPrev,
    int? elecCurr,
    String tenant = '',
    String kind = 'utility',
    int sequence = 1,
    String? start,
    String? end,
  }) {
    // 编号：SJ-账期-房号（同房同期唯一，重生成即覆盖同号）
    final String no = 'SJ-${period.replaceAll('-', '')}-$roomNo-${kind == 'rent' ? 'R' : 'U'}-${sequence.toString().padLeft(3, '0')}';
    final parts = period.split('-');
    final year = int.parse(parts[0]), month = int.parse(parts[1]);
    final String first = '$period-01';
    final String last = DateUtil.format(DateTime(year, month + 1, 0));
    return Receipt(
      roomNo: roomNo,
      period: period,
      kind: kind, sequence: sequence,
      periodStart: start ?? first, periodEnd: end ?? last,
      watermark: AppConfig.instance.receiptWatermark,
      no: no,
      tenant: tenant,
      waterFee: waterFee,
      elecFee: elecFee,
      total: total,
      waterUse: waterUse,
      elecUse: elecUse,
      waterPrice: waterPrice,
      elecPrice: elecPrice,
      waterPrev: waterPrev,
      waterCurr: waterCurr,
      elecPrev: elecPrev,
      elecCurr: elecCurr,
      createdAt: DateUtil.formatDateTime(DateTime.now()),
    );
  }

  /// 某房间可开收据的账期列表（倒序，含当前账期）
  static Future<List<String>> periodsOf(String roomNo) async {
    final List<Payment> list =
        await PaymentRepository.instance.byRoom(roomNo);
    final Set<String> seen = <String>{};
    final List<String> periods = <String>[];
    for (final Payment p in list) {
      // 只收水电相关流水的账期
      if (seen.add(p.period)) {
        periods.add(p.period);
      }
    }
    final String cur = DateUtil.currentPeriod;
    if (seen.add(cur)) {
      periods.add(cur);
    }
    periods.sort((String a, String b) => b.compareTo(a));
    return periods;
  }
}
