import 'dart:convert';

class ConnectionProfile {
  const ConnectionProfile({required this.name, required this.baseUrl});
  final String name;
  final String baseUrl;

  Uri endpoint(String path) =>
      Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');
  Map<String, String> toJson() => {'name': name, 'baseUrl': baseUrl};
  String encode() => jsonEncode(toJson());
}

class ConnectionDraft {
  const ConnectionDraft(this.profile, this.token);
  final ConnectionProfile profile;
  final String token;

  factory ConnectionDraft.parse({
    required String name,
    required String address,
    required String token,
  }) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.host.contains(RegExp(r'\s')) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('请输入完整的 http:// 或 https:// 服务地址，不要包含用户名和密码。');
    }
    if (uri.scheme == 'http' && !_localHost(uri.host)) {
      throw const FormatException('公网服务请使用 HTTPS 地址；局域网和本机可以使用 HTTP。');
    }
    final supplied = token.trim();
    final extracted =
        uri.queryParameters['token'] ??
        uri.queryParameters['access_token'] ??
        (uri.fragment.startsWith('token=')
            ? Uri.decodeComponent(uri.fragment.substring(6))
            : '');
    final clean = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    return ConnectionDraft(
      ConnectionProfile(
        name: name.trim().isEmpty ? '我的电脑' : name.trim(),
        baseUrl: clean.toString(),
      ),
      extracted.isNotEmpty ? extracted : supplied,
    );
  }

  static bool _localHost(String host) {
    if (host == 'localhost' || host == '::1' || host.endsWith('.local')) {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    return parts[0] == 127 ||
        parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
        (parts[0] == 100 && parts[1]! >= 64 && parts[1]! <= 127);
  }
}

class AgentSession {
  const AgentSession({
    required this.id,
    required this.title,
    this.cwd = '',
    this.running = false,
    this.updatedAt = 0,
  });
  final String id;
  final String title;
  final String cwd;
  final bool running;
  final int updatedAt;

  factory AgentSession.fromDsh(Map<String, dynamic> json) {
    final values = (json['projections'] as Map?)?['values'] as Map? ?? {};
    return AgentSession(
      id: json['sessionId']?.toString() ?? '',
      title: (values['title'] ?? json['title'] ?? '新会话').toString(),
      cwd: json['cwd']?.toString() ?? '',
      running: json['running'] == true,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

enum MessageRole { user, assistant, tool, system }

class AgentMessage {
  const AgentMessage({
    required this.id,
    required this.role,
    required this.text,
  });
  final String id;
  final MessageRole role;
  final String text;
}

class AgentSnapshot {
  const AgentSnapshot({this.messages = const [], this.running = false});
  final List<AgentMessage> messages;
  final bool running;
}

class AgentException implements Exception {
  const AgentException(this.message);
  final String message;
  @override
  String toString() => message;
}
