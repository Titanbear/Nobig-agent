import '../domain/models.dart';

abstract interface class AgentGateway {
  Future<void> connect(ConnectionProfile profile, String token);
  Future<List<AgentSession>> listSessions();
  Future<String> createSession({String cwd = ''});
  Stream<AgentSnapshot> watchSession(String sessionId);
  Future<void> sendMessage(String sessionId, String text, String requestId);
  Future<void> cancel(String sessionId);
  Future<void> close();
}
