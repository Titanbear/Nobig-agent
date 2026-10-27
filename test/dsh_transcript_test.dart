import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/data/dsh_transcript.dart';

Map<String, Object> event(int seq, String type, Map<String, Object> data) => {
  'event': {'seq': seq, 'type': type, 'time': 1000, 'data': data},
};

void main() {
  test('nested final record replaces live text even before turn end', () {
    final transcript = DshTranscript();
    transcript.accept({
      'type': 'assistant-stream',
      'frame': {
        'type': 'chunk',
        'chunk': {'type': 'text-delta', 'text': 'hello'},
      },
    });
    transcript.accept({
      'type': 'event',
      'event': event(4, 'assistant/message', {
        'message': {
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
        },
      }),
    });
    expect(transcript.snapshot.messages, hasLength(1));
  });

  test('an interrupted live reply is retained when the next turn starts', () {
    final transcript = DshTranscript();
    transcript.accept({
      'type': 'assistant-stream',
      'frame': {
        'type': 'chunk',
        'chunk': {'type': 'text-delta', 'text': 'partial'},
      },
    });
    transcript.accept({
      'type': 'event',
      'event': event(5, 'turn/end', {})['event'],
    });
    transcript.accept({
      'type': 'event',
      'event': event(6, 'user/message', {
        'content': [
          {'type': 'text', 'text': 'continue'},
        ],
      })['event'],
    });
    expect(transcript.snapshot.messages.map((m) => m.text), [
      'partial',
      'continue',
    ]);
  });
  test('snapshot and replay of the same event do not duplicate a message', () {
    final transcript = DshTranscript();
    final user = event(1, 'user/message', {
      'id': 'user-1',
      'content': [
        {'type': 'text', 'text': '你好'},
      ],
    });
    transcript.accept({
      'type': 'snapshot',
      'records': [user],
    });
    transcript.accept({'type': 'event', 'event': user['event']});
    expect(transcript.snapshot.messages, hasLength(1));
    expect(transcript.snapshot.messages.single.text, '你好');
  });

  test('streamed text is replaced by the persisted final message', () {
    final transcript = DshTranscript();
    transcript.accept({
      'type': 'assistant-stream',
      'frame': {
        'type': 'chunk',
        'chunk': {'type': 'text-delta', 'text': '你好'},
      },
    });
    expect(transcript.snapshot.messages.single.text, '你好');
    transcript.accept({
      'type': 'event',
      'event': event(2, 'assistant/message', {
        'message': {
          'content': [
            {'type': 'text', 'text': '你好，世界'},
          ],
        },
      })['event'],
    });
    expect(transcript.snapshot.messages, hasLength(1));
    expect(transcript.snapshot.messages.single.text, '你好，世界');
    transcript.accept({
      'type': 'event',
      'event': event(3, 'turn/end', {})['event'],
    });
    expect(transcript.snapshot.running, isFalse);
  });

  test('reasoning deltas are not exposed as assistant answer text', () {
    final transcript = DshTranscript();
    transcript.accept({
      'type': 'assistant-stream',
      'frame': {
        'type': 'chunk',
        'chunk': {'type': 'reasoning-delta', 'text': 'internal'},
      },
    });
    expect(transcript.snapshot.messages, isEmpty);
  });
}
