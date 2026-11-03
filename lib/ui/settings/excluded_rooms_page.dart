import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import '../../core/config/app_config.dart';
import '../../data/models/room.dart';
import '../../data/repository/room_repository.dart';
import '../../services/data_bus.dart';
import '../../services/notification_service.dart';
import '../widgets/app_widgets.dart';

class ExcludedRoomsPage extends StatefulWidget {
  const ExcludedRoomsPage({super.key});

  @override
  State<ExcludedRoomsPage> createState() => _ExcludedRoomsPageState();
}

class _ExcludedRoomsPageState extends State<ExcludedRoomsPage> {
  late final Future<List<Room>> _rooms = RoomRepository.instance.all();
  bool _saving = false;

  Future<void> _toggle(String room, bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final cfg = AppConfig.instance;
    final previous = Set<String>.from(cfg.excludedRooms);
    try {
      cfg.excludedRooms = {...previous};
      if (enabled) {
        cfg.excludedRooms.add(room);
      } else {
        cfg.excludedRooms.remove(room);
      }
      await cfg.save();
      DataBus.instance.notify();
    } catch (_) {
      cfg.excludedRooms = previous;
      if (mounted) AppSnackbar.show('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    try {
      await NotificationService.instance.refresh();
    } catch (_) {
      if (mounted) AppSnackbar.show('名单已保存，通知刷新失败，请重新打开应用');
    }
  }

  @override
  Widget build(BuildContext context) => AuroraScaffold(
      topBar: MiuixSmallTopAppBar(
          title: '白名单房间',
          color: Colors.transparent,
          navigationIcon: MiuixIconButton(
              onPressed: () => Navigator.pop(context),
              child: const MiuixIcon(icon: Icons.arrow_back_ios_new_rounded))),
      snackbarHost: const AppSnackbarHost(),
      content: (padding) => FutureBuilder<List<Room>>(
            future: _rooms,
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('房间加载失败'));
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rooms = snapshot.data!;
              return ListView(
                  padding: EdgeInsets.fromLTRB(20, padding.top + 8, 20,
                      kGlassNavClearance + padding.bottom),
                  children: [
                    const SectionTitle('选择不计入的房间'),
                    const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('白名单房间的房租和水电费用不计入汇总与报表，也不发送任何提醒；'
                            '房间数量仍计入。历史流水和抄表读数保留，拍照识别照常使用。'
                            '调整名单后，历史报表按当前名单重新统计。')),
                    if (rooms.isEmpty)
                      const EmptyView('暂无房间', icon: Icons.home_outlined)
                    else
                      GlassCard(
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(children: [
                            for (var i = 0; i < rooms.length; i++) ...[
                              if (i > 0) const MiuixHorizontalDivider(),
                              MiuixSwitchPreference(
                                  title: rooms[i].roomNo,
                                  summary: rooms[i].tenant.isEmpty
                                      ? '未填写租户'
                                      : rooms[i].tenant,
                                  value: AppConfig.instance
                                      .isExcludedRoom(rooms[i].roomNo),
                                  onChanged: (value) =>
                                      _toggle(rooms[i].roomNo, value)),
                            ],
                          ])),
                  ]);
            },
          ));
}
