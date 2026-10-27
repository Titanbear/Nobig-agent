import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/domain/models.dart';

void main() {
  test('new pasted launch link replaces any token left in the form', () {
    final draft = ConnectionDraft.parse(
      name: 'PC B',
      address: 'https://b.example.com/?token=token-for-b',
      token: 'old-token-for-a',
    );
    expect(draft.token, 'token-for-b');
  });
  test(
    'pasted DSH token is extracted and never appears in stored metadata',
    () {
      final draft = ConnectionDraft.parse(
        name: '我的电脑',
        address: 'https://agent.example.com/app/?token=test-secret',
        token: '',
      );
      expect(draft.token, 'test-secret');
      expect(draft.profile.baseUrl, 'https://agent.example.com/app');
      expect(draft.profile.toJson().toString(), isNot(contains('test-secret')));
      expect(
        draft.profile.endpoint('api/session/list').path,
        '/app/api/session/list',
      );
    },
  );

  test(
    'public HTTP and embedded passwords are rejected, local HTTP is allowed',
    () {
      for (final url in [
        'http://agent.example.com',
        'https://user:pass@example.com',
      ]) {
        expect(
          () => ConnectionDraft.parse(name: 'PC', address: url, token: ''),
          throwsFormatException,
        );
      }
      final local = ConnectionDraft.parse(
        name: 'PC',
        address: 'http://127.0.0.1:3080/',
        token: '',
      );
      expect(local.profile.baseUrl, 'http://127.0.0.1:3080');
    },
  );

  test(
    'invalid addresses do not become apparently valid PC configurations',
    () {
      for (final url in ['', 'not a url', 'ftp://example.com', 'https://']) {
        expect(
          () => ConnectionDraft.parse(name: 'PC', address: url, token: ''),
          throwsFormatException,
        );
      }
    },
  );
}
