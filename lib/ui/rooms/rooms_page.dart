import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/room_repository.dart';
import '../shell/app_shell.dart';
import '../transitions.dart';
import '../widgets/app_widgets.dart';
import 'room_detail_page.dart';
import 'room_edit_page.dart';

/// 房间管理页：房间列表 / 搜索 / 新增 / 进入详情。
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  /// 顶栏折叠行为：上滑时大标题平滑收起，避让右上角操作按钮
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  /// 全部房间
  List<Room> _all = <Room>[];

  /// 搜索关键字
  String _keyword = '';

  /// 搜索框文本控制器（配合 AppTextField 的占位提示修复）
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;

  /// 未结清房租欠款（roomNo → 欠款合计），「房租未缴」标签口径
  Map<String, int> _rentOwed = <String, int>{};

  /// 未结清水电流水聚合（roomNo → 待收金额），「水电待收」标签口径
  Map<String, int> _utilOwed = <String, int>{};

  /// 已折叠的楼层（默认全部展开；点楼层标题可收起/展开）
  final Set<String> _collapsed = <String>{};

  /// 感知底部 Tab 切换（从收款 Tab 收完款切回来要刷新欠款标签）
  ValueListenable<int>? _tabIndex;

  /// 本页在底部导航中的索引
  static const int _tab = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ValueListenable<int> index = AppShellScope.of(context).selectedIndex;
    if (!identical(_tabIndex, index)) {
      _tabIndex?.removeListener(_onTabChanged);
      _tabIndex = index;
      _tabIndex!.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    _tabIndex?.removeListener(_onTabChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 从其它 Tab 切回房间管理时重新拉取（收款 / 抄表 / 编辑都会改欠款）
  void _onTabChanged() {
    if (_tabIndex?.value == _tab && mounted) _load();
  }

  Future<void> _load() async {
    final List<Room> list = await RoomRepository.instance.all();
    // 待收口径：房租 = 未结清 rent 流水欠款；水电 = 未结清流水合计
    final Map<String, int> rentOwed =
        await PaymentRepository.instance.unsettledRentByRoom();
    final Map<String, int> utilOwed =
        await PaymentRepository.instance.unsettledUtilityByRoom();
    if (!mounted) return;
    setState(() {
      _all = list;
      _rentOwed = rentOwed;
      _utilOwed = utilOwed;
      _loading = false;
    });
  }

  /// 过滤后的列表
  List<Room> get _filtered {
    final String k = _keyword.trim();
    if (k.isEmpty) return _all;
    return _all.where((Room r) {
      return r.roomNo.contains(k) ||
          r.tenant.contains(k) ||
          r.roomType.contains(k);
    }).toList();
  }

  /// 按楼层分组（与抄表页同一套口径 [Room.floorOf]）。
  /// 返回值顺序：楼层号升序、「—」（房号无数字）排最后；层内按房号排序。
  List<MapEntry<String, List<Room>>> _floorsOf(List<Room> rooms) {
    final Map<String, List<Room>> m = <String, List<Room>>{};
    for (final Room r in rooms) {
      m.putIfAbsent(Room.floorOf(r.roomNo), () => <Room>[]).add(r);
    }
    final List<String> keys = m.keys.toList()
      ..sort((String a, String b) {
        final int na = int.tryParse(a) ?? 9999;
        final int nb = int.tryParse(b) ?? 9999;
        if (na != nb) return na.compareTo(nb);
        return a.compareTo(b);
      });
    return keys
        .map((String k) => MapEntry<String, List<Room>>(
              k,
              m[k]!..sort((Room a, Room b) => a.roomNo.compareTo(b.roomNo)),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final List<Room> list = _filtered;

    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: '房间管理',
        subtitle:
            '共 ${_all.length} 间 · 在租 ${_all.where((Room r) => r.isOccupied).length} 间',
        actions: <Widget>[
          MiuixIconButton(
            onPressed: _openCollectPanel,
            child: MiuixIcon(
              icon: Icons.account_balance_wallet_rounded,
              tint: c.primary,
            ),
          ),
          const SizedBox(width: 8),
          MiuixIconButton(
            onPressed: _openAdd,
            child: MiuixIcon(icon: Icons.add_rounded, tint: c.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      snackbarHost: const AppSnackbarHost(),
      // 不放悬浮 + 按钮：底部玻璃导航悬浮在它上面，会透出蓝色光斑且
      // 点击被导航栏抢占；新增入口统一用顶栏右上角的 +。
      content: (EdgeInsets padding) {
        if (_loading) {
          return Padding(
            padding: padding,
            child: const Center(child: MiuixCircularProgressIndicator()),
          );
        }
        // MiuixScrollBehaviorListener：把列表滚动桥接给顶栏（大标题折叠）
        return MiuixScrollBehaviorListener(
          behavior: _appBarBehavior,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                padding.top + 8,
                20,
                kGlassNavClearance + 60 + padding.bottom,
              ),
              children: <Widget>[
                //==================== 搜索框 ====================
                AppTextField(
                  label: '搜索房间号 / 承租人 / 房型',
                  controller: _searchCtrl,
                  leadingIcon: const MiuixIcon(icon: Icons.search_rounded),
                  onChanged: (String v) => setState(() => _keyword = v),
                ),
                const SizedBox(height: 12),

                //==================== 房间列表（按楼层分组）====================
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: EmptyView('还没有房间，点右上角 + 新增一间吧'),
                  )
                else
                  for (final MapEntry<String, List<Room>> f in _floorsOf(list))
                    ...<Widget>[
                      _buildFloorHeader(f.key, f.value.length, c),
                      if (!_collapsed.contains(f.key))
                        for (int i = 0; i < f.value.length; i++) ...<Widget>[
                          _buildRoomCard(f.value[i], c),
                          const SizedBox(height: 12),
                        ],
                    ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 楼层标题：点击可折叠/展开该楼层，右侧箭头随状态旋转
  Widget _buildFloorHeader(String floor, int count, MiuixColors c) {
    final bool collapsed = _collapsed.contains(floor);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          if (collapsed) {
            _collapsed.remove(floor);
          } else {
            _collapsed.add(floor);
          }
        }),
        child: Row(
          children: <Widget>[
            MiuixText(
              Room.floorName(floor),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.onSurfaceContainer,
            ),
            const SizedBox(width: 8),
            StatusTag('$count 间', color: c.onSurfaceVariantSummary),
            const Spacer(),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0.25,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: Icon(
                Icons.arrow_drop_down_rounded,
                size: 28,
                color: c.onSurfaceVariantSummary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 单个房间卡片
  Widget _buildRoomCard(Room room, MiuixColors c) {
    final int? days = DateUtil.daysFromNow(room.expire);
    // 周期口径：有未结清流水才算欠；无流水 = 周期内已预付 / 无需收
    final int rentOwed = _rentOwed[room.roomNo] ?? 0;
    final int utilOwed = _utilOwed[room.roomNo] ?? 0;
    final bool utilDue = utilOwed > 0;
    final bool utilAccum = !utilDue && room.utilityFee > 0;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 4),
      onPressed: () => _openDetail(room.roomNo),
      child: Column(
        children: <Widget>[
          MiuixBasicComponent(
            startAction: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: MiuixText(
                  room.roomNo.length > 3
                      ? room.roomNo.substring(room.roomNo.length - 3)
                      : room.roomNo,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ),
            title: room.roomNo,
            summary:
                '${room.isOccupied ? room.tenant : '空置中'} · ${room.roomType.isEmpty ? '未填房型' : room.roomType} · ${_rentSummary(room)}',
            endActions: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // 空置房不挂房租状态：空置不产生房租欠款
                  // （与待办提醒 / 应收统计口径一致）
                  StatusTag(
                    !room.isOccupied
                        ? '空置'
                        : rentOwed == 0
                            ? '房租已缴'
                            : '房租未缴 ¥$rentOwed',
                    color: !room.isOccupied
                        ? c.onSurfaceVariantSummary
                        : rentOwed == 0
                            ? const Color(0xFF34C759)
                            : c.error,
                  ),
                  const SizedBox(height: 4),
                  StatusTag(
                    utilDue
                        ? '水电待收 ¥$utilOwed'
                        : (utilAccum
                            ? '水电累计中 ¥${room.utilityFee}'
                            : '水电已清'),
                    color: utilDue
                        ? const Color(0xFFFF9500)
                        : utilAccum
                            ? c.onSurfaceVariantSummary
                            : const Color(0xFF34C759),
                  ),
                ],
              ),
            ],
          ),
          const MiuixHorizontalDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: <Widget>[
                _MiniInfo('押金', '¥${room.deposit}', c),
                _MiniInfo('钥匙', '${room.keyCount} 把', c),
                _MiniInfo('磁卡', '${room.cardCount} 张', c),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      MiuixText('到期',
                          fontSize: 11, color: c.onSurfaceVariantSummary),
                      const SizedBox(height: 2),
                      MiuixText(
                        days == null
                            ? '未设置'
                            : '${room.expire}（${DateUtil.humanDays(days)}）',
                        fontSize: 12,
                        color:
                            (days != null && days <= 7) ? c.error : c.onSurface,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 租金文案：随设置的房租周期变化（年付显示年总额，月付显示月租），
  /// 与房间编辑页填写口径一致。
  String _rentSummary(Room room) {
    final int cycle = AppConfig.instance.rentCycle;
    if (cycle <= 1) return '租金 ¥${room.rent}/月';
    return '租金 ¥${room.rent * cycle}/${AppConfig.cycleUnit(cycle)}';
  }

  //========================= 跳转 ============================

  void _openDetail(String roomNo) {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => RoomDetailPage(roomNo: roomNo)),
        )
        .then((_) => _load());
  }

  void _openAdd() {
    Navigator.of(context)
        .push(
          AppPageRoute<void>(
              builder: (BuildContext _) => const RoomEditPage()),
        )
        .then((_) => _load());
  }

  void _openCollectPanel() {
    // 收款面板已是底部 Tab（3）：跨 Tab 直接切过去
    AppShellScope.of(context).switchTab(3);
  }
}

/// 卡片底部的小信息块
class _MiniInfo extends StatelessWidget {
  const _MiniInfo(this.label, this.value, this.c);

  final String label;
  final String value;
  final MiuixColors c;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MiuixText(label, fontSize: 11, color: c.onSurfaceVariantSummary),
          const SizedBox(height: 2),
          MiuixText(value, fontSize: 13, fontWeight: FontWeight.w600),
        ],
      ),
    );
  }
}
