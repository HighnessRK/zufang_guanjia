import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/person.dart';
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
  const RoomEditPage({super.key, this.roomNo, this.copyFrom});

  /// 传入表示「编辑」，为空表示「新增」
  final String? roomNo;

  /// 【v1.1.1】传入表示「复制为新房」：沿用该房间的楼层 / 房型 / 租金 /
  /// 押金 / 配套家电等配置，新房号留空待填，租户、抄表、实付不带过来。
  final Room? copyFrom;

  @override
  State<RoomEditPage> createState() => _RoomEditPageState();
}

class _RoomEditPageState extends State<RoomEditPage> {
  late final TextEditingController _roomNo;
  late final TextEditingController _rent;
  late final TextEditingController _paid;
  late final TextEditingController _roomType;
  late final TextEditingController _tenant;
  late final TextEditingController _phone;
  late final TextEditingController _idCard;
  late final TextEditingController _checkIn;
  late final TextEditingController _expire;
  late final TextEditingController _floor;
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

  /// 当前输入按周期折算出的月租（内部记账口径：应收 = 月租 × 周期月数）。
  ///
  /// 【v1.1.1 修复】改为**小数**：年付填 7600 时 7600 ÷ 12 = 633.333…，
  /// 此前用 `~/` 取整成 633，账期引擎按 633 × 12 = 7596 出应收，凭空少
  /// 4 元。保留小数后应收在 [PaymentRepository] 处四舍五入回 7600。
  double get _monthlyRent =>
      (double.tryParse(_rent.text.trim()) ?? 0) / _cycle;

  /// 楼层下拉可选项：1 ~ 20 层（超出可用「自定义」手输，如「一楼」「店面」）
  static const int _maxFloorOption = 20;

  /// 电话号码是否合规（11 位、1 开头）——实时提示用
  static bool _phoneOk(String v) => RegExp(r'^1\d{10}$').hasMatch(v);

  /// 身份证是否合规（18 位 + ISO 7064:1983 MOD 11-2 校验位）——实时提示用
  static bool _idCardOk(String v) {
    final String t = v.trim();
    if (!RegExp(r'^\d{17}[\dXx]$').hasMatch(t)) return false;
    const String w = '7 9 10 5 8 4 2 1 6 3 7 9 10 5 8 4 2';
    const List<int> check = <int>[1, 0, 9, 8, 7, 6, 5, 4, 3, 2];
    final List<int> weights = w.split(' ').map(int.parse).toList();
    int sum = 0;
    for (int i = 0; i < 17; i++) {
      sum += (t.codeUnitAt(i) - 48) * weights[i];
    }
    final String last = t[17].toUpperCase();
    return last == (check[sum % 11] == 10 ? 'X' : '${check[sum % 11]}');
  }

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
    _phone = TextEditingController();
    _idCard = TextEditingController();
    _checkIn = TextEditingController();
    _expire = TextEditingController();
    _floor = TextEditingController();
    _deposit = TextEditingController();
    _keyCount = TextEditingController();
    _cardCount = TextEditingController();
    _ac = TextEditingController();
    _heater = TextEditingController();
    _fridge = TextEditingController();
    _washer = TextEditingController();
    // 边输入边刷新「月租」换算小字（租金按设置周期口径展示）
    _rent.addListener(_onRentChanged);
    // 边输入边刷新电话 / 身份证的实时校验小字与入住日期联动的到期日
    _phone.addListener(_onRentChanged);
    _idCard.addListener(_onRentChanged);
    _checkIn.addListener(_onCheckInChanged);
    _fill();
  }

  void _onRentChanged() {
    if (mounted) setState(() {});
  }

  /// 【v1.1.1】入住日期一改，到期日期自动顺延一年（可在设置里关闭）。
  void _onCheckInChanged() {
    if (!mounted) return;
    final DateTime? d = DateTime.tryParse(_checkIn.text.trim());
    if (d == null) return;
    if (!AppConfig.instance.autoExpire) return;
    setState(() {
      _expire.text = DateUtil.format(DateTime(d.year + 1, d.month, d.day));
    });
  }

  /// 编辑模式下把数据库里的值填进表单；「复制为新房」则只带配置项。
  Future<void> _fill() async {
    final bool isCopy = !_isEdit && widget.copyFrom != null;
    // 「复制」分支不查库、走同步路径，可能在 initState 还没跑完就 setState，
    // 撞上构建期会抛 "setState() called during build"。先让出一帧避开。
    if (isCopy) await Future<void>.delayed(Duration.zero);
    final Room? room = _isEdit
        ? await RoomRepository.instance.byRoomNo(widget.roomNo!)
        : widget.copyFrom;
    if (room == null || !mounted) return;
    setState(() {
      // 租金按设置的周期口径展示（年付显示年金额），内部仍存月租
      _rent.text = (room.rent * _cycle).round().toString();
      // 复制只带「配置」：楼层 / 房型 / 租金 / 押金 / 钥匙磁卡 / 配套家电；
      // 实付、租户、身份证、起止日期、抄表与水电费一律不带（新房是空的）
      _paid.text = isCopy ? '' : '${room.paid}';
      _roomType.text = room.roomType;
      _tenant.text = isCopy ? '' : room.tenant;
      _floor.text = room.floor;
      _idCard.text = isCopy ? '' : room.idCard;
      _checkIn.text = isCopy ? '' : (room.checkIn ?? '');
      _expire.text = isCopy ? '' : (room.expire ?? '');
      _deposit.text = '${room.deposit}';
      _keyCount.text = '${room.keyCount}';
      _cardCount.text = '${room.cardCount}';
      _ac.text = '${room.ac}';
      _heater.text = '${room.heater}';
      _fridge.text = '${room.fridge}';
      _washer.text = '${room.washer}';
      _waterFee = isCopy ? 0 : room.waterFee;
      _elecFee = isCopy ? 0 : room.elecFee;
    });
    if (isCopy) return; // 复制不带租户，电话自然也是空的

    // 【v1.1.1】把主租户电话一并填进表单：此前「添加房间」界面压根没有电话
    // 字段，只能进详情页再补一位租户才能留号码。
    final List<Person> people =
        await PersonRepository.instance.byRoom(widget.roomNo!);
    if (!mounted) return;
    Person? primary;
    for (final Person p in people) {
      if (p.isPrimary) {
        primary = p;
        break;
      }
    }
    final String phone = primary?.phone ?? '';
    if (_phone.text != phone) {
      setState(() => _phone.text = phone);
    }
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
            // 【v1.1.1】一楼是店面、房号并不叫 101 → 楼层支持自定义分组
            _FloorField(
              controller: _floor,
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
              caption: _cycle <= 1
                  ? '月租 ¥${_monthlyRent.round()}'
                  : '月租 ¥${_monthlyRent.toStringAsFixed(2)} · 按「${AppConfig.cycleLabel(_cycle)}」口径填写'
                      '（${AppConfig.cycleLabel(_cycle)}即填${AppConfig.cycleLabel(_cycle)}总额，'
                      '内部按月租入账，不会少收）',
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
            // 【v1.1.1】新增房间时就能填主租户电话（此前只能进详情页再补）
            AppLabelField(
              label: '主租户电话',
              hint: '选填',
              controller: _phone,
              keyboardType: TextInputType.phone,
              labelWidth: _kFieldLabelWidth,
              caption: _phone.text.trim().isEmpty || _phoneOk(_phone.text)
                  ? '选填；在租户卡片上可一键拨打'
                  : '⚠ 号码应为 11 位、1 开头',
              captionColor: _phone.text.trim().isEmpty || _phoneOk(_phone.text)
                  ? null
                  : const Color(0xFFE5484D),
            ),
            AppLabelField(
              label: '身份证号',
              hint: '选填',
              controller: _idCard,
              keyboardType: TextInputType.text,
              labelWidth: _kFieldLabelWidth,
              caption: _idCard.text.trim().isEmpty || _idCardOk(_idCard.text)
                  ? '选填；校验位不通过也能保存，仅供提醒'
                  : '⚠ 位数或校验位不符，请核对',
              captionColor:
                  _idCard.text.trim().isEmpty || _idCardOk(_idCard.text)
                      ? null
                      : const Color(0xFFE5484D),
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
    // 保证「应收 = 月租 × 周期月数」的账期引擎口径不变。
    // 【v1.1.1】月租保留小数：7600 ÷ 12 = 633.333…，应收处再四舍五入回 7600，
    // 此前取整成 633 会让年付凭空少 4 元（633 × 12 = 7596）。
    final double monthlyRent = _monthlyRent;

    final Room room = Room(
      roomNo: roomNo,
      floor: _floor.text.trim(),
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

      // 主租户姓名 / 电话 / 身份证与 people 表联动（有则同步 / 无则补一条
      // 主租户；电话、身份证跟随租户本人存储）
      await PersonRepository.instance
          .syncFromRoom(roomNo, room.tenant, room.idCard, _phone.text.trim());
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
      // 同 settings_edit：对话框退出动画期间内部仍持有该 controller，不手动
      // dispose（否则抛 "used after being disposed"，真机闪红屏 / 弹回首页）。
    } else {
      controller.text = v;
    }
  }
}

/// 【v1.1.1】楼层下拉框：一楼常是店面、房号并不叫 101，楼层需要能自定义。
///
/// 下拉给出 1 ~ 20 层，另附「自定义…」弹窗手输（一楼 / 店面 / 阁楼）；
/// 留空表示继续按房号推导（101 → 1 层）。
class _FloorField extends StatefulWidget {
  const _FloorField({required this.controller, required this.labelWidth});

  final TextEditingController controller;
  final double labelWidth;

  /// 手输楼层的占位标记，选中它才弹输入框
  static const String kCustom = '自定义…';

  @override
  State<_FloorField> createState() => _FloorFieldState();
}

class _FloorFieldState extends State<_FloorField> {
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

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final String v = controller.text.trim();
    // 数字楼层补「层」显示，自定义值（一楼 / 店面）原样显示
    final String shown =
        v.isEmpty ? '' : (int.tryParse(v) != null ? '$v 层' : v);
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
                '楼层',
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
                  // 空值时以占位提示「按房号推导」，有值后显示楼层
                  label: shown.isEmpty ? '按房号推导' : '',
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
                // readOnly 输入框收不到点击，整框补一层手势
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
    final List<MapEntry<String, String>> options = <MapEntry<String, String>>[
      const MapEntry<String, String>('', '按房号推导'),
      for (int i = 1; i <= _RoomEditPageState._maxFloorOption; i++)
        MapEntry<String, String>('$i', '$i 层'),
      if (current.isNotEmpty &&
          int.tryParse(current) == null) // 自定义值也给一个勾选项
        MapEntry<String, String>(current, current),
      const MapEntry<String, String>(_FloorField.kCustom, _FloorField.kCustom),
    ];
    final String? v = await showOptionPicker<String>(
      context,
      title: '选择楼层',
      current: current,
      options: options,
    );
    if (v == null || !context.mounted) return;
    if (v != _FloorField.kCustom) {
      controller.text = v;
      return;
    }
    final TextEditingController ctrl = TextEditingController(text: current);
    final bool? ok = await showAppDialog(
      context,
      title: '自定义楼层',
      summary: '填写任意楼层名称，如「一楼」「店面」「阁楼」',
      content: AppTextField(label: '楼层名称', controller: ctrl),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      controller.text = ctrl.text.trim();
    }
    // 同 _RoomTypeField：对话框退出动画期间仍持有该 controller，不手动 dispose
  }
}
