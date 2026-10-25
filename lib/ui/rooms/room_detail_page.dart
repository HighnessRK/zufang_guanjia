import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_miuix/miuix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/calc_util.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/payment.dart';
import '../../data/models/person.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/person_repository.dart';
import '../../data/repository/room_repository.dart';
import '../../services/data_bus.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import 'room_edit_page.dart';

/// 房间详情页：房间全部信息 + 租户信息联动 + 历史缴费流水。
class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key, required this.roomNo});

  final String roomNo;

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  Room? _room;
  List<Person> _people = <Person>[];
  List<Payment> _payments = <Payment>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // MCP / 其它入口改了本房间数据 → 详情与流水立即重算（详见 [DataBus]）
    DataBus.instance.addListener(_onDataBus);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataBus);
    super.dispose();
  }

  /// MCP 写操作 → 重新拉取本房间（房间 / 租户 / 流水）
  void _onDataBus() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final Room? room = await RoomRepository.instance.byRoomNo(widget.roomNo);
    final List<Person> people =
        await PersonRepository.instance.byRoom(widget.roomNo);
    final List<Payment> payments =
        await PaymentRepository.instance.byRoom(widget.roomNo);
    if (!mounted) return;
    setState(() {
      _room = room;
      _people = people;
      _payments = payments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final Room? room = _room;

    return AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
        color: Colors.transparent,
        title: widget.roomNo,
        navigationIcon: MiuixIconButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded),
        ),
        actions: <Widget>[
          MiuixIconButton(
            onPressed: _openEdit,
            child: MiuixIcon(icon: Icons.edit_rounded, tint: c.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        if (_loading || room == null) {
          return Padding(
            padding: padding,
            child: const Center(child: MiuixCircularProgressIndicator()),
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
              20, padding.top + 8, 20, kGlassNavClearance + padding.bottom),
          children: <Widget>[
            _buildStatusCard(room, c),
            const SizedBox(height: 12),
            _buildRoomInfoCard(room, c),
            const SizedBox(height: 12),
            _buildApplianceCard(room, c),
            const SizedBox(height: 12),
            _buildPeopleCard(c),
            const SizedBox(height: 12),
            _buildMeterCard(room, c),
            const SizedBox(height: 12),
            _buildPaymentCard(c),
            const SizedBox(height: 20),
            _buildActions(c),
          ],
        );
      },
    );
  }

  /// 顶部状态卡
  Widget _buildStatusCard(Room room, MiuixColors c) {
    final int? days = DateUtil.daysFromNow(room.expire);
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              MiuixText(room.roomNo, fontSize: 24, fontWeight: FontWeight.w700),
              const Spacer(),
              StatusTag(
                room.isOccupied ? '在租中' : '空置',
                color: room.isOccupied
                    ? const Color(0xFF34C759)
                    : c.onSurfaceVariantSummary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow('房型', room.roomType),
          InfoRow('主租户', room.tenant),
          InfoRow('租金', _rentRowText(room)),
          InfoRow('押金', '¥${room.deposit}'),
          InfoRow('入住日期', room.checkIn ?? ''),
          InfoRow(
            '到期日期',
            days == null
                ? (room.expire ?? '')
                : '${room.expire}（${DateUtil.humanDays(days)}）',
            highlight: days != null && days <= 7,
          ),
        ],
      ),
    );
  }

  /// 房间基础信息卡
  Widget _buildRoomInfoCard(Room room, MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MiuixText('资产信息', fontSize: 16, fontWeight: FontWeight.w700),
          const SizedBox(height: 10),
          InfoRow('钥匙', '${room.keyCount} 把'),
          InfoRow('小豆豆（大门磁卡）', '${room.cardCount} 张'),
        ],
      ),
    );
  }

  /// 配套家电卡
  Widget _buildApplianceCard(Room room, MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MiuixText('配套家电', fontSize: 16, fontWeight: FontWeight.w700),
          const SizedBox(height: 10),
          InfoRow('空调', room.ac > 0 ? '${room.ac} 台' : '无'),
          InfoRow('热水器', room.heater > 0 ? '${room.heater} 台' : '无'),
          InfoRow('冰箱', room.fridge > 0 ? '${room.fridge} 台' : '无'),
          InfoRow('洗衣机', room.washer > 0 ? '${room.washer} 台' : '无'),
        ],
      ),
    );
  }

  /// 租户信息卡（与 people 表联动）
  Widget _buildPeopleCard(MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: <Widget>[
                const MiuixText('租户信息',
                    fontSize: 16, fontWeight: FontWeight.w700),
                const Spacer(),
                GradientButton(
                  label: '添加',
                  icon: Icons.person_add_alt_1_rounded,
                  compact: true,
                  onPressed: _addPerson,
                ),
              ],
            ),
          ),
          if (_people.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyView('暂无租户信息', icon: Icons.person_off_rounded),
            )
          else
            for (int i = 0; i < _people.length; i++) ...<Widget>[
              _buildPersonRow(_people[i], c),
              if (i != _people.length - 1) const MiuixHorizontalDivider(),
            ],
        ],
      ),
    );
  }

  /// 租户行：两行布局 + 右侧紧凑操作按钮。
  ///
  /// 【为什么不用 MiuixBasicComponent】title / summary 与 endActions 挤在
  /// 同一行，电话略长 + 四个按钮（拨打 / 复制 / 编辑 / 删除）就会把最右的
  /// 删除按钮顶出屏幕（实测 201 房租户行被右边缘裁切）。改成自定义两行：
  /// 姓名 + 主租户标签独占第一行，电话独占第二行（都超长省略号截断），
  /// 四个 30px 紧凑按钮固定在右侧，宽度永远够用。
  Widget _buildPersonRow(Person p, MiuixColors c) {
    final bool hasPhone = p.phone.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 9, 8, 9),
      child: Row(
        children: <Widget>[
          MiuixIcon(
            icon: Icons.person_rounded,
            size: 21,
            tint: p.isPrimary ? c.primary : c.onSurfaceVariantSummary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: MiuixText(
                        p.name,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (p.isPrimary) ...<Widget>[
                      const SizedBox(width: 6),
                      StatusTag('主租户', color: c.primary),
                    ],
                  ],
                ),
                if (hasPhone) ...<Widget>[
                  const SizedBox(height: 2),
                  MiuixText(
                    p.phone,
                    fontSize: 12.5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    color: c.onSurfaceVariantSummary,
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 2),
                  MiuixText(
                    '未填写电话',
                    fontSize: 12.5,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    color: c.onSurfaceVariantSummary.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 2),
          if (hasPhone) ...<Widget>[
            _personAction(
              icon: Icons.call_rounded,
              tooltip: '拨打',
              color: c.primary,
              onTap: () => _callPhone(p.phone),
            ),
            _personAction(
              icon: Icons.copy_rounded,
              tooltip: '复制',
              onTap: () => _copyPhone(p.phone),
            ),
          ],
          _personAction(
            icon: Icons.edit_rounded,
            tooltip: '编辑',
            onTap: () => _editPerson(p),
          ),
          _personAction(
            icon: Icons.delete_outline_rounded,
            tooltip: '删除',
            color: const Color(0xFFFF3B30),
            onTap: () => _deletePerson(p),
          ),
        ],
      ),
    );
  }

  /// 30×30 紧凑操作按钮：固定宽度保证一行放得下四个且不溢出屏幕。
  Widget _personAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        color: color ?? c.onSurfaceVariantSummary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        splashRadius: 16,
      ),
    );
  }

  /// 抄表信息卡（金额 = 周期累计；徽章 = 周期收缴状态）
  Widget _buildMeterCard(Room room, MiuixColors c) {
    // 待收 = 未结清的 water / elec / 旧版 utility 流水合计
    int owed = 0;
    for (final Payment p in _payments) {
      if ((p.payType == AppConstants.payTypeWater ||
              p.payType == AppConstants.payTypeElec ||
              p.payType == AppConstants.payTypeUtility) &&
          !p.isSettled &&
          p.due > 0) {
        owed += p.due - p.paid;
      }
    }
    final bool dueNow = owed > 0;
    final bool accumulating = !dueNow && room.utilityFee > 0;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const MiuixText('水电抄表',
                  fontSize: 16, fontWeight: FontWeight.w700),
              const Spacer(),
              StatusTag(
                dueNow
                    ? '待收 ¥$owed'
                    : (accumulating ? '累计中' : '已结清'),
                color: dueNow
                    ? const Color(0xFFFF9500)
                    : (accumulating
                        ? c.onSurfaceVariantSummary
                        : const Color(0xFF34C759)),
              ),
              const SizedBox(width: 10),
              // 编辑上期 / 本期水电读数
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openMeterEdit(room),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: MiuixText('编辑',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow('上期电表', '${room.elecPrev} 度'),
          InfoRow('本期电表', '${room.elecCurr} 度'),
          InfoRow('上期水表', '${room.waterPrev} 吨'),
          InfoRow('本期水表', '${room.waterCurr} 吨'),
          const SizedBox(height: 6),
          const MiuixHorizontalDivider(),
          const SizedBox(height: 6),
          InfoRow('电费', '¥${room.elecFee}'),
          InfoRow('水费', '¥${room.waterFee}'),
          InfoRow('水电费合计', '¥${room.utilityFee}', highlight: true),
        ],
      ),
    );
  }

  /// 编辑本房间水电读数（上期 / 本期电水表）。
  /// 保存后按当前单价重算费用并跑一遍周期引擎，与抄表页口径一致。
  Future<void> _openMeterEdit(Room room) async {
    final TextEditingController elecPrev =
        TextEditingController(text: '${room.elecPrev}');
    final TextEditingController elecCurr =
        TextEditingController(text: '${room.elecCurr}');
    final TextEditingController waterPrev =
        TextEditingController(text: '${room.waterPrev}');
    final TextEditingController waterCurr =
        TextEditingController(text: '${room.waterCurr}');
    final List<TextEditingController> ctrls = <TextEditingController>[
      elecPrev,
      elecCurr,
      waterPrev,
      waterCurr,
    ];

    final bool? ok = await showAppDialog(
      context,
      title: '编辑水电读数',
      summary: '修改后按当前单价重算费用',
      confirmText: '保存',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppLabelField(
              label: '上期电表', controller: elecPrev, labelWidth: 76),
          AppLabelField(
              label: '本期电表', controller: elecCurr, labelWidth: 76),
          AppLabelField(
              label: '上期水表', controller: waterPrev, labelWidth: 76),
          AppLabelField(
              label: '本期水表', controller: waterCurr, labelWidth: 76),
          _MeterFeePreview(
            room: room,
            elecPrev: elecPrev,
            elecCurr: elecCurr,
            waterPrev: waterPrev,
            waterCurr: waterCurr,
          ),
        ],
      ),
    );
    // 先取值再销毁控制器，避免 use-after-dispose
    final int ep = int.tryParse(elecPrev.text.trim()) ?? room.elecPrev;
    final int ec = int.tryParse(elecCurr.text.trim()) ?? room.elecCurr;
    final int wp = int.tryParse(waterPrev.text.trim()) ?? room.waterPrev;
    final int wc = int.tryParse(waterCurr.text.trim()) ?? room.waterCurr;
    for (final TextEditingController t in ctrls) {
      t.dispose();
    }
    if (ok != true || !mounted) return;

    // 本期读数小于上期 → 与抄表页一致二次确认
    if (ec < ep || wc < wp) {
      final bool? cont = await showAppDialog(
        context,
        title: '读数异常',
        summary: '本期读数小于上期读数，可能导致账单为 0，确定继续保存吗？',
        confirmText: '继续保存',
        danger: true,
      );
      if (cont != true || !mounted) return;
    }

    final AppConfig cfg = AppConfig.instance;
    final CalcResult r = CalcUtil.compute(
      elecPrev: ep,
      elecCurr: ec,
      waterPrev: wp,
      waterCurr: wc,
      elecPrice: cfg.elecPrice,
      waterPrice: cfg.waterPrice,
    );
    await RoomRepository.instance.updateMeter(
      roomNo: room.roomNo,
      elecPrev: ep,
      elecCurr: ec,
      waterPrev: wp,
      waterCurr: wc,
      elecFee: r.elecFee,
      waterFee: r.waterFee,
      utilityFee: r.totalFee,
    );
    // 跑一遍周期引擎：满周期的累计额立即生成待收流水
    final List<Room> fresh = await RoomRepository.instance.all();
    await PaymentRepository.instance.ensureCurrentPeriod(fresh);
    if (!mounted) return;
    AppSnackbar.show('已保存 ${room.roomNo} 水电读数，费用合计 ¥${r.totalFee}');
    await _load();
  }

  /// 历史缴费流水卡
  Widget _buildPaymentCard(MiuixColors c) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: <Widget>[
                MiuixText('历史缴费流水', fontSize: 16, fontWeight: FontWeight.w700),
              ],
            ),
          ),
          if (_payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: EmptyView('暂无缴费记录', icon: Icons.receipt_long_rounded),
            )
          else
            for (int i = 0; i < _payments.length; i++) ...<Widget>[
              MiuixBasicComponent(
                title: '${_payments[i].period} ${_payments[i].payTypeText}',
                summary: '应收 ¥${_payments[i].due} · 实收 ¥${_payments[i].paid}'
                    '${_payments[i].debt > 0 ? ' · 欠 ¥${_payments[i].debt}' : ''}',
                endActions: <Widget>[
                  StatusTag(
                    _payments[i].isSettled ? '已结清' : '未结清',
                    color: _payments[i].isSettled
                        ? const Color(0xFF34C759)
                        : c.error,
                  ),
                ],
              ),
              if (i != _payments.length - 1) const MiuixHorizontalDivider(),
            ],
        ],
      ),
    );
  }

  /// 底部操作按钮
  Widget _buildActions(MiuixColors c) {
    return Row(
      children: <Widget>[
        Expanded(
          child: MiuixTextButton('编辑房间', onPressed: _openEdit),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MiuixButton(
            onPressed: _deleteRoom,
            colors: MiuixButtonColors(
              color: c.error,
              disabledColor: c.disabledPrimaryButton,
              contentColor: c.onError,
              disabledContentColor: c.disabledOnPrimaryButton,
            ),
            child: const MiuixText('删除房间'),
          ),
        ),
      ],
    );
  }

  //========================= 操作 ============================

  void _openEdit() {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => RoomEditPage(roomNo: widget.roomNo)),
        )
        .then((_) => _load());
  }

  Future<void> _deleteRoom() async {
    final bool? ok = await showAppDialog(
      context,
      title: '删除房间 ${widget.roomNo}？',
      summary: '删除后该房间的租户信息与缴费流水将一并清空，且无法恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (ok != true || !mounted) return;
    await RoomRepository.instance.delete(widget.roomNo);
    if (!mounted) return;
    AppSnackbar.show('房间 ${widget.roomNo} 已删除');
    Navigator.of(context).pop();
  }

  /// 弹出「新增 / 编辑租户」表单（含主租户开关、身份证）
  Future<void> _addPerson([Person? person]) async {
    final TextEditingController name =
        TextEditingController(text: person?.name ?? '');
    final TextEditingController phone =
        TextEditingController(text: person?.phone ?? '');
    final TextEditingController idCard =
        TextEditingController(text: person?.idCard ?? '');

    // 房间还没有主租户时，新增的第一位默认即主租户
    bool hasPrimary = false;
    for (final Person p in _people) {
      if (p.isPrimary) {
        hasPrimary = true;
        break;
      }
    }
    bool isPrimary = person?.isPrimary ?? !hasPrimary;

    final bool? ok = await showAppDialog(
      context,
      title: person == null ? '新增租户' : '编辑租户',
      content: StatefulBuilder(
        builder: (BuildContext dlgCtx, void Function(VoidCallback) setDlg) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppTextField(label: '姓名', controller: name),
              AppTextField(
                label: '电话',
                controller: phone,
                keyboardType: TextInputType.phone,
                clearComposing: true,
              ),
              AppTextField(
                label: '身份证（选填）',
                controller: idCard,
                clearComposing: true,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: MiuixText('设为主租户', fontSize: 14),
                    ),
                    MiuixSwitch(
                      value: isPrimary,
                      onChanged: (bool v) => setDlg(() => isPrimary = v),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;

    final String newName = name.text.trim();
    if (newName.isEmpty) {
      // 【控制器释放时机】不能在这里 dispose()：showAppDialog 的 Future 在
      // 路由 pop 的瞬间就完成，而对话框的 220ms 退出动画还没跑完，内部
      // MiuixTextField / EditableText 仍持有这些 controller（输入法也未收起）。
      // 此时释放会触发 "A TextEditingController was used after being disposed"，
      // 真机表现为保存后闪一下红色报错页 / 被弹回首页。它们是局部变量，
      // 对话框卸载后监听随之解除，交给 GC 回收即可。
      AppSnackbar.show('请填写姓名');
      return;
    }

    if (person == null) {
      final int id = await PersonRepository.instance.insert(Person(
          roomNo: widget.roomNo,
          name: newName,
          phone: phone.text.trim(),
          idCard: idCard.text.trim(),
          isPrimary: isPrimary));
      if (isPrimary) {
        // 同房间其它租户取消主标记 + rooms.tenant 镜像
        await PersonRepository.instance
            .applyPrimary(id, widget.roomNo, true);
      }
    } else {
      final bool wasPrimary = person.isPrimary;
      person.name = newName;
      person.phone = phone.text.trim();
      person.idCard = idCard.text.trim();
      person.isPrimary = isPrimary;
      await PersonRepository.instance.update(person);
      if (isPrimary != wasPrimary) {
        await PersonRepository.instance
            .applyPrimary(person.id!, widget.roomNo, isPrimary);
      }
    }
    if (!mounted) return;
    AppSnackbar.show('租户信息已保存');
    _load();
  }

  /// 一键拨号：唤起系统拨号盘预填该租户号码
  Future<void> _callPhone(String phone) async {
    final Uri uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) AppSnackbar.show('无法打开拨号应用');
    }
  }

  /// 复制电话号码到剪贴板
  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    AppSnackbar.show('电话号码已复制');
  }

  /// 租金文案：随设置的房租周期变化（年付显示年总额，月付显示月租），
  /// 与房间编辑页填写口径一致。
  String _rentRowText(Room room) {
    final int cycle = AppConfig.instance.rentCycle;
    final String unit = AppConfig.cycleUnit(cycle);
    // 月租已改为小数（年付 7600 ÷ 12 = 633.333…），展示时先乘后四舍五入，
    // 整周期金额原样显示 7600，不再出现 7596
    final int monthly = room.rent.round();
    if (cycle <= 1) {
      return '¥$monthly / 月（本周期已付 ¥${room.paid}）';
    }
    final int per = (room.rent * cycle).round();
    return '¥$per / $unit（月租 ¥$monthly · 本周期已付 ¥${room.paid}）';
  }

  void _editPerson(Person person) => _addPerson(person);

  Future<void> _deletePerson(Person person) async {
    final bool? ok = await showAppDialog(
      context,
      title: '删除租户 ${person.name}？',
      summary: person.isPrimary && _people.length > 1
          ? '删除后其余租户中最早的一位将升为主租户。'
          : null,
      confirmText: '删除',
      danger: true,
    );
    if (ok != true || person.id == null) return;
    await PersonRepository.instance.deleteAndReassign(person);
    if (!mounted) return;
    AppSnackbar.show('租户已删除');
    _load();
  }
}

/// 水电读数编辑弹窗内的实时费用预览：
/// 任一读数变化即按当前单价重算电费 / 水费 / 合计。
class _MeterFeePreview extends StatefulWidget {
  const _MeterFeePreview({
    required this.room,
    required this.elecPrev,
    required this.elecCurr,
    required this.waterPrev,
    required this.waterCurr,
  });

  final Room room;
  final TextEditingController elecPrev;
  final TextEditingController elecCurr;
  final TextEditingController waterPrev;
  final TextEditingController waterCurr;

  @override
  State<_MeterFeePreview> createState() => _MeterFeePreviewState();
}

class _MeterFeePreviewState extends State<_MeterFeePreview> {
  @override
  void initState() {
    super.initState();
    for (final TextEditingController t in _ctrls) {
      t.addListener(_sync);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController t in _ctrls) {
      t.removeListener(_sync);
    }
    super.dispose();
  }

  List<TextEditingController> get _ctrls => <TextEditingController>[
        widget.elecPrev,
        widget.elecCurr,
        widget.waterPrev,
        widget.waterCurr,
      ];

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final Room room = widget.room;
    final AppConfig cfg = AppConfig.instance;
    final CalcResult r = CalcUtil.compute(
      elecPrev: int.tryParse(widget.elecPrev.text.trim()) ?? room.elecPrev,
      elecCurr: int.tryParse(widget.elecCurr.text.trim()) ?? room.elecCurr,
      waterPrev: int.tryParse(widget.waterPrev.text.trim()) ?? room.waterPrev,
      waterCurr: int.tryParse(widget.waterCurr.text.trim()) ?? room.waterCurr,
      elecPrice: cfg.elecPrice,
      waterPrice: cfg.waterPrice,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 86, top: 2),
      child: MiuixText(
        '重算预览：电费 ¥${r.elecFee} · 水费 ¥${r.waterFee} · 合计 ¥${r.totalFee}',
        fontSize: 12,
        color: c.onSurfaceVariantSummary,
      ),
    );
  }
}
