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
  static Future<Receipt> generate(String roomNo, String period) async {
    final Receipt? receipt = await build(roomNo, period);
    if (receipt == null) {
      throw StateError('该房间该账期暂无水电费用');
    }
    await ReceiptRepository.instance.upsert(receipt);
    return receipt;
  }

  /// 构造收据快照（不落库）；无任何水电费用返回 null
  static Future<Receipt?> build(String roomNo, String period) async {
    final PaymentRepository payments = PaymentRepository.instance;

    // 金额：优先 water / elec 分开口径；两者皆无再看旧版合并口径 utility
    final Payment? w =
        await payments.find(roomNo, AppConstants.payTypeWater, period);
    final Payment? e =
        await payments.find(roomNo, AppConstants.payTypeElec, period);
    int waterFee = w?.due ?? 0;
    int elecFee = e?.due ?? 0;
    if (waterFee <= 0 && elecFee <= 0) {
      final Payment? u =
          await payments.find(roomNo, AppConstants.payTypeUtility, period);
      if (u != null && u.due > 0) {
        // 旧版「水电费」合并口径：整笔放合计，明细行由收据卡按合并样式展示
        waterFee = 0;
        elecFee = 0;
        final int total = u.due;
        return _make(
          roomNo: roomNo,
          period: period,
          waterFee: waterFee,
          elecFee: elecFee,
          total: total,
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
      if (period == DateUtil.currentPeriod) {
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
  }) {
    // 编号：SJ-账期-房号（同房同期唯一，重生成即覆盖同号）
    final String no = 'SJ-${period.replaceAll('-', '')}-$roomNo';
    return Receipt(
      roomNo: roomNo,
      period: period,
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
      if (p.payType == AppConstants.payTypeRent) continue;
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
