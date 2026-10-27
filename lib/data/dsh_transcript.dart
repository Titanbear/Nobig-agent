import 'dart:collection';
import '../domain/models.dart';

/// Reduces the public DSH follow protocol; no UI or network dependencies.
class DshTranscript {
  final _events = SplayTreeMap<int, Map<String, dynamic>>();
  final _interruptedText = <int, String>{};
  String _liveText = '';
  bool _streamRunning = false;

  void accept(Map<String, dynamic> frame) {
    switch (frame['type']) {
      case 'snapshot':
        _events.clear();
        _interruptedText.clear();
        _liveText = '';
        _streamRunning = false;
        for (final raw in (frame['records'] as List? ?? [])) {
          if (raw is Map) _record(raw);
        }
        final attempt =
            (frame['assistantStream'] as Map?)?['activeAttempt'] as Map?;
        if (attempt != null) {
          _streamRunning = true;
          for (final raw in (attempt['stream'] as List? ?? [])) {
            if (raw is Map) _chunkFrame(raw);
          }
        }
      case 'event':
        final raw = frame['event'];
        if (raw is Map) {
          final event = raw['event'] is Map ? raw['event'] as Map : raw;
          final seq = ((event['seq'] ?? raw['seq']) as num?)?.toInt();
          if (seq != null && _events.containsKey(seq)) return;
          _record(event);
          if (event['type'] == 'assistant/message') _liveText = '';
          if (event['type'] == 'turn/end') {
            if (seq != null && _liveText.isNotEmpty) {
              _interruptedText[seq] = _liveText;
            }
            _liveText = '';
            _streamRunning = false;
          }
          if (event['type'] == 'user/message') _liveText = '';
        }
      case 'assistant-stream':
        final chunk = frame['frame'];
        if (chunk is Map) _chunkFrame(chunk);
    }
  }

  void _record(Map raw) {
    final event = raw['event'] is Map ? raw['event'] as Map : raw;
    final seq = (event['seq'] ?? raw['seq']) as num?;
    if (seq != null) _events[seq.toInt()] = Map<String, dynamic>.from(event);
  }

  void _chunkFrame(Map frame) {
    if (frame['type'] == 'end' &&
        (frame['outcome'] as Map?)?['kind'] == 'abandoned') {
      _liveText = '';
      _streamRunning = false;
      return;
    }
    final chunk = frame['chunk'];
    if (chunk is Map && chunk['type'] == 'text-delta') {
      _liveText += (chunk['text'] ?? chunk['delta'] ?? '').toString();
      _streamRunning = true;
    } else if (frame['type'] == 'text-chunks') {
      _liveText += (frame['texts'] as List? ?? []).whereType<String>().join();
      _streamRunning = true;
    }
  }

  AgentSnapshot get snapshot {
    final messages = <AgentMessage>[];
    final ids = <String>{};
    var running = false;
    var pending = '';
    for (final entry in _events.entries) {
      final event = entry.value;
      final data = event['data'] as Map? ?? {};
      final type = event['type'];
      if (type == 'turn/begin' || type == 'turn/start') running = true;
      if (type == 'user/message') {
        final id = '${data['id'] ?? 'user-${entry.key}'}';
        if (ids.add(id)) {
          messages.add(
            AgentMessage(
              id: id,
              role: MessageRole.user,
              text: _text(data['content']),
            ),
          );
        }
        pending = '';
      } else if (type == 'assistant/message') {
        final message = data['message'] as Map? ?? data;
        final id = '${message['id'] ?? 'assistant-${entry.key}'}';
        if (ids.add(id)) {
          messages.add(
            AgentMessage(
              id: id,
              role: MessageRole.assistant,
              text: _text(message['content']),
            ),
          );
        }
        pending = '';
      } else if (type == 'assistant/chunk') {
        final chunk = data['chunk'];
        if (chunk is Map && chunk['type'] == 'text-delta') {
          pending += (chunk['text'] ?? chunk['delta'] ?? '').toString();
          running = true;
        }
      } else if (type == 'tool/call') {
        messages.add(
          AgentMessage(
            id: 'tool-${entry.key}',
            role: MessageRole.tool,
            text: '执行工具：${data['name'] ?? '工具'}',
          ),
        );
      } else if (type == 'turn/end') {
        final interrupted = _interruptedText[entry.key] ?? pending;
        if (interrupted.isNotEmpty) {
          messages.add(
            AgentMessage(
              id: 'partial-${entry.key}',
              role: MessageRole.assistant,
              text: interrupted,
            ),
          );
          pending = '';
        }
        running = false;
        final reason = data['reason'];
        if (reason is Map && reason['kind'] == 'error') {
          messages.add(
            AgentMessage(
              id: 'error-${entry.key}',
              role: MessageRole.system,
              text: '本轮执行失败，请在 PC 端查看详情。',
            ),
          );
        }
      }
    }
    final live = _liveText.isNotEmpty ? _liveText : pending;
    if (live.isNotEmpty) {
      messages.add(
        AgentMessage(id: 'live', role: MessageRole.assistant, text: live),
      );
    }
    return AgentSnapshot(
      messages: List.unmodifiable(messages.where((m) => m.text.isNotEmpty)),
      running: running || _streamRunning,
    );
  }

  static String _text(Object? content) {
    if (content is String) return content;
    if (content is! List) return '';
    return content
        .whereType<Map>()
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'] ?? '')
        .join('\n');
  }
}
