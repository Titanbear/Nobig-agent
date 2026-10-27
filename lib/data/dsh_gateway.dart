import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import '../domain/models.dart';
import 'agent_gateway.dart';
import 'dsh_transcript.dart';

/// Minimal DSH rc.2 adapter. The PC owns the Agent, model keys and files.
class DshGateway implements AgentGateway {
  DshGateway({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final _sockets = <WebSocket>{};
  ConnectionProfile? _profile;
  String _cookie = '';
  bool _closed = false;
  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_cookie.isNotEmpty) 'Cookie': _cookie,
    if (_profile != null) 'Origin': Uri.parse(_profile!.baseUrl).origin,
  };

  static String requestId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();

  @override
  Future<void> connect(ConnectionProfile profile, String token) async {
    _profile = profile;
    if (token.isNotEmpty) {
      try {
        final uri = profile
            .endpoint('')
            .replace(queryParameters: {'token': token});
        final request = http.Request('GET', uri)..followRedirects = false;
        final response = await _client.send(request).timeout(_timeout);
        final raw = response.headers['set-cookie'] ?? '';
        await response.stream.drain<void>();
        if (response.statusCode != 303 || raw.isEmpty) {
          throw const AgentException('身份验证失败，请重新复制 PC 服务当前的连接 Token。');
        }
        _cookie = RegExp(
          r'(?:^|,\s*)([^\s=;,]+)=([^;]*)',
        ).allMatches(raw).map((m) => '${m[1]}=${m[2]}').join('; ');
        if (_cookie.isEmpty) throw const AgentException('服务没有返回有效的登录凭据。');
      } on AgentException {
        rethrow;
      } catch (_) {
        throw const AgentException('无法完成身份验证，请检查地址、网络和 PC 服务。');
      }
    }
    await listSessions();
  }

  Future<dynamic> _rpc(String method, Map<String, dynamic> args) async {
    final profile = _profile;
    if (_closed || profile == null) {
      throw const AgentException('连接已关闭，请重新连接电脑。');
    }
    try {
      // Mutating RPCs are intentionally never retried automatically.
      final response = await _client
          .post(
            profile.endpoint('api/$method'),
            headers: _headers,
            body: jsonEncode({
              'type': 'client-request',
              'rpcId': requestId(),
              'method': method,
              'payload': {'args': args},
            }),
          )
          .timeout(_timeout);
      if (response.statusCode == 401) {
        throw const AgentException('登录已失效，请使用 PC 当前的 Token 重新连接。');
      }
      if (response.statusCode == 403) {
        throw const AgentException('服务拒绝访问，请检查 DSH 的远程访问及反向代理配置。');
      }
      if (response.statusCode != 200) {
        throw AgentException('服务返回 HTTP ${response.statusCode}，请检查地址和 DSH 版本。');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final result = body is Map ? body['result'] : null;
      if (result is! Map || result['ok'] is! bool) {
        throw const AgentException('这个地址没有返回兼容的 DSH 接口，请检查是否停在代理登录页。');
      }
      if (result['ok'] != true) {
        throw const AgentException('PC 拒绝了本次操作，请在 PC 端检查工作目录、模型和权限配置。');
      }
      return result['value'];
    } on AgentException {
      rethrow;
    } on FormatException {
      throw const AgentException('服务响应不是 DSH 数据，请检查是否填写了正确的服务地址。');
    } catch (_) {
      throw const AgentException('未能确认请求结果，请检查 PC 和网络；发送操作不会自动重试。');
    }
  }

  @override
  Future<List<AgentSession>> listSessions() async {
    final value = await _rpc('session/list', {'_request': <String, dynamic>{}});
    final items = value is List
        ? value
        : value is Map
        ? value['items']
        : null;
    if (items is! List) throw const AgentException('会话列表格式不兼容，请检查 DSH 版本。');
    return items
        .whereType<Map>()
        .where((item) => item['origin'] != 'subagent')
        .map((item) => AgentSession.fromDsh(Map<String, dynamic>.from(item)))
        .where((session) => session.id.isNotEmpty)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<String> createSession({String cwd = ''}) async {
    final result = await _rpc('session/create', {
      'request': {if (cwd.trim().isNotEmpty) 'cwd': cwd.trim()},
    });
    final id = result is Map ? result['sessionId']?.toString() : null;
    if (id == null || id.isEmpty) throw const AgentException('服务没有返回新会话 ID。');
    return id;
  }

  @override
  Stream<AgentSnapshot> watchSession(String sessionId) async* {
    final profile = _profile;
    if (profile == null || _closed) throw const AgentException('请先连接电脑。');
    final httpUri = profile.endpoint('api/remote.mux');
    final uri = httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
    );
    WebSocket? socket;
    try {
      socket = await WebSocket.connect(
        uri.toString(),
        headers: _headers,
      ).timeout(_timeout);
      if (_closed) return;
      _sockets.add(socket);
      final streamId = requestId();
      final transcript = DshTranscript();
      socket.add(
        jsonEncode({
          'type': 'open',
          'streamId': streamId,
          'endpoint': 'session/follow',
          'payload': {
            'args': {
              'request': {
                'address': {'kind': 'session', 'sessionId': sessionId},
                'assistantStream': true,
              },
            },
          },
        }),
      );
      await for (final raw in socket) {
        if (raw is! String) continue;
        final envelope = jsonDecode(raw);
        if (envelope is! Map || envelope['streamId'] != streamId) continue;
        if (envelope['type'] == 'error') {
          throw const AgentException('会话实时订阅被拒绝，请检查 DSH 版本和访问权限。');
        }
        if (envelope['type'] != 'item') {
          throw const AgentException('会话订阅已结束，正在重新连接。');
        }
        if (envelope['type'] == 'item' && envelope['value'] is Map) {
          transcript.accept(
            Map<String, dynamic>.from(envelope['value'] as Map),
          );
          yield transcript.snapshot;
        }
      }
      if (!_closed) throw const AgentException('实时连接已断开，正在尝试重新订阅。');
    } on AgentException {
      rethrow;
    } catch (_) {
      if (!_closed) throw const AgentException('实时连接不可用，请确认公网入口支持 WebSocket。');
    } finally {
      if (socket != null) {
        _sockets.remove(socket);
        await socket.close();
      }
    }
  }

  @override
  Future<void> sendMessage(
    String sessionId,
    String text,
    String requestId,
  ) async {
    await _rpc('session/prompt', {
      'request': {
        'requestId': requestId,
        'sessionId': sessionId,
        'mode': 'queue',
        'content': [
          {'type': 'text', 'text': text},
        ],
      },
    });
  }

  @override
  Future<void> cancel(String sessionId) async {
    await _rpc('session/cancel', {
      'request': {'sessionId': sessionId},
    });
  }

  @override
  Future<void> close() async {
    _closed = true;
    _cookie = '';
    _client.close();
    for (final socket in List<WebSocket>.of(_sockets)) {
      await socket.close();
    }
    _sockets.clear();
  }
}
