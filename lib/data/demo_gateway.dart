import 'dart:async';
import '../domain/models.dart';
import 'agent_gateway.dart';

class DemoGateway implements AgentGateway {
  final _sessions = <AgentSession>[
    const AgentSession(id: 'welcome', title: '你好，Nobig', cwd: '演示工作区'),
  ];
  final _messages = <String, List<AgentMessage>>{
    'welcome': [
      const AgentMessage(
        id: 'welcome-1',
        role: MessageRole.assistant,
        text:
            '欢迎来到 Nobig Agent。\n\n这是手机端的本地演示，你可以试着发送消息或新建会话。\n\n连接你的电脑后，这里会展示 PC Agent 的真实会话与执行结果。',
      ),
    ],
  };
  final _streams = <String, StreamController<AgentSnapshot>>{};
  final _timers = <String, Timer>{};
  final _requestIds = <String>{};

  @override
  Future<void> connect(ConnectionProfile profile, String token) async {}
  @override
  Future<List<AgentSession>> listSessions() async =>
      List.of(_sessions.reversed);
  @override
  Future<String> createSession({String cwd = ''}) async {
    final id = 'demo-${DateTime.now().microsecondsSinceEpoch}';
    _sessions.add(AgentSession(id: id, title: '新的对话', cwd: '演示工作区'));
    _messages[id] = [];
    return id;
  }

  AgentSnapshot _snapshot(String id) => AgentSnapshot(
    messages: List.unmodifiable(_messages[id] ?? []),
    running: _timers.containsKey(id),
  );
  void _emit(String id) => _streams[id]?.add(_snapshot(id));

  @override
  Stream<AgentSnapshot> watchSession(String sessionId) async* {
    final stream = _streams.putIfAbsent(
      sessionId,
      () => StreamController<AgentSnapshot>.broadcast(),
    );
    yield _snapshot(sessionId);
    yield* stream.stream;
  }

  @override
  Future<void> sendMessage(
    String sessionId,
    String text,
    String requestId,
  ) async {
    if (!_requestIds.add(requestId)) return;
    if (_timers.containsKey(sessionId)) {
      throw const AgentException('请等待演示回复完成。');
    }
    final messages = _messages.putIfAbsent(sessionId, () => []);
    messages.add(
      AgentMessage(id: requestId, role: MessageRole.user, text: text),
    );
    final answer =
        '已收到：“$text”\n\n这是一条本地模拟回复，没有调用模型或操作电脑。\n\n客户端骨架已准备好连接配置、会话列表与聊天入口。你可以前往「电脑」，填写 PC 上的 DSH 服务地址和连接 Token。';
    final replyId = '$requestId-reply';
    messages.add(
      AgentMessage(id: replyId, role: MessageRole.assistant, text: ''),
    );
    var end = 0;
    _timers[sessionId] = Timer.periodic(const Duration(milliseconds: 25), (
      timer,
    ) {
      end = (end + 3).clamp(0, answer.length);
      messages[messages.length - 1] = AgentMessage(
        id: replyId,
        role: MessageRole.assistant,
        text: answer.substring(0, end),
      );
      if (end == answer.length) {
        timer.cancel();
        _timers.remove(sessionId);
      }
      _emit(sessionId);
    });
    _emit(sessionId);
  }

  @override
  Future<void> cancel(String sessionId) async {
    _timers.remove(sessionId)?.cancel();
    _emit(sessionId);
  }

  @override
  Future<void> close() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final stream in _streams.values) {
      await stream.close();
    }
    _streams.clear();
  }
}
