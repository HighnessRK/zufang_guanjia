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

/// 编辑房间表单的标签列宽：按最长标签「实付（本周期）」对齐，
/// 保证所有字段的输入框左边缘在同一竖线上（设置页风格整齐排布）。
const double _kFieldLabelWidth = 112;

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

  /// 房租缴费周期（与「设置 · 计费参数」同口径：1/3/6/12 个月）
  int get _cycle => AppConfig.instance.rentCycle <= 0 ? 1 : AppConfig.instance.rentCycle;

  /// 租金输入框单位后缀：元/月、元/季、元/半年、元/年
  String get _cycleUnit => '元/${AppConfig.cycleUnit(_cycle)}';

  /// 当前输入按周期折算出的月租（内部记账口径：应收 = 月租 × 周期月数）
  int get _monthlyRent =>
      (int.tryParse(_rent.text.trim()) ?? 0) ~/ _cycle;

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
    // 边输入边刷新「月租」换算小字（租金按设置周期口径展示）
    _rent.addListener(_onRentChanged);
    _fill();
  }

  void _onRentChanged() {
    if (mounted) setState(() {});
  }

  /// 编辑模式下把数据库里的值填进表单
  Future<void> _fill() async {
    if (!_isEdit) return;
    final Room? room = await RoomRepository.instance.byRoomNo(widget.roomNo!);
    if (room == null || !mounted) return;
    setState(() {
      // 租金按设置的周期口径展示（年付显示年金额），内部仍存月租
      _rent.text = '${room.rent * _cycle}';
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
    _rent.removeListener(_onRentChanged);
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
            AppLabelField(
              label: '房间号',
              hint: '如 101',
              controller: _roomNo,
              keyboardType: TextInputType.text,
              labelWidth: _kFieldLabelWidth,
            ),
            _RoomTypeField(
              controller: _roomType,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '租金（$_cycleUnit）',
              hint: '按设置周期计',
              controller: _rent,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
              caption: '月租 ¥$_monthlyRent · 按「${AppConfig.cycleLabel(_cycle)}」口径填写'
                  '（年付即填一年总额，内部按月租入账）',
            ),
            AppLabelField(
              label: '实付（本周期）',
              hint: '元',
              controller: _paid,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '押金（元）',
              hint: '退租时退还',
              controller: _deposit,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            const SectionTitle('主租户信息'),
            AppLabelField(
              label: '主租户姓名',
              hint: '承租人',
              controller: _tenant,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '身份证号',
              hint: '选填',
              controller: _idCard,
              keyboardType: TextInputType.text,
              labelWidth: _kFieldLabelWidth,
            ),
            _DateField(
              label: '入住日期',
              hint: '点右侧图标选择',
              controller: _checkIn,
            ),
            _DateField(
              label: '到期日期',
              hint: '点右侧图标选择',
              controller: _expire,
            ),
            const SectionTitle('配套与资产'),
            AppLabelField(
              label: '钥匙数量（把）',
              hint: '0 = 无',
              controller: _keyCount,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '大门磁卡（张）',
              hint: '小豆豆 · 一楼',
              controller: _cardCount,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '空调（台）',
              hint: '0 = 无',
              controller: _ac,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '热水器（台）',
              hint: '0 = 无',
              controller: _heater,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '冰箱（台）',
              hint: '0 = 无',
              controller: _fridge,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
            ),
            AppLabelField(
              label: '洗衣机（台）',
              hint: '0 = 无',
              controller: _washer,
              keyboardType: TextInputType.number,
              labelWidth: _kFieldLabelWidth,
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

    // 租金：按设置周期口径填写（年付填年总额）→ 换算成月租入表，
    // 保证「应收 = 月租 × 周期月数」的账期引擎口径不变
    final int cycleAmount = int.tryParse(_rent.text.trim()) ?? 0;
    final int monthlyRent = _monthlyRent;

    final Room room = Room(
      roomNo: roomNo,
      rent: monthlyRent,
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
    // 周期金额不是月数整数倍时会向下取整入账，明确告知避免「少了几块」的疑惑
    final bool rounded = _cycle > 1 && cycleAmount % _cycle != 0;
    AppSnackbar.show(rounded
        ? '房间 $roomNo 已保存（按月租 ¥$monthlyRent 入账）'
        : '房间 $roomNo 已保存');
    Navigator.of(context).pop();
  }
}

/// 日期字段：标签在左 + 可手填，点右侧日历图标弹出液态玻璃日期选择器。
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return AppLabelField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: TextInputType.datetime,
      labelWidth: _kFieldLabelWidth,
      trailingIcon: MiuixIconButton(
        onPressed: () => _pick(context),
        child: MiuixIcon(
          icon: Icons.calendar_month_rounded,
          size: 20,
          tint: c.onSurfaceVariantSummary,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime initial = DateUtil.parse(controller.text) ?? DateTime.now();
    final DateTime? picked = await showDatePickDialog(
      context,
      title: '选择日期',
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      controller.text = DateUtil.format(picked);
    }
  }
}

/// 房型下拉框：固定预设（店面 / 单间 / 一室一厅 / 两室一厅）+「其他」可手输。
/// 与其它字段同行左标签布局，右侧数值 + 下拉箭头，点按弹出选项。
///
/// 需要 StatefulWidget：选值后 controller.text 变化，占位提示「点击选择」
/// 要随之让位（否则值与占位叠印）。用 controller 监听重建。
class _RoomTypeField extends StatefulWidget {
  const _RoomTypeField({
    required this.controller,
    required this.labelWidth,
  });

  final TextEditingController controller;
  final double labelWidth;

  /// 预设房型（顺序即展示顺序）
  static const List<String> kPresets = <String>[
    '店面',
    '单间',
    '一室一厅',
    '两室一厅',
    '其他',
  ];

  @override
  State<_RoomTypeField> createState() => _RoomTypeFieldState();
}

class _RoomTypeFieldState extends State<_RoomTypeField> {
  TextEditingController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_sync);
  }

  @override
  void dispose() {
    controller.removeListener(_sync);
    super.dispose();
  }

  /// 值变化 → 重建，占位提示与当前值互斥显示
  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    // 标签在框外左侧（与 AppLabelField 同布局），框内仅值 + 下拉箭头
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: widget.labelWidth,
              child: MiuixText(
                '房型',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.onSurfaceContainer,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                MiuixTextField(
                  // 空值时以占位提示「点击选择」，有值后自动让位
                  label: controller.text.isEmpty ? '点击选择' : '',
                  useLabelAsPlaceholder: true,
                  controller: controller,
                  readOnly: true,
                  singleLine: true,
                  trailingIcon: MiuixIcon(
                    icon: Icons.arrow_drop_down_rounded,
                    size: 28,
                    tint: c.onSurfaceVariantSummary,
                  ),
                ),
                // 整框可点：弹出预设选项
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _pick(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final String current = controller.text.trim();
    const List<String> presets = _RoomTypeField.kPresets;
    // 当前值不在预设里（历史手输值）时，临时补一项以显示勾选
    final List<MapEntry<String, String>> options = <MapEntry<String, String>>[
      for (final String p in presets) MapEntry<String, String>(p, p),
      if (current.isNotEmpty && !presets.contains(current))
        MapEntry<String, String>(current, '$current（自定义）'),
    ];
    final String? v = await showOptionPicker<String>(
      context,
      title: '选择房型',
      current: current,
      options: options,
    );
    if (v == null || !context.mounted) return;
    if (v == '其他') {
      // 其他 → 弹窗手输
      final TextEditingController ctrl =
          TextEditingController(text: current == '其他' ? '' : current);
      final bool? ok = await showAppDialog(
        context,
        title: '自定义房型',
        summary: '填写任意房型名称，如「阁楼」「loft」「商铺」',
        content: AppTextField(label: '房型名称', controller: ctrl),
      );
      if (ok == true && ctrl.text.trim().isNotEmpty) {
        controller.text = ctrl.text.trim();
      }
      ctrl.dispose();
    } else {
      controller.text = v;
    }
  }
}
