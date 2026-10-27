import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/app_controller.dart';
import 'package:nobig_agent/data/agent_gateway.dart';
import 'package:nobig_agent/data/settings_store.dart';
import 'package:nobig_agent/domain/models.dart';

class DelayedGateway implements AgentGateway {
  final gate = Completer<void>();
  @override
  Future<void> connect(ConnectionProfile profile, String token) => gate.future;
  @override
  Future<List<AgentSession>> listSessions() async => [
    const AgentSession(id: 'old', title: '旧连接'),
  ];
  @override
  Future<String> createSession({String cwd = ''}) async => 'new';
  @override
  Stream<AgentSnapshot> watchSession(String sessionId) => const Stream.empty();
  @override
  Future<void> sendMessage(
    String sessionId,
    String text,
    String requestId,
  ) async {}
  @override
  Future<void> cancel(String sessionId) async {}
  @override
  Future<void> close() async {}
}

class DelayedRefreshGateway extends DelayedGateway {
  final refresh = Completer<List<AgentSession>>();
  int reads = 0;
  @override
  Future<void> connect(ConnectionProfile profile, String token) async {}
  @override
  Future<List<AgentSession>> listSessions() {
    if (++reads == 1) return Future.value([]);
    return refresh.future;
  }
}

void main() {
  test('switching to demo releases the old connection refresh flag', () async {
    final gateway = DelayedRefreshGateway();
    final controller = AppController(
      MemorySettingsStore(),
      gatewayFactory: () => gateway,
    );
    await controller.connect(
      ConnectionDraft.parse(
        name: 'PC',
        address: 'https://agent.example.com',
        token: '',
      ),
    );
    final oldRefresh = controller.refreshSessions();
    expect(controller.loadingSessions, isTrue);
    await controller.enterDemo();
    gateway.refresh.complete([]);
    await oldRefresh;
    expect(controller.loadingSessions, isFalse);
    await controller.refreshSessions();
    expect(controller.sessions.single.id, 'welcome');
    controller.dispose();
  });
  test(
    'a late successful connection cannot undo an explicit disconnect',
    () async {
      final gateway = DelayedGateway();
      final controller = AppController(
        MemorySettingsStore(),
        gatewayFactory: () => gateway,
      );
      final pending = controller.connect(
        ConnectionDraft.parse(
          name: 'PC',
          address: 'https://agent.example.com',
          token: 'test-token',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.disconnect();
      gateway.gate.complete();
      await pending;
      expect(controller.connected, isFalse);
      expect(controller.sessions, isEmpty);
      controller.dispose();
    },
  );
}
