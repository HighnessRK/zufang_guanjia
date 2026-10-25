import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/calc_util.dart';
import '../../core/utils/date_util.dart';
import '../../data/models/room.dart';
import '../../data/repository/payment_repository.dart';
import '../../data/repository/room_repository.dart';
import '../../services/data_bus.dart';
import '../../services/llm_service.dart';
import '../settings/llm_settings_page.dart';
import '../shell/app_shell.dart';
import '../widgets/app_widgets.dart';

/// 水电抄录页（核心高频功能）——按楼层组织：
///   每层卡片：【整层拍电表 · AI 统一识别多块表】/【整层录水表 · 批量输入】
///   每间房行：单房间拍照 / 水表输入 / 已收徽章 / 实时费用
///   底部一键保存全部修改。
///
/// 楼层由房间号推导：去掉最后两位（101→1层、1203→12层），
/// 不足三位的房号归入「其他」。
class MeterPage extends StatefulWidget {
  const MeterPage({super.key});

  @override
  State<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends State<MeterPage> {
  /// 顶栏折叠行为：上滑时大标题平滑收起，避让右上角操作按钮
  final MiuixExitUntilCollapsedScrollBehavior _appBarBehavior =
      miuixScrollBehavior();

  /// 全部房间
  List<Room> _rooms = <Room>[];

  /// 每间房的本期电表 / 水表输入控制器
  final Map<String, TextEditingController> _elecCtrls =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _waterCtrls =
      <String, TextEditingController>{};

  /// 每间房的周期待收水电费（未结清 water/elec 流水聚合，只读状态）
  final Map<String, int> _owed = <String, int>{};

  /// 拍照识别进行中（AI 按钮置灰 + 转圈）
  bool _recognizing = false;

  /// 正在批量识别的楼层（置灰该层按钮）
  String? _busyFloor;

  /// 正在单房间识别的房号（置灰该行相机按钮）
  String? _recognizingRoom;

  /// 整层录水表批量输入表单
  bool _waterSheetVisible = false;
  String? _waterSheetFloor;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // MCP / 其它入口改动读数后立刻刷新（详见 [DataBus]）
    DataBus.instance.addListener(_onDataBus);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataBus);
    for (final TextEditingController c in _elecCtrls.values) {
      c.dispose();
    }
    for (final TextEditingController c in _waterCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// MCP 写操作 → 读数与待收立即重算。
  ///
  /// 【保护未保存输入】本页是「边录边存草稿」模式，用户可能已改了读数
  /// 还没点保存。此时若被外部改动冲掉，比不刷新更糟（DataBus 只在焦点
  /// 落在输入框时才拦截）。所以有未保存修改时直接跳过本次刷新。
  void _onDataBus() {
    if (!mounted) return;
    if (_changeCount() > 0) return;
    _load();
  }

  Future<void> _load() async {
    final List<Room> rooms = await RoomRepository.instance.all();
    if (!mounted) return;

    // 重建输入控制器（以数据库当前值为基准）
    for (final TextEditingController c in _elecCtrls.values) {
      c.removeListener(_onEdit);
      c.dispose();
    }
    for (final TextEditingController c in _waterCtrls.values) {
      c.removeListener(_onEdit);
      c.dispose();
    }
    _elecCtrls.clear();
    _waterCtrls.clear();
    _owed.clear();
    final Map<String, int> owed =
        await PaymentRepository.instance.unsettledUtilityByRoom();
    _owed.addAll(owed);
    for (final Room r in rooms) {
      final TextEditingController ec =
          TextEditingController(text: '${r.elecCurr}');
      final TextEditingController wc =
          TextEditingController(text: '${r.waterCurr}');
      ec.addListener(_onEdit);
      wc.addListener(_onEdit);
      _elecCtrls[r.roomNo] = ec;
      _waterCtrls[r.roomNo] = wc;
    }
    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  /// 任意输入变化 → 重算费用行与「修改计数」
  void _onEdit() => setState(() {});

  //===================== 楼层分组 =====================

  /// 楼层推导（口径统一收进 [Room.floorOf]，房间管理页共用）
  /// 楼层 → 房间列表（自定义楼层优先；数字楼层升序 → 汉字序数 →
  /// 其他文本 → 「—」最后；层内按房号排序）。与房间管理页同口径。
  List<MapEntry<String, List<Room>>> _floors() {
    final Map<String, List<Room>> m = <String, List<Room>>{};
    for (final Room r in _rooms) {
      m.putIfAbsent(r.floorKey, () => <Room>[]).add(r);
    }
    final List<String> keys = m.keys.toList()..sort(Room.floorCompare);
    return keys
        .map((String k) => MapEntry<String, List<Room>>(
              k,
              m[k]!..sort((Room a, Room b) => a.roomNo.compareTo(b.roomNo)),
            ))
        .toList();
  }

  List<Room> _roomsOf(String floor) =>
      _rooms.where((Room r) => r.floorKey == floor).toList()
        ..sort((Room a, Room b) => a.roomNo.compareTo(b.roomNo));

  /// 楼层展示名：数字楼层补「层」，自定义楼层（一楼 / 店面）原样显示，
  /// '—'（房号无数字的房间）显示为「其他房间」
  String _floorName(String? floor) =>
      floor == null ? '其他房间' : Room.floorName(floor);

  //===================== 实时计算与修改统计 =====================

  /// 按当前输入重算某房间的水电费
  CalcResult _calcFor(Room room) {
    final AppConfig cfg = AppConfig.instance;
    final int elecCurr =
        int.tryParse(_elecCtrls[room.roomNo]?.text.trim() ?? '') ??
            room.elecCurr;
    final int waterCurr =
        int.tryParse(_waterCtrls[room.roomNo]?.text.trim() ?? '') ??
            room.waterCurr;
    return CalcUtil.compute(
      elecPrev: room.elecPrev,
      elecCurr: elecCurr,
      waterPrev: room.waterPrev,
      waterCurr: waterCurr,
      elecPrice: cfg.elecPrice,
      waterPrice: cfg.waterPrice,
    );
  }

  /// 该房间是否有未保存的修改（只看读数，收缴状态由结算按钮处理）
  bool _changed(Room room) {
    final String e = _elecCtrls[room.roomNo]?.text.trim() ?? '';
    final String w = _waterCtrls[room.roomNo]?.text.trim() ?? '';
    return e != '${room.elecCurr}' || w != '${room.waterCurr}';
  }

  int _changeCount() => _rooms.where(_changed).length;

  //===================== 大模型配置检查 =====================

  Future<bool> _ensureLlmConfig() async {
    final AppConfig cfg = AppConfig.instance;
    if (cfg.llmBaseUrl.isEmpty ||
        cfg.llmApiKey.isEmpty ||
        cfg.llmVisionModel.isEmpty) {
      final bool? go = await showAppDialog(
        context,
        title: '未配置大模型 API',
        summary:
            '拍照识别需要先在「设置 → 大模型识别」填写地址 / Key / 视觉模型，现在去配置吗？',
        confirmText: '去配置',
      );
      if (go == true && mounted) {
        // 直达「大模型识别」配置页：重置设置 Tab 栈后压入，避免落在
        // 该 Tab 上次停留的旧二级页（如缴费统计）上
        AppShellScope.of(context)
            .switchTabAndPush(4, const LlmSettingsPage());
      }
      return false;
    }
    return true;
  }

  //===================== 单房间电表拍照（保留） =====================

  /// 取一张电表照片：先问来源（拍照 / 相册），再交给 image_picker。
  /// 相册路径走系统照片选择器（Photo Picker），全程不申请存储权限。
  Future<XFile?> _pickImage(int maxWidth, int imageQuality) async {
    final AppImageSource? source = await showImageSourceDialog(
      context,
      title: '电表照片来源',
      summary: '拍照现拍，或从相册选一张已有的电表照片交给 AI 识别',
    );
    if (source == null) return null;
    return ImagePicker().pickImage(
      source: source == AppImageSource.gallery
          ? ImageSource.gallery
          : ImageSource.camera,
      maxWidth: maxWidth.toDouble(),
      imageQuality: imageQuality,
    );
  }

  Future<void> _captureRoomElec(Room room) async {
    if (!await _ensureLlmConfig()) return;
    if (_recognizing) return;

    try {
      final XFile? shot = await _pickImage(1440, 85);
      if (shot == null) return; // 用户取消拍照

      setState(() {
        _recognizing = true;
        _recognizingRoom = room.roomNo;
      });
      AppSnackbar.show('正在识别 ${room.roomNo} 电表…');

      final bytes = await shot.readAsBytes();
      final int reading = await LlmService.recognizeElecMeter(bytes);

      if (!mounted) return;
      _elecCtrls[room.roomNo]!.text = '$reading'; // 触发监听 → 自动重算
      AppSnackbar.show('识别成功：${room.roomNo} 本期电表 $reading 度');
    } on StateError catch (e) {
      AppSnackbar.show(e.message);
    } catch (e) {
      final String msg = '$e';
      AppSnackbar.show(
          '识别失败：${msg.length > 90 ? msg.substring(0, 90) : msg}');
    } finally {
      if (mounted) {
        setState(() {
          _recognizing = false;
          _recognizingRoom = null;
        });
      }
    }
  }

  //===================== 整层批量拍电表（AI 按位置识别） =====================

  /// 整层拍电表：内置位置序提示词识别 → **自动填入**本层输入框。
  ///
  /// 【映射规则】电表按「每行从左到右、行与行从上到下」排布，与本层
  /// 房间号升序一一对应（4 块表 → x01/x02/x03/x05，5 块表 →
  /// x01/x02/x03/x05/x06，房号本就没有 04 所以天然跳过）。
  /// 模型返回的第 n 个读数直接落到第 n 个房间，不再弹核对表单。
  Future<void> _captureFloorElec(String floor) async {
    if (!await _ensureLlmConfig()) return;
    if (_recognizing) return;

    final List<Room> rooms = _roomsOf(floor);
    if (rooms.isEmpty) {
      AppSnackbar.show('本层没有房间，无法填入');
      return;
    }
    final List<String> roomNos = rooms.map((Room r) => r.roomNo).toList();

    try {
      final XFile? shot = await _pickImage(1920, 88);
      if (shot == null) return;

      setState(() {
        _recognizing = true;
        _busyFloor = floor;
      });
      AppSnackbar.show('大模型正在识别本层电表…');

      final bytes = await shot.readAsBytes();
      final List<int> readings =
          await LlmService.recognizeFloorMeterReadings(
        bytes,
        roomNos: roomNos,
      );

      if (!mounted) return;

      // 按下标对位填入：读数 < 0 表示该格模型没读出来，跳过
      final List<String> filled = <String>[];
      int changed = 0;
      setState(() {
        final int n = readings.length < roomNos.length
            ? readings.length
            : roomNos.length;
        for (int i = 0; i < n; i++) {
          final int v = readings[i];
          if (v < 0) continue;
          final String roomNo = roomNos[i];
          final TextEditingController? ctrl = _elecCtrls[roomNo];
          if (ctrl == null) continue;
          if (ctrl.text.trim() != '$v') changed++;
          ctrl.text = '$v';
          filled.add('$roomNo→$v');
        }
      });

      final String summary = filled.isEmpty ? '（无有效读数）' : filled.join(' ');
      if (filled.isEmpty) {
        AppSnackbar.show('未能读出任何有效读数，请重拍或换个角度');
      } else if (changed == 0) {
        AppSnackbar.show('识别值与当前输入一致，没有变化：$summary');
      } else if (readings.length != roomNos.length) {
        AppSnackbar.show(
            '识别到 ${readings.length} 块表，本层有 ${roomNos.length} 间房，'
            '已按位置顺序填入 ${filled.length} 间（其中 $changed 间有变化）：'
            '$summary，请核对');
      } else {
        AppSnackbar.show(
            '已按位置顺序填入 ${filled.length} 间（其中 $changed 间有变化），'
            '请核对后保存：$summary');
      }
    } on StateError catch (e) {
      AppSnackbar.show(e.message);
    } catch (e) {
      final String msg = '$e';
      AppSnackbar.show(
          '识别失败：${msg.length > 90 ? msg.substring(0, 90) : msg}');
    } finally {
      if (mounted) {
        setState(() {
          _recognizing = false;
          _busyFloor = null;
        });
      }
    }
  }

  //===================== 整层批量录水表 =====================

  void _openWaterSheet(String floor) {
    setState(() {
      _waterSheetVisible = true;
      _waterSheetFloor = floor;
    });
  }

  //===================== 一键保存全部 =====================

  Future<void> _saveAll() async {
    final List<Room> changed = _rooms.where(_changed).toList();
    if (changed.isEmpty) {
      AppSnackbar.show('没有需要保存的修改');
      return;
    }

    // 读数异常检查（0 视为「本期还没抄」，只有真正抄出的读数
    // 低于上期才提示异常）
    final List<Room> anomalies = changed.where((Room r) {
      final int e = int.tryParse(_elecCtrls[r.roomNo]?.text.trim() ?? '') ??
          r.elecCurr;
      final int w = int.tryParse(_waterCtrls[r.roomNo]?.text.trim() ?? '') ??
          r.waterCurr;
      return (e > 0 && e < r.elecPrev) || (w > 0 && w < r.waterPrev);
    }).toList();
    if (anomalies.isNotEmpty) {
      final bool? ok = await showAppDialog(
        context,
        title: '读数异常',
        summary:
            '${anomalies.map((Room r) => r.roomNo).join('、')} 本期读数小于上期读数，可能导致账单为 0，确定继续保存吗？',
        confirmText: '继续保存',
        danger: true,
      );
      if (ok != true) return;
    }

    // 释放输入焦点：IME 残留焦点会在之后导航/弹栈时莫名重新弹出
    FocusManager.instance.primaryFocus?.unfocus();

    int total = 0;
    int count = 0;
    for (final Room room in changed) {
      final int elecCurr =
          int.tryParse(_elecCtrls[room.roomNo]?.text.trim() ?? '') ??
              room.elecCurr;
      final int waterCurr =
          int.tryParse(_waterCtrls[room.roomNo]?.text.trim() ?? '') ??
              room.waterCurr;
      final CalcResult r = _calcFor(room);

      // 更新 rooms 表的抄表与周期累计水电费字段
      // （curr − prev 以周期起点为基准，结算前不清零，天然累计）
      await RoomRepository.instance.updateMeter(
        roomNo: room.roomNo,
        elecPrev: room.elecPrev,
        elecCurr: elecCurr,
        waterPrev: room.waterPrev,
        waterCurr: waterCurr,
        elecFee: r.elecFee,
        waterFee: r.waterFee,
        utilityFee: r.totalFee,
      );

      total += r.totalFee;
      count++;
    }

    // 跑一遍周期引擎：满周期的累计额立即生成待收流水、首次累计落基准月
    final List<Room> fresh = await RoomRepository.instance.all();
    await PaymentRepository.instance.ensureCurrentPeriod(fresh);

    if (!mounted) return;
    AppSnackbar.show('已保存 $count 间房的抄表数据，水电费合计 ¥$total');
    await _load();
  }

  //===================== 界面 =====================

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    final List<MapEntry<String, List<Room>>> floors = _floors();
    final int changeCount = _changeCount();

    return AuroraScaffold(
      topBar: MiuixTopAppBar(
        scrollBehavior: _appBarBehavior,
        color: Colors.transparent,
        title: '水电抄录',
        subtitle: '账期 ${DateUtil.currentPeriod} · 按楼层分布',
        actions: <Widget>[
          MiuixIconButton(
            onPressed: _load,
            child: const MiuixIcon(icon: Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      snackbarHost: const AppSnackbarHost(),
      content: (EdgeInsets padding) {
        if (_loading) {
          return Padding(
            padding: padding,
            child: const Center(child: MiuixCircularProgressIndicator()),
          );
        }
        return Stack(
          children: <Widget>[
            // 极光背景已由 AuroraScaffold 铺满整页（含顶栏区）
            // MiuixScrollBehaviorListener：把列表滚动桥接给顶栏（大标题折叠）
            MiuixScrollBehaviorListener(
              behavior: _appBarBehavior,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, padding.top + 8, 20,
                    kGlassNavClearance + padding.bottom + 72),
                children: <Widget>[
                  if (_rooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: EmptyView(
                        '暂无房间，请先在「房间」新增房间',
                        hint: '添加房间后即可按楼层批量抄表',
                      ),
                    )
                  else ...<Widget>[
                    for (final MapEntry<String, List<Room>> f in floors) ...<Widget>[
                      SectionTitle(
                          f.key == '—' ? '其他房间 · ${f.value.length} 间' : '${f.key} 层 · ${f.value.length} 间'),
                      _buildFloorCard(c, f.key, f.value),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 4),
                    GradientButton(
                      label: changeCount == 0
                          ? '保存抄表数据'
                          : '保存抄表数据（$changeCount 处修改）',
                      icon: Icons.save_rounded,
                      onPressed: _saveAll,
                    ),
                  ],
                ],
              ),
            ),

            //=============== 整层录水表：批量输入 ===============
            MiuixOverlayBottomSheet(
              show: _waterSheetVisible && _waterSheetFloor != null,
              title: '${_floorName(_waterSheetFloor)} · 批量录入水表',
              onDismissRequest: () =>
                  setState(() => _waterSheetVisible = false),
              content: SizedBox(
                height: 470,
                child: _waterSheetFloor == null
                    ? const SizedBox.shrink()
                    : _WaterFloorSheet(
                        key: ValueKey<String>('water_${_waterSheetFloor ?? ''}'),
                        rooms: _roomsOf(_waterSheetFloor!),
                        prefill: <String, String>{
                          for (final Room r in _roomsOf(_waterSheetFloor!))
                            r.roomNo: _waterCtrls[r.roomNo]?.text.trim() ?? '',
                        },
                        onConfirm: (Map<String, String> values) {
                          // 只统计与当前值不同的房间（预填 0 未改不算填入）
                          int changed = 0;
                          setState(() {
                            values.forEach((String roomNo, String v) {
                              if ((_waterCtrls[roomNo]?.text.trim() ?? '') !=
                                  v) {
                                changed++;
                              }
                              _waterCtrls[roomNo]?.text = v;
                            });
                            _waterSheetVisible = false;
                          });
                          if (changed == 0) {
                            AppSnackbar.show('读数没有变化');
                          } else {
                            AppSnackbar.show(
                                '已填入 $changed 间房的水表读数，请核对后保存');
                          }
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 楼层卡片：批量操作行 + 每间房明细
  Widget _buildFloorCard(MiuixColors c, String floor, List<Room> rooms) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 楼层批量操作行
          Row(
            children: <Widget>[
              Expanded(
                child: _buildFloorAction(
                  c,
                  icon: Icons.photo_camera_rounded,
                  label: '整层拍电表',
                  ai: true,
                  busy: _recognizing && _busyFloor == floor,
                  colors: const <Color>[Color(0xFF3482FF), Color(0xFF7B5CFF)],
                  onTap: () => _captureFloorElec(floor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFloorAction(
                  c,
                  icon: Icons.edit_rounded,
                  label: '整层录水表',
                  ai: false,
                  busy: false,
                  colors: const <Color>[Color(0xFF3FC1FF), Color(0xFF2A7BFF)],
                  onTap: () => _openWaterSheet(floor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const MiuixHorizontalDivider(),
          for (int i = 0; i < rooms.length; i++) ...<Widget>[
            if (i > 0) const MiuixHorizontalDivider(),
            _buildRoomRow(c, rooms[i]),
          ],
        ],
      ),
    );
  }

  /// 楼层批量操作按钮：渐变描边胶囊，AI 带角标，识别中转圈
  Widget _buildFloorAction(
    MiuixColors c, {
    required IconData icon,
    required String label,
    required bool ai,
    required bool busy,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    final Color main = colors.first;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Opacity(
        opacity: busy ? 0.75 : 1,
        child: Container(
          height: 42,
          // 【v1.1.1 修复】padding 12→8、图标与文字间距 8→6，并把文字包进
          // Flexible + ellipsis：楼层整排按钮里「整层拍电表」这类长标签此前
          // 直接把胶囊撑破，右侧漏出黄黑溢出条（RIGHT OVERFLOWED BY 7）。
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                colors[0].withValues(alpha: 0.12),
                colors[1].withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: main.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: main,
                      ),
                    )
                  : Icon(icon, size: 17, color: main),
              const SizedBox(width: 6),
              Flexible(
                child: MiuixText(
                  busy ? '识别中…' : label,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: main,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ai) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF3482FF), Color(0xFF7B5CFF)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const MiuixText(
                    'AI',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 单间房行（单行紧凑版）：房号 | 电表输入（内嵌单间拍照相机）|
  /// 水表输入 | 合计 + 收缴状态徽章（只读，收缴在房间编辑页操作）。
  /// 上期读数不再常驻展示，仅在「本期 < 上期」异常时追加一行警示。
  Widget _buildRoomRow(MiuixColors c, Room room) {
    final TextEditingController ec = _elecCtrls[room.roomNo]!;
    final TextEditingController wc = _waterCtrls[room.roomNo]!;
    final CalcResult calc = _calcFor(room);
    // 实际抄出的读数：0 视为「本期还没抄」，不参与异常告警
    final int ecNum = int.tryParse(ec.text.trim()) ?? room.elecCurr;
    final int wcNum = int.tryParse(wc.text.trim()) ?? room.waterCurr;
    final bool elecBad = calc.elecUseRaw < 0 && ecNum > 0;
    final bool waterBad = calc.waterUseRaw < 0 && wcNum > 0;
    // 周期状态：待收（已到期未结清）> 累计中（未到期）> 已结清
    final int owed = _owed[room.roomNo] ?? 0;
    final bool dueNow = owed > 0;
    final bool accumulating = !dueNow && calc.totalFee > 0;
    final bool changed = _changed(room);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // 房号
              MiuixText(room.roomNo,
                  fontSize: 15, fontWeight: FontWeight.w700),
              // 有未保存修改：橙色小圆点
              if (changed) ...<Widget>[
                const SizedBox(width: 5),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9500),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // 电表：⚡ 前缀 + 行内相机
              _buildReadingField(
                c,
                ec,
                const Color(0xFFFFB340),
                prefix: const Icon(Icons.bolt_rounded,
                    size: 15, color: Color(0xFFFFB340)),
                trailing: _buildFieldCamera(
                  c,
                  busy: _recognizing && _recognizingRoom == room.roomNo,
                  onTap: () => _captureRoomElec(room),
                ),
              ),
              const SizedBox(width: 8),
              // 水表：💧 前缀
              _buildReadingField(
                c,
                wc,
                const Color(0xFF2A7BFF),
                prefix: const Icon(Icons.water_drop_rounded,
                    size: 15, color: Color(0xFF2A7BFF)),
              ),
              const Spacer(),
              // 合计 + 收缴状态（只读；收缴动作在房间编辑页）
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  MiuixText(
                    '¥${calc.totalFee}',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: calc.totalFee > 0
                        ? c.primary
                        : c.onSurfaceVariantSummary,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        dueNow
                            ? Icons.radio_button_unchecked_rounded
                            : accumulating
                                ? Icons.schedule_rounded
                                : Icons.check_circle_rounded,
                        size: 11,
                        color: dueNow
                            ? c.error
                            : accumulating
                                ? const Color(0xFFFF9500)
                                : c.primary,
                      ),
                      const SizedBox(width: 3),
                      MiuixText(
                        dueNow ? '待收' : (accumulating ? '累计中' : '已结清'),
                        fontSize: 10,
                        color: dueNow
                            ? c.error
                            : accumulating
                                ? const Color(0xFFFF9500)
                                : c.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (elecBad || waterBad)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: MiuixText(
                '⚠️ 本期读数小于上期'
                '${elecBad ? '（电上期 ${room.elecPrev}）' : ''}'
                '${waterBad ? '${elecBad ? ' ' : ''}（水上期 ${room.waterPrev}）' : ''}'
                '，已按 0 计算，请检查是否录错',
                fontSize: 10,
                color: c.error,
              ),
            ),
        ],
      ),
    );
  }

  /// 紧凑读数输入框：图标前缀 + 居中数字 +（可选）行内操作
  Widget _buildReadingField(
    MiuixColors c,
    TextEditingController ctrl,
    Color accent, {
    Widget? prefix,
    Widget? trailing,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (prefix != null) ...<Widget>[
            prefix,
            const SizedBox(width: 4),
          ],
          SizedBox(
            width: 44,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.onSurface,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 4),
            trailing,
          ],
        ],
      ),
    );
  }

  /// 输入框行内相机（单房间拍照识别）
  Widget _buildFieldCamera(
    MiuixColors c, {
    required bool busy,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF3482FF),
              ),
            )
          : const Icon(Icons.photo_camera_rounded,
              size: 19, color: Color(0xFF3482FF)),
    );
  }
}

//===================== 整层录水表：批量输入表单 ======================

/// 每间房一行：房号 + 上期 + 输入框（预填当前值，留空不覆盖）。
class _WaterFloorSheet extends StatefulWidget {
  const _WaterFloorSheet({
    super.key,
    required this.rooms,
    required this.prefill,
    required this.onConfirm,
  });

  final List<Room> rooms;
  final Map<String, String> prefill;
  final void Function(Map<String, String>) onConfirm;

  @override
  State<_WaterFloorSheet> createState() => _WaterFloorSheetState();
}

class _WaterFloorSheetState extends State<_WaterFloorSheet> {
  late final Map<String, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = <String, TextEditingController>{
      for (final Room r in widget.rooms)
        r.roomNo: TextEditingController(text: widget.prefill[r.roomNo] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MiuixColors c = MiuixTheme.of(context).colors;
    return Padding(
      // 底部避让悬浮玻璃导航条，保证确认按钮不被遮挡
      padding: const EdgeInsets.only(bottom: kGlassNavClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MiuixText(
            '按水表表盘数字填写本层各房间本期读数，留空表示暂不录入：',
          fontSize: 12,
          height: 1.5,
          color: c.onSurfaceVariantSummary,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            children: <Widget>[
              for (final Room r in widget.rooms)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 52,
                        child: MiuixText(r.roomNo,
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.water_drop_rounded,
                          size: 15, color: Color(0xFF2A7BFF)),
                      const SizedBox(width: 6),
                      StatusTag('上期 ${r.waterPrev}',
                          color: c.onSurfaceVariantSummary),
                      const Spacer(),
                      Container(
                        width: 96,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A7BFF).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2A7BFF)
                                  .withValues(alpha: 0.16)),
                        ),
                        child: TextField(
                          controller: _ctrls[r.roomNo],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.onSurface,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            hintText: '吨',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GradientButton(
          label: '填入本层输入框',
          icon: Icons.download_rounded,
          onPressed: () {
            final Map<String, String> out = <String, String>{};
            for (final MapEntry<String, TextEditingController> e
                in _ctrls.entries) {
              final String v = e.value.text.trim();
              if (v.isNotEmpty) out[e.key] = v;
            }
            widget.onConfirm(out);
          },
        ),
        ],
      ),
    );
  }
}
