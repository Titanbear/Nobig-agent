import 'dart:async';
import 'package:flutter/material.dart';
import 'data/agent_gateway.dart';
import 'data/demo_gateway.dart';
import 'data/dsh_gateway.dart';
import 'data/settings_store.dart';
import 'domain/models.dart';

class AppController extends ChangeNotifier {
  AppController(this.store, {AgentGateway Function()? gatewayFactory})
    : _gatewayFactory = gatewayFactory ?? DshGateway.new;
  final SettingsStore store;
  final AgentGateway Function() _gatewayFactory;
  AgentGateway? _gateway;
  StreamSubscription<AgentSnapshot>? _watch;
  Timer? _reconnect;
  int _generation = 0;
  int _watchGeneration = 0;
  bool _disposed = false;
  String _token = '';

  ConnectionProfile? profile;
  ThemeMode themeMode = ThemeMode.system;
  bool connecting = false;
  bool connected = false;
  bool demo = false;
  bool loadingSessions = false;
  bool loadingChat = false;
  bool sending = false;
  bool stopping = false;
  String? error;
  String? streamError;
  String? activeSessionId;
  List<AgentSession> sessions = [];
  AgentSnapshot chat = const AgentSnapshot();
  String get savedToken => _token;
  String get connectionLabel => demo
      ? '本地演示'
      : connected
      ? '已连接电脑'
      : connecting
      ? '正在连接'
      : '未连接电脑';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final settings = await store.load();
      profile = settings.profile;
      _token = settings.token;
      themeMode = settings.themeMode;
    } catch (_) {
      error = '无法读取本机配置，请重新填写电脑连接信息。';
    }
    _notify();
  }

  Future<void> connect(ConnectionDraft draft) async {
    if (connecting) return;
    await _activate(_gatewayFactory(), draft: draft);
  }

  Future<void> enterDemo() async {
    if (connecting) return;
    await _activate(DemoGateway(), isDemo: true);
  }

  Future<void> _activate(
    AgentGateway gateway, {
    ConnectionDraft? draft,
    bool isDemo = false,
  }) async {
    final generation = ++_generation;
    connecting = true;
    connected = false;
    demo = false;
    error = null;
    sessions = [];
    loadingSessions = false;
    sending = false;
    stopping = false;
    _notify();
    await _releaseGateway();
    if (_disposed || generation != _generation) {
      await gateway.close();
      return;
    }
    _gateway = gateway;
    try {
      if (draft != null) {
        await store.saveConnection(draft.profile, draft.token);
        profile = draft.profile;
        _token = draft.token;
        await gateway.connect(draft.profile, draft.token);
      }
      final items = await gateway.listSessions();
      if (_disposed || generation != _generation) return;
      sessions = items;
      connected = true;
      demo = isDemo;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = _message(e);
      await gateway.close();
      _gateway = null;
    } finally {
      if (generation == _generation) {
        connecting = false;
        _notify();
      }
    }
  }

  Future<void> refreshSessions() async {
    final gateway = _gateway;
    if (gateway == null || !connected || loadingSessions) return;
    final generation = _generation;
    loadingSessions = true;
    error = null;
    _notify();
    try {
      final items = await gateway.listSessions();
      if (generation == _generation) sessions = items;
    } catch (e) {
      if (generation == _generation) error = _message(e);
    } finally {
      if (generation == _generation) {
        loadingSessions = false;
        _notify();
      }
    }
  }

  Future<AgentSession?> createSession({String cwd = ''}) async {
    final gateway = _gateway;
    if (gateway == null || !connected) return null;
    final generation = _generation;
    error = null;
    try {
      final id = await gateway.createSession(cwd: cwd);
      if (generation != _generation || _disposed) return null;
      final session = AgentSession(id: id, title: '新的对话', cwd: cwd);
      sessions = [session, ...sessions.where((s) => s.id != id)];
      _notify();
      return session;
    } catch (e) {
      if (generation == _generation) {
        error = _message(e);
        _notify();
      }
      return null;
    }
  }

  void openSession(String sessionId) {
    leaveSession();
    activeSessionId = sessionId;
    chat = const AgentSnapshot();
    loadingChat = true;
    streamError = null;
    error = null;
    _subscribe();
  }

  void _subscribe() {
    final id = activeSessionId;
    final gateway = _gateway;
    if (id == null || gateway == null || _disposed) return;
    final watchGeneration = ++_watchGeneration;
    _reconnect?.cancel();
    unawaited(_watch?.cancel());
    _watch = gateway
        .watchSession(id)
        .listen(
          (snapshot) {
            if (watchGeneration != _watchGeneration || _disposed) return;
            chat = snapshot;
            loadingChat = false;
            streamError = null;
            _notify();
          },
          onError: (Object e) {
            if (watchGeneration != _watchGeneration || _disposed) return;
            loadingChat = false;
            streamError = _message(e);
            _notify();
            _reconnect = Timer(const Duration(seconds: 3), () {
              if (watchGeneration == _watchGeneration && !_disposed) {
                _subscribe();
              }
            });
          },
        );
    _notify();
  }

  void retryChat() {
    if (activeSessionId != null) {
      loadingChat = true;
      _subscribe();
    }
  }

  void leaveSession() {
    ++_watchGeneration;
    _reconnect?.cancel();
    _reconnect = null;
    unawaited(_watch?.cancel());
    _watch = null;
    activeSessionId = null;
  }

  Future<bool> sendMessage(String text) async {
    final gateway = _gateway;
    final id = activeSessionId;
    if (gateway == null || id == null || text.trim().isEmpty || sending) {
      return false;
    }
    final generation = _generation;
    sending = true;
    error = null;
    _notify();
    try {
      await gateway.sendMessage(id, text.trim(), DshGateway.requestId());
      return generation == _generation;
    } catch (e) {
      if (generation == _generation) error = _message(e);
      return false;
    } finally {
      if (generation == _generation) {
        sending = false;
        _notify();
      }
    }
  }

  Future<void> stopTask() async {
    final gateway = _gateway;
    final id = activeSessionId;
    if (gateway == null || id == null || stopping) return;
    final generation = _generation;
    stopping = true;
    error = null;
    _notify();
    try {
      await gateway.cancel(id);
    } catch (e) {
      if (generation == _generation) error = _message(e);
    } finally {
      if (generation == _generation) {
        stopping = false;
        _notify();
      }
    }
  }

  void pause() {
    ++_watchGeneration;
    _reconnect?.cancel();
    unawaited(_watch?.cancel());
    _watch = null;
  }

  void resume() {
    if (activeSessionId != null) {
      _subscribe();
    } else {
      unawaited(refreshSessions());
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    connected = false;
    connecting = false;
    demo = false;
    loadingSessions = false;
    loadingChat = false;
    sending = false;
    stopping = false;
    sessions = [];
    chat = const AgentSnapshot();
    error = null;
    streamError = null;
    await _releaseGateway();
    _notify();
  }

  Future<void> forgetConnection() async {
    await disconnect();
    try {
      await store.clearConnection();
      profile = null;
      _token = '';
    } catch (_) {
      error = '清除配置失败，请重试。';
    }
    _notify();
  }

  Future<void> setTheme(ThemeMode mode) async {
    try {
      await store.saveTheme(mode);
      themeMode = mode;
    } catch (_) {
      error = '外观设置保存失败，请重试。';
    }
    _notify();
  }

  Future<void> _releaseGateway() async {
    leaveSession();
    final old = _gateway;
    _gateway = null;
    await old?.close();
  }

  static String _message(Object error) =>
      error is AgentException ? error.message : '操作未完成，请检查网络后重试。';

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    leaveSession();
    unawaited(_gateway?.close());
    _gateway = null;
    super.dispose();
  }
}
