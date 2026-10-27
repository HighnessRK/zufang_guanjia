import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../core/config/app_config.dart';
import '../data/db/database_helper.dart';
import 'backup_service.dart';
import 'data_bus.dart';
import 'feishu_api.dart';
import 'notification_service.dart';
import 'sync_merge.dart';

/// Row snapshots are editable in Bitable. Existing unrelated rows are untouched.
/// The baseline is device-private and deliberately excluded from shared backups.
class FeishuSyncService with WidgetsBindingObserver {
  FeishuSyncService._();
  static final instance = FeishuSyncService._();
  final status = ValueNotifier<String>('未同步');
  static const tables = ['rooms', 'people', 'payments', 'receipts'];
  static const prefix = 'rental-v1/';
  bool _busy = false;
  bool _foreground = true;
  Timer? _timer;
  FeishuApi? _api;
  String _identity = '';
  Timer? _debounce;
  String get _root {
    final c = AppConfig.instance;
    return '/bitable/v1/apps/${Uri.encodeComponent(c.feishuAppToken)}/tables/${Uri.encodeComponent(c.feishuTableId)}';
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    DataBus.instance.addListener(_schedule);
    AppConfig.instance.addListener(_schedule);
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground && AppConfig.instance.feishuEnabled) {
        sync().catchError((Object _) {});
      }
    });
  }

  void _schedule() {
    _debounce?.cancel();
    if (!_busy && _foreground && AppConfig.instance.feishuEnabled) {
      _debounce = Timer(const Duration(seconds: 3), () => sync().catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && AppConfig.instance.feishuEnabled) {
      sync().catchError((Object _) {});
    }
  }

  Future<File> _baseline() async => File('${AppConfig.instance.configPath}.feishu-baseline');

  Future<Map<String, String>> _local() async {
    final db = await DatabaseHelper.instance.database;
    final result = <String, String>{};
    await db.transaction((txn) async {
      for (final table in tables) {
        for (final row in await txn.query(table)) {
          result['$table/${row[table == 'rooms' ? 'room_no' : 'id']}'] = canonicalJson(row);
        }
      }
    });
    final path = AppConfig.instance.configPath;
    if (path != null) {
      for (final line in await File(path).readAsLines()) {
        final i = line.indexOf('=');
        if (i <= 0 || line.trimLeft().startsWith('#')) continue;
        result['config/${line.substring(0, i).trim()}'] = canonicalJson(line.substring(i + 1));
      }
    }
    return result;
  }

  String _text(Object? value) {
    if (value is String) return value;
    if (value is List) return value.map((e) => e is Map ? e['text'] ?? '' : '').join();
    throw StateError('飞书同步字段类型不正确');
  }

  Future<({Map<String, String> values, Map<String, String> ids})> _remote() async {
    final values = <String, String>{}, ids = <String, String>{};
    for (final record in await _api!.list('$_root/records')) {
      final fields = record['fields'] as Map<String, dynamic>;
      if (fields['rental_key'] == null) continue;
      final key = _text(fields['rental_key']);
      if (!key.startsWith(prefix)) continue;
      final short = key.substring(prefix.length);
      if (!RegExp(r'^(rooms|people|payments|receipts|config)/[^\r\n]+$').hasMatch(short)) {
        throw StateError('飞书同步键格式不合法，已停止同步');
      }
      if (ids.containsKey(short)) throw StateError('飞书存在重复同步键，已停止同步');
      final value = canonicalJson(jsonDecode(_text(fields['rental_json'])));
      values[short] = value;
      ids[short] = record['record_id'] as String;
    }
    return (values: values, ids: ids);
  }

  Future<void> _schema() async {
    final fields = await _api!.list('$_root/fields');
    for (final name in ['rental_key', 'rental_json']) {
      final existing = fields.where((f) => f['field_name'] == name);
      if (existing.isEmpty) {
        await _api!.request('$_root/fields', method: 'POST', body: {'field_name': name, 'type': 1});
      } else if (existing.first['type'] != 1) {
        throw StateError('$name 必须是多行文本字段');
      }
    }
  }

  Future<void> sync({bool initialize = false, bool download = false}) async {
    if (_busy) throw StateError('同步进行中，请稍候');
    final cfg = AppConfig.instance;
    if ([cfg.feishuAppToken, cfg.feishuTableId, cfg.feishuClientId, cfg.feishuClientSecret].any((e) => e.trim().isEmpty)) {
      throw StateError('请先填写完整飞书参数');
    }
    _busy = true;
    status.value = '同步中…';
    try {
      final identity = canonicalJson([cfg.feishuAppToken, cfg.feishuTableId, cfg.feishuClientId, cfg.feishuClientSecret]);
      if (_identity != identity) {
        _api = FeishuApi(cfg.feishuClientId, cfg.feishuClientSecret);
        _identity = identity;
      }
      await _schema();
      final remote = await _remote();
      final local = await _local();
      final file = await _baseline();
      Map<String, String> base = {};
      bool hasBase = false;
      if (await file.exists()) {
        final saved = jsonDecode(await file.readAsString()) as Map;
        if (saved['target'] == '${cfg.feishuAppToken}/${cfg.feishuTableId}') {
          base = Map<String, String>.from(saved['values'] as Map);
          hasBase = true;
        }
      }
      if (!hasBase) {
        if (!download && (!initialize || remote.values.isNotEmpty)) {
          throw StateError('此设备尚未建立同步基线。首次上传仅允许空同步表；已有远端数据请使用“从飞书初始化缓存”');
        }
        if (await BackupService.instance.createBackupFile() == null) throw StateError('同步前备份失败');
      }
      if (download && remote.values.isEmpty) throw StateError('飞书同步表为空，不能清空本地缓存');
      if (download && await BackupService.instance.createBackupFile() == null) throw StateError('下载前备份失败');
      final merged = download ? remote.values : mergeSync(base, local, remote.values);
      await _validate(merged);
      // Do not overwrite typing or changes made while fetching the remote state.
      if (_editing ||
          canonicalJson(await _local()) != canonicalJson(local)) {
        throw StateError('本地正在编辑或已发生变化，本轮同步取消，稍后重试');
      }
      final check = await _remote();
      if (canonicalJson(check.values) != canonicalJson(remote.values)) throw StateError('飞书数据已变化，请重试');
      // Save the old baseline before starting remote writes. If the network
      // fails after some rows, the same three-way merge can safely retry.
      if (!hasBase && !download) {
        await file.writeAsString(jsonEncode({'target': '${cfg.feishuAppToken}/${cfg.feishuTableId}', 'values': base}), flush: true);
      }
      for (final key in {...remote.values.keys, ...merged.keys}) {
        if (remote.values[key] == merged[key]) continue;
        final id = remote.ids[key];
        if (!merged.containsKey(key)) {
          await _api!.request('$_root/records/$id', method: 'DELETE');
        } else {
          final body = {'fields': {'rental_key': '$prefix$key', 'rental_json': merged[key]}};
          await _api!.request(id == null ? '$_root/records' : '$_root/records/$id',
              method: id == null ? 'POST' : 'PUT', body: body);
        }
      }
      final verified = await _remote();
      if (canonicalJson(verified.values) != canonicalJson(merged)) throw StateError('远端回读不一致，已停止更新本地');
      if (canonicalJson(await _local()) != canonicalJson(local)) throw StateError('上传期间本地有新修改，已保留本地，下一轮重新核对');
      if (canonicalJson(merged) != canonicalJson(local)) {
        if (await BackupService.instance.createBackupFile() == null) throw StateError('更新缓存前备份失败');
        await _apply(merged, local);
      }
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(jsonEncode({'target': '${cfg.feishuAppToken}/${cfg.feishuTableId}', 'values': merged}), flush: true);
      await temporary.rename(file.path);
      status.value = '同步成功 · ${DateTime.now().toLocal().toString().substring(0, 19)}';
    } catch (e) {
      status.value = e is StateError ? e.message : e.toString();
      rethrow;
    } finally {
      _busy = false;
    }
  }

  bool get _editing {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && (context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  Future<void> _validate(Map<String, String> values) async {
    final db = await DatabaseHelper.instance.database;
    final columns = <String, Set<String>>{};
    for (final table in tables) {
      columns[table] = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((r) => r['name'] as String).toSet();
    }
    final rooms = <String>{};
    final configKeys = <String>{};
    for (final entry in values.entries) {
      final slash = entry.key.indexOf('/');
      if (slash <= 0) throw StateError('无效同步键');
      final type = entry.key.substring(0, slash), id = entry.key.substring(slash + 1);
      final value = jsonDecode(entry.value);
      if (type == 'config') {
        if (!RegExp(r'^[a-z_]+$').hasMatch(id) || value is! String ||
            value.contains('\n') || value.contains('\r')) {
          throw StateError('无效配置记录');
        }
        configKeys.add(id);
        continue;
      }
      if (!tables.contains(type) || value is! Map ||
          !value.keys.every(columns[type]!.contains)) {
        throw StateError('飞书记录字段与当前数据库不匹配');
      }
      final pk = type == 'rooms' ? 'room_no' : 'id';
      if ('${value[pk]}' != id || (type != 'rooms' && value['id'] is! int)) throw StateError('不能更改同步记录主键');
      if (type == 'rooms') rooms.add(id);
    }
    if (!configKeys.containsAll(['water_price', 'elec_price', 'feishu_app_token', 'feishu_table_id'])) {
      throw StateError('同步配置不完整，拒绝覆盖');
    }
    for (final entry in values.entries.where((e) => !e.key.startsWith('config/') && !e.key.startsWith('rooms/'))) {
      if (!rooms.contains((jsonDecode(entry.value) as Map)['room_no'])) throw StateError('飞书记录引用不存在的房间');
    }
  }

  Future<void> _apply(Map<String, String> values, Map<String, String> expected) async {
    final db = await DatabaseHelper.instance.database;
    // Validate all JSON before touching the cache. SQLite enforces columns/FKs.
    final rows = {for (final table in tables) table: <Map<String, Object?>>[]};
    for (final entry in values.entries) {
      final type = entry.key.split('/').first;
      if (rows.containsKey(type)) rows[type]!.add(Map<String, Object?>.from(jsonDecode(entry.value) as Map));
    }
    final config = StringBuffer();
    for (final entry in values.entries.where((e) => e.key.startsWith('config/'))) {
      final value = jsonDecode(entry.value);
      if (value is! String || value.contains('\n') || value.contains('\r')) throw StateError('飞书配置格式不合法');
      config.writeln('${entry.key.substring(7)}=$value');
    }
    if (config.isEmpty) throw StateError('飞书配置缺失，取消更新缓存');
    final path = AppConfig.instance.configPath!;
    final oldConfig = await File(path).readAsString();
    final temp = File('$path.sync.tmp');
    await temp.writeAsString(config.toString(), flush: true);
    try {
      await db.transaction((txn) async {
        if (_editing) throw StateError('正在编辑，取消缓存更新');
        final current = <String, String>{};
        for (final table in tables) {
          for (final row in await txn.query(table)) {
            current['$table/${row[table == 'rooms' ? 'room_no' : 'id']}'] = canonicalJson(row);
          }
        }
        final expectedDb = Map<String, String>.fromEntries(expected.entries.where((e) => !e.key.startsWith('config/')));
        if (canonicalJson(current) != canonicalJson(expectedDb)) throw StateError('本地已发生变化，取消覆盖');
      for (final table in tables.reversed) { await txn.delete(table); }
      for (final table in tables) {
        for (final row in rows[table]!) { await txn.insert(table, row); }
      }
        await temp.rename(path);
      });
    } catch (_) {
      await File(path).writeAsString(oldConfig, flush: true);
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    await AppConfig.instance.load();
    DataBus.instance.notify();
    await NotificationService.instance.refresh();
  }
}
