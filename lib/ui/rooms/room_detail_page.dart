import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_miuix/miuix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/payment.dart';
import '../../data/models/person.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/person_repository.dart';
import '../../data/repository/room_repository.dart';
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
          InfoRow('租金', '¥${room.rent} / 月（本周期已付 ¥${room.paid}）'),
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
              MiuixBasicComponent(
                startAction: MiuixIcon(
                  icon: Icons.person_rounded,
                  tint: _people[i].isPrimary ? c.primary : null,
                ),
                title: _people[i].name,
                summary: _people[i].phone,
                endActions: <Widget>[
                  if (_people[i].isPrimary)
                    StatusTag('主租户', color: c.primary),
                  if (_people[i].phone.isNotEmpty) ...<Widget>[
                    MiuixIconButton(
                      onPressed: () => _callPhone(_people[i].phone),
                      child:
                          const MiuixIcon(icon: Icons.call_rounded, size: 18),
                    ),
                    MiuixIconButton(
                      onPressed: () => _copyPhone(_people[i].phone),
                      child:
                          const MiuixIcon(icon: Icons.copy_rounded, size: 18),
                    ),
                  ],
                  MiuixIconButton(
                    onPressed: () => _editPerson(_people[i]),
                    child: const MiuixIcon(icon: Icons.edit_rounded, size: 18),
                  ),
                  MiuixIconButton(
                    onPressed: () => _deletePerson(_people[i]),
                    child: const MiuixIcon(
                        icon: Icons.delete_outline_rounded, size: 18),
                  ),
                ],
              ),
              if (i != _people.length - 1) const MiuixHorizontalDivider(),
            ],
        ],
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
              ),
              AppTextField(label: '身份证（选填）', controller: idCard),
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
      name.dispose();
      phone.dispose();
      idCard.dispose();
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
    name.dispose();
    phone.dispose();
    idCard.dispose();
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
