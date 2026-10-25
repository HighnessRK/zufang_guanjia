import 'dart:async';
import 'dart:convert';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/calc_util.dart';
import '../core/utils/date_util.dart';
import '../data/models/payment.dart';
import '../data/models/person.dart';
import '../data/models/room.dart';
import '../data/repository/payment_repository.dart';
import '../data/repository/person_repository.dart';
import '../data/repository/room_repository.dart';
import 'data_bus.dart';
import 'notification_service.dart';

/// MCP 工具定义：AI 助手通过 tools/list 发现、tools/call 调用。
///
/// 【能力边界】覆盖房东日常全流程——查/建/改/删房间与租户、收房租、
/// 收水电费、抄表、改计费与提醒设置、看统计、做备份。所有写操作与
/// APP 内操作走同一批仓储层，口径完全一致，改完广播 [DataBus] 让界面
/// 立即刷新。
class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  /// 工具名（snake_case，AI 靠它调用）
  final String name;

  /// 中文说明：AI 靠它判断什么时候用
  final String description;

  /// JSON Schema（inputSchema）
  final Map<String, Object?> inputSchema;

  /// 执行体：入参为解析后的 arguments，返回可 JSON 序列化结果
  final Future<Object?> Function(Map<String, dynamic> args) handler;
}

/// 能力分组（MCP 设置页的「AI 可用能力」列表）
class McpCapability {
  const McpCapability(this.title, this.summary, this.icon, this.tools);

  final String title;
  final String summary;
  final dynamic icon;
  final List<String> tools;
}

/// 全部 MCP 工具与能力分组。
class McpTools {
  McpTools._();

  static final McpTool byName = McpTool(
    name: 'noop',
    description: '',
    inputSchema: <String, Object?>{},
    handler: (Map<String, dynamic> a) async => null,
  );

  /// 工具注册表：name → 工具
  static final Map<String, McpTool> registry = <String, McpTool>{};

  /// 能力分组（顺序即设置页展示顺序）
  static const List<McpCapability> capabilities = <McpCapability>[
    McpCapability('房间管理', '查询 / 新增 / 修改 / 删除房间', null, <String>[
      'list_rooms',
      'get_room',
      'create_room',
      'update_room',
      'delete_room',
    ]),
    McpCapability('租户管理', '查询 / 添加 / 修改 / 删除租户', null, <String>[
      'list_tenants',
      'add_tenant',
      'update_tenant',
      'delete_tenant',
    ]),
    McpCapability('收款管理', '流水查询 · 收房租 · 收水电费', null, <String>[
      'list_payments',
      'collect_rent',
      'settle_utility',
    ]),
    McpCapability('抄表管理', '读取与修改水电表读数', null, <String>[
      'get_meter',
      'update_meter',
    ]),
    McpCapability('应用设置', '读取与修改计费 / 提醒 / 通知设置', null, <String>[
      'get_settings',
      'update_settings',
    ]),
    McpCapability('数据查询与备份', '经营概览 · 账期统计 · 生成备份', null, <String>[
      'get_overview',
      'get_statistics',
      'create_backup',
    ]),
  ];

  static final List<McpTool> all = <McpTool>[
    //====================== 房间管理 ======================
    McpTool(
      name: 'list_rooms',
      description: '查询全部房间列表，含楼层、租金、承租人、入住状态与待收金额。'
          '可选按楼层过滤（如 "2" 表示 2 层）。',
      inputSchema: _schema(<String, Object?>{
        'floor': _str('楼层号过滤（可选），如 "2" 代表 2 层'),
      }),
      handler: (Map<String, dynamic> a) async {
        final String? floor = _optStr(a['floor']);
        final List<Room> rooms = await RoomRepository.instance.all();
        final Map<String, int> owedUtil =
            await PaymentRepository.instance.unsettledUtilityByRoom();
        final Map<String, int> owedRent =
            await PaymentRepository.instance.unsettledRentByRoom();
        final List<Map<String, Object?>> out = <Map<String, Object?>>[];
        for (final Room r in rooms) {
          if (floor != null && Room.floorOf(r.roomNo) != floor) continue;
          out.add(<String, Object?>{
            'roomNo': r.roomNo,
            'floor': Room.floorOf(r.roomNo),
            'roomType': r.roomType,
            'tenant': r.tenant,
            'occupied': r.isOccupied,
            'rent': r.rent,
            'paid': r.paid,
            'deposit': r.deposit,
            'checkIn': r.checkIn,
            'expire': r.expire,
            'rentOwed': owedRent[r.roomNo] ?? 0,
            'utilityOwed': owedUtil[r.roomNo] ?? 0,
            'utilityFee': r.utilityFee,
            'utilityPaid': r.utilityPaid,
          });
        }
        return <String, Object?>{'total': out.length, 'rooms': out};
      },
    ),
    McpTool(
      name: 'get_room',
      description: '查询单个房间的完整信息：房间资料、全部租户、缴费流水。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号，如 "201"'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');
        final List<Person> people = await PersonRepository.instance.byRoom(roomNo);
        final List<Map<String, Object?>> payments = (await PaymentRepository
                .instance
                .byRoom(roomNo))
            .map((dynamic p) => p.toMap() as Map<String, Object?>)
            .toList();
        return <String, Object?>{
          'room': _roomJson(room),
          'people': people.map(_personJson).toList(),
          'payments': payments,
        };
      },
    ),
    McpTool(
      name: 'create_room',
      description: '新增一个房间。房间号必填且不能已存在；可同时填写租金、'
          '承租人、押金、入住 / 到期日期与初始水电表读数。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填，如 "201"）'),
        'rent': _int('月租金（元）'),
        'paid': _int('本周期已收房租（元）'),
        'roomType': _str('房型，如 "单间" / "一室一厅" / "店面"'),
        'tenant': _str('主租户姓名（填了即视为在租）'),
        'idCard': _str('主租户身份证号'),
        'phone': _str('主租户电话（会一并建立租户档案）'),
        'checkIn': _str('入住日期 yyyy-MM-dd'),
        'expire': _str('到期日期 yyyy-MM-dd'),
        'deposit': _int('押金（元）'),
        'elecPrev': _int('上期电表读数（度）'),
        'waterPrev': _int('上期水表读数（吨）'),
        'keyCount': _int('钥匙数量'),
        'cardCount': _int('大门磁卡（小豆豆）数量'),
        'ac': _int('空调台数'),
        'heater': _int('热水器台数'),
        'fridge': _int('冰箱台数'),
        'washer': _int('洗衣机台数'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        if (await RoomRepository.instance.byRoomNo(roomNo) != null) {
          throw Exception('房间 $roomNo 已存在');
        }
        final Room room = Room(
          roomNo: roomNo,
          rent: _optInt(a['rent']) ?? 0,
          paid: _optInt(a['paid']) ?? 0,
          roomType: _optStr(a['roomType']) ?? '',
          tenant: _optStr(a['tenant']) ?? '',
          idCard: _optStr(a['idCard']) ?? '',
          checkIn: _optStr(a['checkIn']),
          expire: _optStr(a['expire']),
          elecPrev: _optInt(a['elecPrev']) ?? 0,
          elecCurr: _optInt(a['elecPrev']) ?? 0,
          waterPrev: _optInt(a['waterPrev']) ?? 0,
          waterCurr: _optInt(a['waterPrev']) ?? 0,
          deposit: _optInt(a['deposit']) ?? 0,
          keyCount: _optInt(a['keyCount']) ?? 0,
          cardCount: _optInt(a['cardCount']) ?? 0,
          ac: _optInt(a['ac']) ?? 0,
          heater: _optInt(a['heater']) ?? 0,
          fridge: _optInt(a['fridge']) ?? 0,
          washer: _optInt(a['washer']) ?? 0,
        );
        await RoomRepository.instance.insert(room);

        // 填了承租人 → 建主租户档案（与编辑房间页 syncFromRoom 同口径）
        final String tenant = room.tenant.trim();
        if (tenant.isNotEmpty) {
          final String phone = _optStr(a['phone']) ?? '';
          final int id = await PersonRepository.instance.insert(Person(
            roomNo: roomNo,
            name: tenant,
            phone: phone,
            idCard: room.idCard,
            isPrimary: true,
          ));
          await PersonRepository.instance.applyPrimary(id, roomNo, true);
        }
        await _afterMutation('创建房间 $roomNo');
        final Room? fresh = await RoomRepository.instance.byRoomNo(roomNo);
        return <String, Object?>{
          'ok': true,
          'room': fresh == null ? null : _roomJson(fresh),
        };
      },
    ),
    McpTool(
      name: 'update_room',
      description: '修改已有房间的字段。只传需要改的字段，未传的字段保持不变。'
          '修改租金 / 承租人 / 水电读数会自动重算费用与待收流水。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
        'rent': _int('月租金（元）'),
        'paid': _int('本周期已收房租（元）'),
        'roomType': _str('房型'),
        'tenant': _str('主租户姓名（清空表示房间空置）'),
        'idCard': _str('主租户身份证号'),
        'checkIn': _str('入住日期 yyyy-MM-dd'),
        'expire': _str('到期日期 yyyy-MM-dd'),
        'deposit': _int('押金（元）'),
        'elecPrev': _int('上期电表读数（度）'),
        'elecCurr': _int('本期电表读数（度）'),
        'waterPrev': _int('上期水表读数（吨）'),
        'waterCurr': _int('本期水表读数（吨）'),
        'keyCount': _int('钥匙数量'),
        'cardCount': _int('大门磁卡数量'),
        'ac': _int('空调台数'),
        'heater': _int('热水器台数'),
        'fridge': _int('冰箱台数'),
        'washer': _int('洗衣机台数'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');

        _assign(room, 'rent', a['rent']);
        _assign(room, 'paid', a['paid']);
        _assign(room, 'deposit', a['deposit']);
        _assign(room, 'keyCount', a['keyCount']);
        _assign(room, 'cardCount', a['cardCount']);
        _assign(room, 'ac', a['ac']);
        _assign(room, 'heater', a['heater']);
        _assign(room, 'fridge', a['fridge']);
        _assign(room, 'washer', a['washer']);
        _assign(room, 'elecPrev', a['elecPrev']);
        _assign(room, 'elecCurr', a['elecCurr']);
        _assign(room, 'waterPrev', a['waterPrev']);
        _assign(room, 'waterCurr', a['waterCurr']);
        if (a['roomType'] != null) room.roomType = _optStr(a['roomType']) ?? '';
        if (a['idCard'] != null) room.idCard = _optStr(a['idCard']) ?? '';
        if (a['checkIn'] != null) room.checkIn = _optStr(a['checkIn']);
        if (a['expire'] != null) room.expire = _optStr(a['expire']);
        if (a['tenant'] != null) room.tenant = _optStr(a['tenant']) ?? '';

        // 读数变化 → 按当前单价重算周期累计水电费
        final AppConfig cfg = AppConfig.instance;
        final CalcResult r = CalcUtil.compute(
          elecPrev: room.elecPrev,
          elecCurr: room.elecCurr,
          waterPrev: room.waterPrev,
          waterCurr: room.waterCurr,
          elecPrice: cfg.elecPrice,
          waterPrice: cfg.waterPrice,
        );
        room.elecFee = r.elecFee;
        room.waterFee = r.waterFee;
        room.utilityFee = r.totalFee;
        await RoomRepository.instance.update(room);

        // 承租人字段与租户档案对齐（与编辑房间页保存一致）
        await PersonRepository.instance
            .syncFromRoom(roomNo, room.tenant, room.idCard);

        // 房租实收变化 → 同步流水；跑账期引擎生成待收
        await PaymentRepository.instance.syncRent(room);
        final List<Room> fresh = await RoomRepository.instance.all();
        await PaymentRepository.instance.ensureCurrentPeriod(fresh);

        await _afterMutation('修改房间 $roomNo');
        final Room? updated = await RoomRepository.instance.byRoomNo(roomNo);
        return <String, Object?>{
          'ok': true,
          'room': updated == null ? null : _roomJson(updated),
        };
      },
    ),
    McpTool(
      name: 'delete_room',
      description: '删除一个房间，其租户档案与缴费流水一并删除，不可恢复。'
          '请先和用户确认后再调用。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        if (await RoomRepository.instance.byRoomNo(roomNo) == null) {
          throw Exception('房间 $roomNo 不存在');
        }
        await RoomRepository.instance.delete(roomNo);
        await _afterMutation('删除房间 $roomNo');
        return <String, Object?>{'ok': true, 'deleted': roomNo};
      },
    ),

    //====================== 租户管理 ======================
    McpTool(
      name: 'list_tenants',
      description: '查询租户列表。可按房间号过滤，也可按手机号精确查找。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号过滤（可选）'),
        'phone': _str('按手机号精确查找（可选）'),
      }),
      handler: (Map<String, dynamic> a) async {
        final String? roomNo = _optStr(a['roomNo']);
        final String? phone = _optStr(a['phone']);
        final List<Person> list;
        if (phone != null) {
          list = await PersonRepository.instance.searchByPhone(phone);
        } else if (roomNo != null) {
          list = await PersonRepository.instance.byRoom(roomNo);
        } else {
          list = await PersonRepository.instance.all();
        }
        return <String, Object?>{
          'total': list.length,
          'tenants': list.map(_personJson).toList(),
        };
      },
    ),
    McpTool(
      name: 'add_tenant',
      description: '给某房间添加一位租户。设 isPrimary 为 true 时成为主租户'
          '（同步房间的承租人字段，同房间其他租户自动取消主标记）。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
        'name': _str('姓名（必填）'),
        'phone': _str('电话'),
        'idCard': _str('身份证号'),
        'isPrimary': _bool('是否设为主租户'),
      }, required: <String>['roomNo', 'name']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final String name = _reqStr(a, 'name');
        if (await RoomRepository.instance.byRoomNo(roomNo) == null) {
          throw Exception('房间 $roomNo 不存在，请先创建房间');
        }
        final int id = await PersonRepository.instance.insert(Person(
          roomNo: roomNo,
          name: name,
          phone: _optStr(a['phone']) ?? '',
          idCard: _optStr(a['idCard']) ?? '',
          isPrimary: a['isPrimary'] == true,
        ));
        if (a['isPrimary'] == true) {
          await PersonRepository.instance.applyPrimary(id, roomNo, true);
        }
        await _afterMutation('添加租户 $name（$roomNo）');
        return <String, Object?>{'ok': true, 'id': id};
      },
    ),
    McpTool(
      name: 'update_tenant',
      description: '修改一位租户的信息（按租户 id）。设 isPrimary 可切换主租户。',
      inputSchema: _schema(<String, Object?>{
        'id': _int('租户 id（必填，来自 list_tenants）'),
        'name': _str('姓名'),
        'phone': _str('电话'),
        'idCard': _str('身份证号'),
        'isPrimary': _bool('是否设为主租户'),
      }, required: <String>['id']),
      handler: (Map<String, dynamic> a) async {
        final int id = _optInt(a['id']) ?? (throw Exception('缺少 id'));
        final Person? person = await _findPerson(id);
        if (person == null) throw Exception('租户 id=$id 不存在');
        if (a['name'] != null) person.name = _optStr(a['name']) ?? '';
        if (a['phone'] != null) person.phone = _optStr(a['phone']) ?? '';
        if (a['idCard'] != null) person.idCard = _optStr(a['idCard']) ?? '';
        final bool wasPrimary = person.isPrimary;
        if (a['isPrimary'] != null) person.isPrimary = a['isPrimary'] == true;
        await PersonRepository.instance.update(person);
        if (person.isPrimary != wasPrimary) {
          await PersonRepository.instance
              .applyPrimary(id, person.roomNo, person.isPrimary);
        }
        await _afterMutation('修改租户 ${person.name}');
        return <String, Object?>{'ok': true, 'tenant': _personJson(person)};
      },
    ),
    McpTool(
      name: 'delete_tenant',
      description: '删除一位租户（按租户 id）。删除主租户后，同房间最早的一位'
          '租户会自动升为主租户。',
      inputSchema: _schema(<String, Object?>{
        'id': _int('租户 id（必填，来自 list_tenants）'),
      }, required: <String>['id']),
      handler: (Map<String, dynamic> a) async {
        final int id = _optInt(a['id']) ?? (throw Exception('缺少 id'));
        final Person? person = await _findPerson(id);
        if (person == null) throw Exception('租户 id=$id 不存在');
        await PersonRepository.instance.deleteAndReassign(person);
        await _afterMutation('删除租户 ${person.name}');
        return <String, Object?>{'ok': true, 'deleted': id};
      },
    ),

    //====================== 收款管理 ======================
    McpTool(
      name: 'list_payments',
      description: '查询缴费流水。可按房间号 / 费用类型（rent 房租、water 水费、'
          'elec 电费）/ 账期（yyyy-MM）过滤，或只看未结清的。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号过滤（可选）'),
        'payType': _str('费用类型过滤：rent / water / elec / utility（可选）'),
        'period': _str('账期过滤 yyyy-MM（可选）'),
        'unsettledOnly': _bool('只看未结清流水（可选）'),
      }),
      handler: (Map<String, dynamic> a) async {
        final String? roomNo = _optStr(a['roomNo']);
        final String? payType = _optStr(a['payType']);
        final String? period = _optStr(a['period']);
        final List<Payment> list;
        if (roomNo != null) {
          list = await PaymentRepository.instance.byRoom(roomNo);
        } else if (period != null) {
          list = await PaymentRepository.instance.byPeriod(period);
        } else {
          list = await PaymentRepository.instance.all();
        }
        final List<Map<String, Object?>> out = <Map<String, Object?>>[];
        for (final Payment p in list) {
          if (payType != null && p.payType != payType) continue;
          if (a['unsettledOnly'] == true && p.isSettled) continue;
          out.add(<String, Object?>{
            'id': p.id,
            'roomNo': p.roomNo,
            'payType': p.payType,
            'payTypeText': p.payTypeText,
            'period': p.period,
            'due': p.due,
            'paid': p.paid,
            'debt': p.debt,
            'isSettled': p.isSettled,
            'payTime': p.payTime,
            'remark': p.remark,
          });
        }
        return <String, Object?>{'total': out.length, 'payments': out};
      },
    ),
    McpTool(
      name: 'collect_rent',
      description: '收房租：给某房间入账一笔房租收款（增量累加），自动同步'
          '应收流水并在收满时结清。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
        'amount': _int('本次收款金额（元，必填）'),
      }, required: <String>['roomNo', 'amount']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final int amount = _optInt(a['amount']) ?? 0;
        if (amount <= 0) throw Exception('收款金额必须大于 0');
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');
        await PaymentRepository.instance.collectRent(roomNo, amount);
        await _afterMutation('收房租 $roomNo ¥$amount');
        final Room? updated = await RoomRepository.instance.byRoomNo(roomNo);
        return <String, Object?>{
          'ok': true,
          'roomNo': roomNo,
          'amount': amount,
          'paidTotal': updated?.paid,
          'rent': updated?.rent,
        };
      },
    ),
    McpTool(
      name: 'settle_utility',
      description: '收水电费：结清某房间的水费（water）或电费（elec）。'
          '结清后该表读数滚动为本期，下一周期从当前读数重新累计。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
        'payType': _str('费用类型（必填）：water 水费 / elec 电费'),
        'amount': _int('结清金额（元；不传则按当前待收金额结清）'),
      }, required: <String>['roomNo', 'payType']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final String payType = _reqStr(a, 'payType');
        if (payType != AppConstants.payTypeWater &&
            payType != AppConstants.payTypeElec) {
          throw Exception('payType 只能是 water 或 elec');
        }
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');
        final int amount = _optInt(a['amount']) ??
            (payType == AppConstants.payTypeWater
                ? room.waterFee
                : room.elecFee);
        await PaymentRepository.instance.settleUtility(roomNo, payType, amount);
        await _afterMutation('收${payType == 'water' ? '水' : '电'}费 '
            '$roomNo ¥$amount');
        return <String, Object?>{
          'ok': true,
          'roomNo': roomNo,
          'payType': payType,
          'amount': amount,
        };
      },
    ),

    //====================== 抄表管理 ======================
    McpTool(
      name: 'get_meter',
      description: '读取某房间的水电表读数与当前周期累计费用。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');
        final Map<String, int> owed =
            await PaymentRepository.instance.unsettledUtilityByRoom();
        return <String, Object?>{
          'roomNo': roomNo,
          'elecPrev': room.elecPrev,
          'elecCurr': room.elecCurr,
          'waterPrev': room.waterPrev,
          'waterCurr': room.waterCurr,
          'elecFee': room.elecFee,
          'waterFee': room.waterFee,
          'utilityFee': room.utilityFee,
          'utilityPaid': room.utilityPaid,
          'utilityOwed': owed[roomNo] ?? 0,
        };
      },
    ),
    McpTool(
      name: 'update_meter',
      description: '修改某房间的水电表读数并按当前单价自动重算费用、生成待收。'
          '只传需要改的字段；注意本期读数不应小于上期读数。',
      inputSchema: _schema(<String, Object?>{
        'roomNo': _str('房间号（必填）'),
        'elecCurr': _int('本期电表读数（度）'),
        'elecPrev': _int('上期电表读数（度）'),
        'waterCurr': _int('本期水表读数（吨）'),
        'waterPrev': _int('上期水表读数（吨）'),
      }, required: <String>['roomNo']),
      handler: (Map<String, dynamic> a) async {
        final String roomNo = _reqStr(a, 'roomNo');
        final Room? room = await RoomRepository.instance.byRoomNo(roomNo);
        if (room == null) throw Exception('房间 $roomNo 不存在');
        _assign(room, 'elecCurr', a['elecCurr']);
        _assign(room, 'elecPrev', a['elecPrev']);
        _assign(room, 'waterCurr', a['waterCurr']);
        _assign(room, 'waterPrev', a['waterPrev']);
        final AppConfig cfg = AppConfig.instance;
        final CalcResult r = CalcUtil.compute(
          elecPrev: room.elecPrev,
          elecCurr: room.elecCurr,
          waterPrev: room.waterPrev,
          waterCurr: room.waterCurr,
          elecPrice: cfg.elecPrice,
          waterPrice: cfg.waterPrice,
        );
        await RoomRepository.instance.updateMeter(
          roomNo: roomNo,
          elecPrev: room.elecPrev,
          elecCurr: room.elecCurr,
          waterPrev: room.waterPrev,
          waterCurr: room.waterCurr,
          elecFee: r.elecFee,
          waterFee: r.waterFee,
          utilityFee: r.totalFee,
        );
        final List<Room> fresh = await RoomRepository.instance.all();
        await PaymentRepository.instance.ensureCurrentPeriod(fresh);
        await _afterMutation('抄表 $roomNo');
        return <String, Object?>{
          'ok': true,
          'roomNo': roomNo,
          'elecCurr': room.elecCurr,
          'waterCurr': room.waterCurr,
          'elecFee': r.elecFee,
          'waterFee': r.waterFee,
          'utilityFee': r.totalFee,
          'warning': r.hasNegative ? '本期读数小于上期读数，已按 0 计费' : null,
        };
      },
    ),

    //====================== 应用设置 ======================
    McpTool(
      name: 'get_settings',
      description: '读取 APP 的全部计费与提醒设置：水电单价、缴费周期、'
          '收缴日期、提醒天数、通知开关等。',
      inputSchema: _schema(<String, Object?>{}),
      handler: (Map<String, dynamic> a) async {
        final AppConfig c = AppConfig.instance;
        return <String, Object?>{
          'waterPrice': c.waterPrice,
          'elecPrice': c.elecPrice,
          'rentCycle': c.rentCycle,
          'rentCycleLabel': AppConfig.cycleLabel(c.rentCycle),
          'waterCycle': c.waterCycle,
          'elecCycle': c.elecCycle,
          'elecCycleLabel': c.elecCycleLabel,
          'summerStart': c.summerStart,
          'summerEnd': c.summerEnd,
          'waterCollectDate': c.waterCollectDate,
          'elecCollectDate': c.elecCollectDate,
          'remindDays': c.remindDays,
          'expireRemindDays': c.expireRemindDays,
          'notifyEnabled': c.notifyEnabled,
          'focusEnabled': c.focusEnabled,
          'premiumMaterial': c.premiumMaterial,
          'updateSource': c.updateSource,
          'autoCheckUpdate': c.autoCheckUpdate,
          'updateNotify': c.updateNotify,
          'currentPeriod': DateUtil.currentPeriod,
        };
      },
    ),
    McpTool(
      name: 'update_settings',
      description: '修改 APP 设置。只传需要改的字段，未传的保持不变。'
          'rentCycle 可取 1/3/6/12（月/季/半年/年付），waterCycle 可取 '
          '1/3/12，elecCycle 可取 0(智能)/1/3/12。修改后立即写盘生效。',
      inputSchema: _schema(<String, Object?>{
        'waterPrice': _num('水费单价（元/吨）'),
        'elecPrice': _num('电费单价（元/度）'),
        'rentCycle': _int('房租缴费周期（月）：1 / 3 / 6 / 12'),
        'waterCycle': _int('水费缴费周期（月）：1 / 3 / 12'),
        'elecCycle': _int('电费缴费周期（月）：0 智能 / 1 / 3 / 12'),
        'summerStart': _int('智能电费夏季起始月（1-12）'),
        'summerEnd': _int('智能电费夏季结束月（1-12）'),
        'waterCollectDate': _str('统一收水日期 yyyy-MM-dd'),
        'elecCollectDate': _str('统一收电日期 yyyy-MM-dd'),
        'remindDays': _int('缴费提醒提前天数'),
        'expireRemindDays': _int('到期提醒提前天数'),
        'notifyEnabled': _bool('系统通知开关'),
        'focusEnabled': _bool('澎湃OS 焦点通知开关'),
        'premiumMaterial': _bool('高级材质（液态玻璃）开关'),
        'updateSource': _str('更新下载源：gitee / github'),
        'autoCheckUpdate': _bool('启动时自动检查更新'),
        'updateNotify': _bool('发现新版本弹窗提醒'),
      }),
      handler: (Map<String, dynamic> a) async {
        final AppConfig c = AppConfig.instance;
        await c.update(
          waterPrice: _optNum(a['waterPrice'])?.toDouble(),
          elecPrice: _optNum(a['elecPrice'])?.toDouble(),
          rentCycle: _optInt(a['rentCycle']),
          waterCycle: _optInt(a['waterCycle']),
          elecCycle: _optInt(a['elecCycle']),
          summerStart: _optInt(a['summerStart']),
          summerEnd: _optInt(a['summerEnd']),
          waterCollectDate: _optStr(a['waterCollectDate']),
          elecCollectDate: _optStr(a['elecCollectDate']),
          remindDays: _optInt(a['remindDays']),
          expireRemindDays: _optInt(a['expireRemindDays']),
          notifyEnabled: a['notifyEnabled'] == true ? true : null,
          focusEnabled: a['focusEnabled'] == true ? true : null,
          premiumMaterial: a['premiumMaterial'] == true ? true : null,
          updateSource: _optStr(a['updateSource']),
          autoCheckUpdate: a['autoCheckUpdate'] == true ? true : null,
          updateNotify: a['updateNotify'] == true ? true : null,
        );
        // 提醒天数 / 通知开关变化 → 重算三端通知
        unawaited(NotificationService.instance.refresh());
        await _afterMutation('修改应用设置');
        return <String, Object?>{
          'ok': true,
          'settings': _settingsJson(),
        };
      },
    ),

    //====================== 数据查询与备份 ======================
    McpTool(
      name: 'get_overview',
      description: '获取经营概览：房间总数 / 在租数、本月房租应收已收、'
          '水电待收、当前账期与欠费房间数。适合回答"这个月收了多少"之类的问题。',
      inputSchema: _schema(<String, Object?>{}),
      handler: (Map<String, dynamic> a) async {
        final List<Room> rooms = await RoomRepository.instance.all();
        final Map<String, int> owedUtil =
            await PaymentRepository.instance.unsettledUtilityByRoom();
        final Map<String, int> owedRent =
            await PaymentRepository.instance.unsettledRentByRoom();
        int occupied = 0, rentSum = 0, paidSum = 0;
        int utilOwed = 0, rentOwed = 0, owingRooms = 0;
        for (final Room r in rooms) {
          if (r.isOccupied) {
            occupied++;
            rentSum += r.rent;
            paidSum += r.paid;
          }
          final int u = owedUtil[r.roomNo] ?? 0;
          final int rr = owedRent[r.roomNo] ?? 0;
          utilOwed += u;
          rentOwed += rr;
          if (u > 0 || rr > 0) owingRooms++;
        }
        final StatSummary stat =
            await PaymentRepository.instance.statSummary();
        return <String, Object?>{
          'currentPeriod': stat.period,
          'roomTotal': rooms.length,
          'occupied': occupied,
          'vacant': rooms.length - occupied,
          'monthlyRent': rentSum,
          'rentCollected': paidSum,
          'utilityOwed': utilOwed,
          'rentOwed': rentOwed,
          'owingRooms': owingRooms,
          'periodDue': stat.due,
          'periodPaid': stat.paid,
          'periodDebt': stat.debt,
        };
      },
    ),
    McpTool(
      name: 'get_statistics',
      description: '查询某账期（yyyy-MM，缺省为当期）的收缴统计：应收 / 实收 / '
          '欠费 / 结清笔数与结清率。',
      inputSchema: _schema(<String, Object?>{
        'period': _str('账期 yyyy-MM（可选，默认当期）'),
      }),
      handler: (Map<String, dynamic> a) async {
        final StatSummary s = await PaymentRepository.instance
            .statSummary(period: _optStr(a['period']));
        return <String, Object?>{
          'period': s.period,
          'due': s.due,
          'paid': s.paid,
          'debt': s.debt,
          'settledCount': s.settledCount,
          'unsettledCount': s.unsettledCount,
          'settleRate': double.parse(s.settleRate.toStringAsFixed(4)),
        };
      },
    ),
    McpTool(
      name: 'create_backup',
      description: '生成一份数据备份（rental.db + info.gwt 打包为 zip，'
          '存到应用备份目录），返回备份文件路径。不弹分享界面。',
      inputSchema: _schema(<String, Object?>{}),
      handler: (Map<String, dynamic> a) async {
        final Future<String?> Function()? action =
            BackupActions.createBackupFile;
        if (action == null) throw Exception('备份能力尚未初始化');
        final String? path = await action();
        if (path == null) throw Exception('备份失败：备份目录不可写');
        return <String, Object?>{'ok': true, 'path': path};
      },
    ),
  ];

  /// 初始化注册表（首次访问时构建）
  static void _ensureInit() {
    if (registry.isNotEmpty) return;
    for (final McpTool t in all) {
      registry[t.name] = t;
    }
  }

  /// 工具清单（tools/list 响应）
  static List<Map<String, Object?>> toolSchemas() {
    _ensureInit();
    return all
        .map((McpTool t) => <String, Object?>{
              'name': t.name,
              'description': t.description,
              'inputSchema': t.inputSchema,
            })
        .toList();
  }

  /// 按名字取工具
  static McpTool? lookup(String name) {
    _ensureInit();
    return registry[name];
  }

  //========================= 内部工具 =========================

  /// 写操作完成后：广播界面刷新 + 刷新三端通知
  static Future<void> _afterMutation(String what) async {
    DataBus.instance.notify();
    try {
      await NotificationService.instance.refresh();
    } catch (_) {
      // 通知刷新失败不影响数据操作结果
    }
    // what 目前仅用于日志语义，保留参数便于排查
    assert(true, what);
  }

  static Future<Person?> _findPerson(int id) async {
    final List<Person> all = await PersonRepository.instance.all();
    for (final Person p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Map<String, Object?> _settingsJson() {
    final AppConfig c = AppConfig.instance;
    return <String, Object?>{
      'waterPrice': c.waterPrice,
      'elecPrice': c.elecPrice,
      'rentCycle': c.rentCycle,
      'waterCycle': c.waterCycle,
      'elecCycle': c.elecCycle,
      'remindDays': c.remindDays,
      'expireRemindDays': c.expireRemindDays,
      'notifyEnabled': c.notifyEnabled,
      'focusEnabled': c.focusEnabled,
      'premiumMaterial': c.premiumMaterial,
    };
  }

  static Map<String, Object?> _roomJson(Room r) => <String, Object?>{
        'roomNo': r.roomNo,
        'floor': Room.floorOf(r.roomNo),
        'roomType': r.roomType,
        'tenant': r.tenant,
        'idCard': r.idCard,
        'rent': r.rent,
        'paid': r.paid,
        'deposit': r.deposit,
        'checkIn': r.checkIn,
        'expire': r.expire,
        'elecPrev': r.elecPrev,
        'elecCurr': r.elecCurr,
        'waterPrev': r.waterPrev,
        'waterCurr': r.waterCurr,
        'elecFee': r.elecFee,
        'waterFee': r.waterFee,
        'utilityFee': r.utilityFee,
        'utilityPaid': r.utilityPaid,
        'keyCount': r.keyCount,
        'cardCount': r.cardCount,
        'ac': r.ac,
        'heater': r.heater,
        'fridge': r.fridge,
        'washer': r.washer,
        'occupied': r.isOccupied,
      };

  static Map<String, Object?> _personJson(Person p) => <String, Object?>{
        'id': p.id,
        'roomNo': p.roomNo,
        'name': p.name,
        'phone': p.phone,
        'idCard': p.idCard,
        'isPrimary': p.isPrimary,
      };

  /// 只在 args 显式提供字段时赋值（update 语义）
  static void _assign(Room room, String field, Object? v) {
    if (v == null) return;
    final int? n = _optInt(v);
    if (n == null) return;
    switch (field) {
      case 'rent':
        room.rent = n;
      case 'paid':
        room.paid = n;
      case 'deposit':
        room.deposit = n;
      case 'keyCount':
        room.keyCount = n;
      case 'cardCount':
        room.cardCount = n;
      case 'ac':
        room.ac = n;
      case 'heater':
        room.heater = n;
      case 'fridge':
        room.fridge = n;
      case 'washer':
        room.washer = n;
      case 'elecPrev':
        room.elecPrev = n;
      case 'elecCurr':
        room.elecCurr = n;
      case 'waterPrev':
        room.waterPrev = n;
      case 'waterCurr':
        room.waterCurr = n;
    }
  }

  //========================= Schema 助手 =========================

  static Map<String, Object?> _schema(
    Map<String, Object?> props, {
    List<String> required = const <String>[],
  }) =>
      <String, Object?>{
        'type': 'object',
        'properties': props,
        if (required.isNotEmpty) 'required': required,
      };

  static Map<String, Object?> _str(String desc) =>
      <String, Object?>{'type': 'string', 'description': desc};

  static Map<String, Object?> _int(String desc) =>
      <String, Object?>{'type': 'integer', 'description': desc};

  static Map<String, Object?> _num(String desc) =>
      <String, Object?>{'type': 'number', 'description': desc};

  static Map<String, Object?> _bool(String desc) =>
      <String, Object?>{'type': 'boolean', 'description': desc};

  static String _reqStr(Map<String, dynamic> a, String key) {
    final String? v = _optStr(a[key]);
    if (v == null || v.isEmpty) throw Exception('缺少必填参数 $key');
    return v;
  }

  static String? _optStr(Object? v) {
    if (v == null) return null;
    final String s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _optInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString().trim());
  }

  static num? _optNum(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString().trim());
  }

  /// 工具结果统一序列化为 JSON 文本（供 MCP content 返回）
  static String encode(Object? v) => jsonEncode(v);
}

/// 备份动作（供 create_backup 工具调用，实现注入避免循环依赖）。
class BackupActions {
  BackupActions._();

  /// 由 app 启动 / 设置页注入实现（写 zip 到应用备份目录）
  static Future<String?> Function()? createBackupFile;
}
