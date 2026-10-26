import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite 数据库帮助类：负责建库、建表、升级、备份路径管理。
///
/// 【四张表】rooms / people / payments / receipts（v1.1.3 起）
///   rooms     房间信息表（核心）
///   people    租户信息表（核心）
///   payments  缴费流水表（支撑缴费统计 / 历史账单 / 欠费累计）
class DatabaseHelper {
  DatabaseHelper._();

  /// 全局单例
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// 数据库完整文件路径（备份 / 恢复使用）
  String? dbFilePath;

  /// 获取已打开的数据库（未打开则自动打开）
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// 打开数据库并完成初始化
  Future<Database> _open() async {
    final String dir = await getDatabasesPath();
    final String path = p.join(dir, AppConstants.dbName);
    dbFilePath = path;

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (Database db) async {
        // 开启外键约束，保证 people.room_no 与 rooms.room_no 关联有效
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// 首次建库：创建三张表
  Future<void> _onCreate(Database db, int version) async {
    // 1) 房间信息表
    await db.execute('''
      CREATE TABLE ${AppConstants.tableRooms} (
        room_no      TEXT    PRIMARY KEY,  -- 房间号
        floor        TEXT    NOT NULL DEFAULT '', -- 自定义楼层（一楼/店面；空=按房号推导）
        rent         INTEGER NOT NULL DEFAULT 0, -- 租金
        paid         INTEGER NOT NULL DEFAULT 0, -- 实付
        room_type    TEXT    DEFAULT '',   -- 房型
        tenant       TEXT    DEFAULT '',   -- 承租人
        id_card      TEXT    DEFAULT '',   -- 身份证
        check_in     TEXT,                 -- 入住日期
        expire       TEXT,                 -- 到期日期
        elec_prev    INTEGER NOT NULL DEFAULT 0, -- 上期电表
        elec_curr    INTEGER NOT NULL DEFAULT 0, -- 本期电表
        water_prev   INTEGER NOT NULL DEFAULT 0, -- 上期水表
        water_curr   INTEGER NOT NULL DEFAULT 0, -- 本期水表
        water_fee    INTEGER NOT NULL DEFAULT 0, -- 水费
        elec_fee     INTEGER NOT NULL DEFAULT 0, -- 电费
        utility_fee  INTEGER NOT NULL DEFAULT 0, -- 水电费
        utility_paid INTEGER NOT NULL DEFAULT 0, -- 水电收缴
        card_count   INTEGER NOT NULL DEFAULT 0, -- 小豆豆（一楼大门磁卡）
        key_count    INTEGER NOT NULL DEFAULT 0, -- 钥匙
        deposit      INTEGER NOT NULL DEFAULT 0, -- 押金
        ac           INTEGER NOT NULL DEFAULT 0, -- 空调
        heater       INTEGER NOT NULL DEFAULT 0, -- 热水器
        fridge       INTEGER NOT NULL DEFAULT 0, -- 冰箱
        washer       INTEGER NOT NULL DEFAULT 0  -- 洗衣机
      )
    ''');

    // 2) 租户信息表（一个房间可有多位租户，is_primary 标记主租户）
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePeople} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        room_no    TEXT NOT NULL,
        name       TEXT NOT NULL,   -- 姓名
        phone      TEXT NOT NULL,   -- 电话
        id_card    TEXT NOT NULL DEFAULT '', -- 身份证（跟随租户本人，选填）
        is_primary INTEGER NOT NULL DEFAULT 0, -- 1 = 主租户（同步 rooms.tenant）
        FOREIGN KEY (room_no) REFERENCES ${AppConstants.tableRooms} (room_no)
          ON DELETE CASCADE
      )
    ''');

    // 3) 缴费流水表（房间号 + 费用类型 + 账期 唯一）
    await db.execute('''
      CREATE TABLE ${AppConstants.tablePayments} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        room_no    TEXT    NOT NULL,
        pay_type   TEXT    NOT NULL,             -- rent / utility
        period     TEXT    NOT NULL,             -- 账期 yyyy-MM
        due        INTEGER NOT NULL DEFAULT 0,   -- 应收
        paid       INTEGER NOT NULL DEFAULT 0,   -- 实收
        is_settled INTEGER NOT NULL DEFAULT 0,   -- 是否结清
        pay_time   TEXT,                         -- 缴费时间
        remark     TEXT    DEFAULT '',
        UNIQUE (room_no, pay_type, period)
      )
    ''');

    // 4) 电子收据表（v1.1.3）：房间号 + 账期 唯一，房间删除级联清理
    await _createReceipts(db);

    // 常用查询索引
    await db.execute(
        'CREATE INDEX idx_payments_period ON ${AppConstants.tablePayments} (period)');
    await db.execute(
        'CREATE INDEX idx_payments_room ON ${AppConstants.tablePayments} (room_no)');
    await db.execute(
        'CREATE INDEX idx_people_room ON ${AppConstants.tablePeople} (room_no)');
  }

  /// 电子收据表 + 索引（新装 [_onCreate] 与老用户升级 [_onUpgrade] 共用）
  Future<void> _createReceipts(Database db) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableReceipts} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        room_no    TEXT    NOT NULL,
        period     TEXT    NOT NULL,              -- 账期 yyyy-MM
        no         TEXT    NOT NULL DEFAULT '',   -- 收据编号
        tenant     TEXT    NOT NULL DEFAULT '',   -- 租户快照
        water_fee  INTEGER NOT NULL DEFAULT 0,    -- 水费（元）
        elec_fee   INTEGER NOT NULL DEFAULT 0,    -- 电费（元）
        total      INTEGER NOT NULL DEFAULT 0,    -- 合计（元）
        water_use  INTEGER,                       -- 用量快照（吨，可空）
        elec_use   INTEGER,                       -- 用量快照（度，可空）
        water_price REAL,                         -- 水价快照（元/吨）
        elec_price REAL,                          -- 电价快照（元/度）
        note       TEXT    NOT NULL DEFAULT '',
        created_at TEXT    NOT NULL,              -- 生成时间 yyyy-MM-dd HH:mm
        UNIQUE (room_no, period),
        FOREIGN KEY (room_no) REFERENCES ${AppConstants.tableRooms} (room_no)
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_receipts_created ON ${AppConstants.tableReceipts} (created_at)');
  }

  /// 版本升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2：people 表增加「主租户」标记，并回填老数据
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE ${AppConstants.tablePeople} '
          'ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0');
      // 回填：老数据只有 rooms.tenant 单承租人 —— 为每个有承租人且还没有
      // 租户记录的房间补一条主租户；已有租户记录但无主的房间，把最早一条
      // 升为主租户，保证升级后 rooms.tenant 与 people 表口径一致
      final List<Map<String, Object?>> rooms = await db.query(
        AppConstants.tableRooms,
        columns: <String>['room_no', 'tenant'],
      );
      for (final Map<String, Object?> r in rooms) {
        final String roomNo = r['room_no'] as String;
        final String tenant = (r['tenant'] ?? '') as String;
        final List<Map<String, Object?>> people = await db.query(
          AppConstants.tablePeople,
          where: 'room_no = ?',
          whereArgs: <Object?>[roomNo],
          orderBy: 'id ASC',
        );
        if (people.isEmpty) {
          if (tenant.isNotEmpty) {
            await db.insert(AppConstants.tablePeople, <String, Object?>{
              'room_no': roomNo,
              'name': tenant,
              'phone': '',
              'is_primary': 1,
            });
          }
        } else if (!people.any((Map<String, Object?> p) =>
            ((p['is_primary'] ?? 0) as int) == 1)) {
          await db.update(
            AppConstants.tablePeople,
            <String, Object?>{'is_primary': 1},
            where: 'id = ?',
            whereArgs: <Object?>[people.first['id']],
          );
        }
      }
    }

    // v2 → v3：身份证跟随租户 —— people 表增加 id_card，把房间上的
    // rooms.id_card 结转到该房间主租户名下（一级界面不再展示身份证）
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE ${AppConstants.tablePeople} '
          "ADD COLUMN id_card TEXT NOT NULL DEFAULT ''");
      final List<Map<String, Object?>> rooms = await db.query(
        AppConstants.tableRooms,
        columns: <String>['room_no', 'id_card'],
      );
      for (final Map<String, Object?> r in rooms) {
        final String card = (r['id_card'] ?? '') as String;
        if (card.isEmpty) continue;
        final String roomNo = r['room_no'] as String;
        final List<Map<String, Object?>> people = await db.query(
          AppConstants.tablePeople,
          where: 'room_no = ?',
          whereArgs: <Object?>[roomNo],
          orderBy: 'is_primary DESC, id ASC',
        );
        if (people.isEmpty) continue;
        await db.update(
          AppConstants.tablePeople,
          <String, Object?>{'id_card': card},
          where: 'id = ?',
          whereArgs: <Object?>[people.first['id']],
        );
      }
    }

    // v3 → v4：自定义楼层 —— rooms 表增加 floor。空串表示仍按房号推导
    //（101→1、1203→12），填了自定义值（「一楼」「店面」）则优先按它分组。
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE ${AppConstants.tableRooms} '
          "ADD COLUMN floor TEXT NOT NULL DEFAULT ''");
    }

    // v4 → v5：新增电子收据表（v1.1.3）
    if (oldVersion < 5) {
      await _createReceipts(db);
    }
  }

  /// 关闭数据库（退出 / 恢复备份前调用）
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 备份：返回数据库文件路径，供原生层复制到外部目录
  Future<String> backupPath() async {
    final String dir = await getDatabasesPath();
    return p.join(dir, AppConstants.dbName);
  }

  /// 当前数据库是否已包含某张表（恢复旧备份时的兼容判断）
  Future<bool> tableExists(String tableName) async {
    final Database db = await database;
    final List<Map<String, Object?>> r = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      <Object?>[tableName],
    );
    return r.isNotEmpty;
  }
}
