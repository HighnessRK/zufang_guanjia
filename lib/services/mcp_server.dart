import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_constants.dart';
import 'mcp_tools.dart';

/// MCP Server —— 把 APP 暴露成一个标准 MCP（Model Context Protocol）服务端，
/// AI 助手（Claude / ChatGPT / 任意 MCP 客户端）连上后即可**全流程**读写本
/// APP：建房、改房、加租户、收房租、收水电费、抄表、改计费设置、看统计、
/// 生成备份，全部与界面操作走同一批仓储层，口径完全一致。
///
/// 【传输层】MCP Streamable HTTP（协议 2025-06-18）
///   * `POST /mcp` 收 JSON-RPC 2.0 单条或批量消息；
///   * `GET  /mcp` 不提供 SSE 长连 → 405（规范允许，客户端回退轮询式 POST）；
///   * `DELETE /mcp` 会话终止 → 204（本服务无状态，直接确认）；
///   * `OPTIONS` 预检与全部响应都带全开 CORS，方便浏览器侧 MCP 客户端；
///   * 端点未识别 → 404。
///
/// 【网络】绑 `0.0.0.0:8765`（[AppConstants.mcpPort]）：本机客户端用
/// 127.0.0.1 直连，同一 WiFi 下的电脑用手机局域网 IP 直连。
///
/// 【并发】每个请求独立处理（`unawaited`），工具执行互不阻塞；sqflite
/// 自身串行化事务，天然安全。
class McpServer {
  McpServer._();

  static final McpServer instance = McpServer._();

  HttpServer? _server;

  /// 服务是否正在运行
  bool get running => _server != null;

  /// 最近一次启动失败原因（端口占用 / 权限等），供设置页展示
  String? lastError;

  /// 本机局域网 IPv4（非回环）。取不到时返回空串。
  String _lanIp = '';

  String get lanIp => _lanIp;

  /// 端点地址（含端口与 /mcp 路径）
  static String _endpoint(String host) =>
      'http://$host:${AppConstants.mcpPort}/mcp';

  /// 本机配置 JSON：AI 客户端在**手机本机**上运行时用回环地址
  String get configLocal => _configJson(_endpoint('127.0.0.1'));

  String get addressLocal => _endpoint('127.0.0.1');
  String get addressLan => _lanIp.isEmpty ? '' : _endpoint(_lanIp);

  /// 局域网配置 JSON：AI 客户端在**同 WiFi 的电脑**上运行时用手机 IP
  String get configLan => _configJson(
      _endpoint(_lanIp.isEmpty ? '192.168.1.1' : _lanIp));

  static String _configJson(String url) =>
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'mcpServers': <String, Object?>{
          'zufang_guanjia': <String, String>{'url': url},
        },
      });

  //========================= 生命周期 =========================

  /// 按配置启停服务（启动流程与设置页开关都会调用）
  Future<void> syncWithConfig() async {
    if (AppConfig.instance.mcpEnabled) {
      await start();
    } else {
      await stop();
    }
  }

  /// 启动服务。幂等：已在运行则直接返回。
  /// 端口被占用等失败只记录 [lastError]，不影响 APP 其它功能。
  Future<void> start() async {
    if (running) return;
    lastError = null;
    try {
      _lanIp = await _findLanIp();
      final HttpServer server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        AppConstants.mcpPort,
        shared: true,
      );
      _server = server;
      server.listen(
        (HttpRequest request) {
          unawaited(_handle(request));
        },
        onError: (Object _) {
          // 单个连接异常不影响服务（多为客户端中途断开）
        },
        cancelOnError: false,
      );
      debugPrint(
          'MCP Server 已启动：0.0.0.0:${AppConstants.mcpPort}（LAN $_lanIp）');
    } on SocketException catch (e) {
      lastError = e.osError?.message ?? e.message;
      _server = null;
      debugPrint('MCP Server 启动失败：$lastError');
    } catch (e) {
      lastError = '$e';
      _server = null;
      debugPrint('MCP Server 启动失败：$lastError');
    }
  }

  /// 停止服务（幂等）
  Future<void> stop() async {
    final HttpServer? server = _server;
    _server = null;
    if (server == null) return;
    try {
      await server.close(force: true);
    } catch (_) {
      // 关闭失败无需上报：端口随进程结束自然释放
    }
    debugPrint('MCP Server 已停止');
  }

  /// 取本机局域网 IPv4：优先私网段（10. / 172.16-31. / 192.168.），
  /// 其次任意非回环 v4。
  Future<String> _findLanIp() async {
    try {
      final List<NetworkInterface> list =
          await NetworkInterface.list(includeLinkLocal: false);
      String fallback = '';
      for (final NetworkInterface ni in list) {
        for (final InternetAddress a in ni.addresses) {
          if (a.type != InternetAddressType.IPv4) continue;
          if (a.isLoopback) continue;
          final String ip = a.address;
          if (ip.startsWith('10.') ||
              ip.startsWith('192.168.') ||
              (ip.startsWith('172.') && _is172Private(ip))) {
            return ip;
          }
          fallback = fallback.isEmpty ? ip : fallback;
        }
      }
      return fallback;
    } catch (_) {
      return '';
    }
  }

  static bool _is172Private(String ip) {
    final List<String> parts = ip.split('.');
    if (parts.length < 2) return false;
    final int? second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  //========================= 请求处理 =========================

  Future<void> _handle(HttpRequest req) async {
    final HttpResponse res = req.response;
    // 是否已写出正文：状态码一旦落地就不能再改，用标志位守卫错误分支
    bool responded = false;
    try {
      _applyCors(req, res);

      if (req.method == 'OPTIONS') {
        res.statusCode = HttpStatus.noContent;
        responded = true;
        return;
      }

      final String path = req.uri.path;
      if (path != '/mcp' && path != '/mcp/') {
        // 附带简短首页说明，方便浏览器验证端口通不通
        res.statusCode = path == '/' ? HttpStatus.ok : HttpStatus.notFound;
        res.headers.contentType = ContentType.text;
        res.write(path == '/'
            ? '租房管家 MCP Server 运行中。请把 MCP 客户端指向 POST /mcp'
            : 'Not Found');
        responded = true;
        return;
      }

      switch (req.method) {
        case 'GET':
          // 未提供 SSE 长连：按规范返回 405，客户端会回退为 POST
          res.statusCode = HttpStatus.methodNotAllowed;
          res.headers.set(HttpHeaders.allowHeader, 'POST, DELETE, OPTIONS');
          res.write('Method Not Allowed');
          responded = true;
          return;
        case 'DELETE':
          // 会话终止：本服务无状态，直接确认
          res.statusCode = HttpStatus.noContent;
          responded = true;
          return;
        case 'POST':
          final String body = await utf8.decoder.bind(req).join();
          responded = await _handlePost(res, body);
          return;        default:
          res.statusCode = HttpStatus.methodNotAllowed;
          res.headers.set(HttpHeaders.allowHeader, 'POST, OPTIONS');
          res.write('Method Not Allowed');
          responded = true;
      }
    } catch (e) {
      debugPrint('MCP 请求处理异常：$e');
      try {
        if (!responded) {
          res.statusCode = HttpStatus.internalServerError;
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode(<String, Object?>{
            'jsonrpc': '2.0',
            'id': null,
            'error': <String, Object?>{
              'code': -32603,
              'message': 'Internal error',
            },
          }));
        }
      } catch (_) {
        // 连接已断开，忽略
      }
    } finally {
      try {
        await res.close();
      } catch (_) {
        // 关闭失败（连接已被对端丢弃）忽略
      }
    }
  }

  /// 处理 POST 正文，返回是否已写出响应
  Future<bool> _handlePost(HttpResponse res, String body) async {
    final Object? decoded = _tryDecode(body);

    // 批量（JSON-RPC 数组）：逐条处理，通知不产生响应
    if (decoded is List<dynamic>) {
      final List<Object?> out = <Object?>[];
      for (final Object? m in decoded) {
        if (m is! Map<String, dynamic>) {
          out.add(_parseError());
          continue;
        }
        final Object? r = await _dispatch(m);
        if (r != null) out.add(r);
      }
      if (out.isEmpty) {
        // 全是通知 → 202 无正文
        res.statusCode = HttpStatus.accepted;
        return true;
      }
      _sendJson(res, jsonEncode(out));
      return true;
    }

    if (decoded is! Map<String, dynamic>) {
      _sendJson(res, jsonEncode(_parseError()));
      return true;
    }

    final Object? result = await _dispatch(decoded);
    if (result == null) {
      // 纯通知（initialize / initialized 等无 id 消息）→ 202 无正文
      res.statusCode = HttpStatus.accepted;
      return true;
    }
    _sendJson(res, jsonEncode(result));
    return true;
  }

  static Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _parseError() => _jsonRpc(<String, Object?>{
        'jsonrpc': '2.0',
        'id': null,
        'error': <String, Object?>{'code': -32700, 'message': 'Parse error'},
      });

  //========================= JSON-RPC 分发 =========================

  /// 处理一条 JSON-RPC 消息；返回 null 表示这是通知（无需响应体）。
  Future<Object?> _dispatch(Map<String, dynamic> msg) async {
    final Object? rawId = msg['id'];
    final String? method = msg['method'] is String ? msg['method'] as String : null;

    if (method == null) {
      return _error(rawId, -32600, 'Invalid Request');
    }

    // ---- 通知 ----
    if (rawId == null) {
      // initialized / cancelled / progress 等：语义上已知悉即可
      return null;
    }

    final Object? params = msg['params'];

    switch (method) {
      case 'initialize':
        return _ok(rawId, _initialize(params));

      case 'ping':
        return _ok(rawId, <String, Object?>{});

      case 'tools/list':
        return _ok(rawId, <String, Object?>{'tools': McpTools.toolSchemas()});

      case 'tools/call':
        return _toolsCall(rawId, params);

      default:
        return _error(rawId, -32601, 'Method not found: $method');
    }
  }

  /// initialize 响应：回显客户端请求的协议版本（我们只支持一个版本，
  /// 客户端没给或给别的版本时用本地常量），并声明工具能力。
  Map<String, Object?> _initialize(Object? params) {
    String version = AppConstants.mcpProtocolVersion;
    if (params is Map<String, dynamic> &&
        params['protocolVersion'] is String) {
      version = params['protocolVersion'] as String;
    }
    return <String, Object?>{
      'protocolVersion': version,
      'capabilities': <String, Object?>{
        'tools': <String, Object?>{'listChanged': false},
      },
      'serverInfo': <String, Object?>{
        'name': AppConstants.mcpServerName,
        'version': AppConstants.appVersion,
      },
      'instructions':
          '我是「租房管家」的 MCP 服务端。你可以用 tools/list 查看全部工具，'
          '覆盖房间、租户、收款、抄表、应用设置与备份的增删改查。'
          '所有写操作会立即同步到 APP 界面。涉及删除、收大额款项时请先与用户确认。',
    };
  }

  /// tools/call：参数错误 → 协议错误；工具执行失败 → isError 结果
  /// （按 MCP 规范，执行类错误要让模型"看见"并自行决定怎么补救）。
  Future<Object?> _toolsCall(Object? id, Object? params) async {
    if (params is! Map<String, dynamic> || params['name'] is! String) {
      return _error(id, -32602, 'Invalid params：缺少工具名 name');
    }
    final String name = params['name'] as String;
    final McpTool? tool = McpTools.lookup(name);
    if (tool == null) {
      return _error(id, -32602, '未知工具：$name');
    }

    final Object? rawArgs = params['arguments'];
    final Map<String, dynamic> args = rawArgs is Map<String, dynamic>
        ? rawArgs
        : <String, dynamic>{};

    try {
      final Object? result = await tool.handler(args);
      return _ok(id, <String, Object?>{
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': McpTools.encode(result)},
        ],
        'isError': false,
      });
    } catch (e) {
      String msg = '$e';
      // Exception('xxx') → 'Exception: xxx'，去掉前缀让模型读起来更干净
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring('Exception: '.length);
      }
      return _ok(id, <String, Object?>{
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': '错误：$msg'},
        ],
        'isError': true,
      });
    }
  }

  static Map<String, Object?> _ok(Object? id, Object? result) =>
      _jsonRpc(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });

  static Map<String, Object?> _error(Object? id, int code, String message) =>
      _jsonRpc(<String, Object?>{
        'jsonrpc': '2.0',
        'id': id,
        'error': <String, Object?>{'code': code, 'message': message},
      });

  static Map<String, Object?> _jsonRpc(Map<String, Object?> m) => m;

  //========================= 响应辅助 =========================

  void _sendJson(HttpResponse res, String body) {
    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType.json;
    // 规范要求 POST 响应带协议版本头（无会话时服务端自报）
    res.headers.set('MCP-Protocol-Version', AppConstants.mcpProtocolVersion);
    res.write(body);
  }

  /// 全开 CORS：内网页内的 MCP 客户端（浏览器扩展 / Web 控制台）可直连
  void _applyCors(HttpRequest req, HttpResponse res) {
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
    res.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, Accept, X-Requested-With, '
      'MCP-Protocol-Version, MCP-Session-Id, mcp-session-id',
    );
    res.headers.set('Access-Control-Max-Age', '86400');
  }
}
