import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/person_repository.dart';
import '../../data/repository/room_repository.dart';
import '../widgets/app_widgets.dart';

/// 新增 / 编辑房间信息。
class RoomEditPage extends StatefulWidget {
  const RoomEditPage({super.key, this.roomNo});

  /// 传入表示「编辑」，为空表示「新增」
  final String? roomNo;

  @override
  State<RoomEditPage> createState() => _RoomEditPageState();
}

class _RoomEditPageState extends State<RoomEditPage> {
  late final TextEditingController _roomNo;
  late final TextEditingController _rent;
  late final TextEditingController _paid;
  late final TextEditingController _roomType;
  late final TextEditingController _tenant;
  late final TextEditingController _idCard;
  late final TextEditingController _checkIn;
  late final TextEditingController _expire;
  late final TextEditingController _deposit;
  late final TextEditingController _keyCount;
  late final TextEditingController _cardCount;
  late final TextEditingController _ac;
  late final TextEditingController _heater;
  late final TextEditingController _fridge;
  late final TextEditingController _washer;

  /// 是否为编辑模式
  bool get _isEdit => widget.roomNo != null;

  bool _saving = false;

  /// 周期累计水/电费（编辑模式，水收费结算区显示与结算用）
  int _waterFee = 0;
  int _elecFee = 0;

  @override
  void initState() {
    super.initState();
    // 统一初始化为空，随后按需填充
    _roomNo = TextEditingController(text: widget.roomNo ?? '');
    _rent = TextEditingController();
    _paid = TextEditingController();
    _roomType = TextEditingController();
    _tenant = TextEditingController();
    _idCard = TextEditingController();
    _checkIn = TextEditingController();
    _expire = TextEditingController();
    _deposit = TextEditingController();
    _keyCount = TextEditingController();
    _cardCount = TextEditingController();
    _ac = TextEditingController();
    _heater = TextEditingController();
    _fridge = TextEditingController();
    _washer = TextEditingController();
    _fill();
  }

  /// 编辑模式下把数据库里的值填进表单
  Future<void> _fill() async {
    if (!_isEdit) return;
    final Room? room = await RoomRepository.instance.byRoomNo(widget.roomNo!);
    if (room == null || !mounted) return;
    setState(() {
      _rent.text = '${room.rent}';
      _paid.text = '${room.paid}';
      _roomType.text = room.roomType;
      _tenant.text = room.tenant;
      _idCard.text = room.idCard;
      _checkIn.text = room.checkIn ?? '';
      _expire.text = room.expire ?? '';
      _deposit.text = '${room.deposit}';
      _keyCount.text = '${room.keyCount}';
      _cardCount.text = '${room.cardCount}';
      _ac.text = '${room.ac}';
      _heater.text = '${room.heater}';
      _fridge.text = '${room.fridge}';
      _washer.text = '${room.washer}';
      _waterFee = room.waterFee;
      _elecFee = room.elecFee;
    });
  }

  @override
  void dispose() {
    _roomNo.dispose();
    _rent.dispose();
    _paid.dispose();
    _roomType.dispose();
    _tenant.dispose();
    _idCard.dispose();
    _checkIn.dispose();
    _expire.dispose();
    _deposit.dispose();
    _keyCount.dispose();
    _cardCount.dispose();
    _ac.dispose();
    _heater.dispose();
    _fridge.dispose();
    _washer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final AppConfig cfg = AppConfig.instance;
    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: _isEdit ? '编辑房间' : '新增房间',
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        return ListView(
          padding: EdgeInsets.fromLTRB(
              20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
          children: <Widget>[
            const SectionTitle('基础信息', padding: EdgeInsets.zero),
            AppTextField(
              label: '房间号（如 101）',
              controller: _roomNo,
              keyboardType: TextInputType.text,
            ),
            AppTextField(
              label: '房型（如 一室一厅）',
              controller: _roomType,
            ),
            AppTextField(
              label: '租金（元/月）',
              controller: _rent,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '实付（本周期已收房租，元）',
              controller: _paid,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '押金（元）',
              controller: _deposit,
              keyboardType: TextInputType.number,
            ),
            const SectionTitle('主租户信息'),
            AppTextField(label: '主租户姓名', controller: _tenant),
            AppTextField(
              label: '身份证号',
              controller: _idCard,
              keyboardType: TextInputType.text,
            ),
            _DateField(
              label: '入住日期（yyyy-MM-dd）',
              controller: _checkIn,
            ),
            _DateField(
              label: '到期日期（yyyy-MM-dd）',
              controller: _expire,
            ),
            const SectionTitle('配套与资产'),
            AppTextField(
              label: '钥匙数量（把）',
              controller: _keyCount,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '小豆豆 · 一楼大门磁卡（张）',
              controller: _cardCount,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '空调（台）',
              controller: _ac,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '热水器（台）',
              controller: _heater,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '冰箱（台）',
              controller: _fridge,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              label: '洗衣机（台）',
              controller: _washer,
              keyboardType: TextInputType.number,
            ),
            if (_isEdit) ...<Widget>[
              const SectionTitle('水收费结算'),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _feeLine(
                        '水费 · ${AppConfig.cycleLabel(cfg.waterCycle)}结算',
                        _waterFee),
                    const SizedBox(height: 6),
                    _feeLine('电费 · ${cfg.elecCycleLabel}', _elecFee),
                    const SizedBox(height: 10),
                    MiuixText(
                      '抄表读数按周期累计，到期一次结清；结算后累计清零、'
                      '该表读数滚动进入下一周期。',
                      fontSize: 11,
                      color: c.onSurfaceVariantSummary,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: GradientButton(
                            label: '收水费',
                            enabled: _waterFee > 0 && !_saving,
                            onPressed: () =>
                                _settle(AppConstants.payTypeWater),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GradientButton(
                            label: '收电费',
                            enabled: _elecFee > 0 && !_saving,
                            onPressed: () =>
                                _settle(AppConstants.payTypeElec),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: MiuixTextButton('取消',
                      onPressed: () => Navigator.of(context).pop()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: _saving ? '保存中…' : '保存',
                    enabled: !_saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// 水收费结算区的一行：费用类型 + 周期说明 | 周期累计金额
  Widget _feeLine(String label, int fee) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Row(
      children: <Widget>[
        Expanded(
          child: MiuixText(label,
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        MiuixText(
          '累计 ¥$fee',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: fee > 0 ? c.primary : c.onSurfaceVariantSummary,
        ),
      ],
    );
  }

  /// 结算一笔水/电费：确认弹窗 → 流水置已结清 + 房间累计清零 + 读数滚动
  Future<void> _settle(String payType) async {
    final bool isWater = payType == AppConstants.payTypeWater;
    final int fee = isWater ? _waterFee : _elecFee;
    if (fee <= 0) {
      AppSnackbar.show(isWater ? '水费暂无累计金额' : '电费暂无累计金额');
      return;
    }
    final AppConfig cfg = AppConfig.instance;
    final String label = isWater ? '水费' : '电费';
    final String cycle =
        isWater ? AppConfig.cycleLabel(cfg.waterCycle) : cfg.elecCycleLabel;

    final bool? ok = await showAppDialog(
      context,
      title: '收$label',
      summary: '累计$label ¥$fee（$cycle）。\n'
          '确认收缴后累计清零、该表读数滚动进入下一周期。',
      confirmText: '已收 ¥$fee',
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    await PaymentRepository.instance
        .settleUtility(widget.roomNo!, payType, fee);
    await _fill();
    if (!mounted) return;
    setState(() => _saving = false);
    AppSnackbar.show('已收 $label ¥$fee');
  }

  /// 保存房间信息
  Future<void> _save() async {
    final String roomNo = _roomNo.text.trim();
    if (roomNo.isEmpty) {
      AppSnackbar.show('请填写房间号');
      return;
    }

    setState(() => _saving = true);

    final Room room = Room(
      roomNo: roomNo,
      rent: int.tryParse(_rent.text.trim()) ?? 0,
      paid: int.tryParse(_paid.text.trim()) ?? 0,
      roomType: _roomType.text.trim(),
      tenant: _tenant.text.trim(),
      idCard: _idCard.text.trim(),
      checkIn: _checkIn.text.trim().isEmpty ? null : _checkIn.text.trim(),
      expire: _expire.text.trim().isEmpty ? null : _expire.text.trim(),
      deposit: int.tryParse(_deposit.text.trim()) ?? 0,
      keyCount: int.tryParse(_keyCount.text.trim()) ?? 0,
      cardCount: int.tryParse(_cardCount.text.trim()) ?? 0,
      ac: int.tryParse(_ac.text.trim()) ?? 0,
      heater: int.tryParse(_heater.text.trim()) ?? 0,
      fridge: int.tryParse(_fridge.text.trim()) ?? 0,
      washer: int.tryParse(_washer.text.trim()) ?? 0,
    );

    try {
      if (_isEdit) {
        // 编辑模式：保留原有的抄表与水电数据
        final Room? old =
            await RoomRepository.instance.byRoomNo(widget.roomNo!);
        if (old != null) {
          room.elecPrev = old.elecPrev;
          room.elecCurr = old.elecCurr;
          room.waterPrev = old.waterPrev;
          room.waterCurr = old.waterCurr;
          room.elecFee = old.elecFee;
          room.waterFee = old.waterFee;
          room.utilityFee = old.utilityFee;
          room.utilityPaid = old.utilityPaid;
        }
        await RoomRepository.instance.update(room);
      } else {
        await RoomRepository.instance.insert(room);
      }

      // 同步房租流水到缴费周期口径（周期到期：应收 = 月租 × 经过月数，
      // 年付即月租 × 12；未到期：仅记录本周期实收，不产生每月欠租）
      await PaymentRepository.instance.syncRent(room);

      // 主租户姓名 / 身份证与 people 表联动（有则同步 / 无则补一条主租户，
      // 身份证跟随租户本人存储）
      await PersonRepository.instance
          .syncFromRoom(roomNo, room.tenant, room.idCard);
    } catch (e) {
      if (mounted) AppSnackbar.show('保存失败：房间号可能已存在');
      setState(() => _saving = false);
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    AppSnackbar.show('房间 $roomNo 已保存');
    Navigator.of(context).pop();
  }
}

/// 日期输入框：可手填 yyyy-MM-dd，也可点右侧图标弹出系统日期选择器
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: TextInputType.datetime,
      trailingIcon: MiuixIconButton(
        onPressed: () => _pick(context),
        child: const MiuixIcon(icon: Icons.calendar_month_rounded, size: 20),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime initial = DateUtil.parse(controller.text) ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateUtil.format(picked);
    }
  }
}
