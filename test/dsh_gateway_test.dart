import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/data/dsh_gateway.dart';
import 'package:nobig_agent/domain/models.dart';

void main() {
  test(
    'real HTTP/WS fixture authenticates, follows, sends and cancels one session',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final calls = <String, Map<String, dynamic>>{};
      final sockets = <WebSocket>[];
      final serverErrors = <Object>[];
      final listener = server.listen((request) async {
        try {
          if (request.uri.path == '/') {
            expect(request.uri.queryParameters['token'], 'test-launch-token');
            request.response.statusCode = 303;
            request.response.headers.set(
              'set-cookie',
              'dsh_session=test-cookie; HttpOnly; Path=/',
            );
            request.response.headers.set('location', '/');
            await request.response.close();
            return;
          }
          expect(request.headers.value('cookie'), 'dsh_session=test-cookie');
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            final socket = await WebSocketTransformer.upgrade(request);
            sockets.add(socket);
            socket.listen((raw) {
              final frame = jsonDecode(raw as String) as Map<String, dynamic>;
              if (frame['type'] != 'open') return;
              expect(frame['endpoint'], 'session/follow');
              expect(
                frame['payload']['args']['request']['address']['sessionId'],
                'session-1',
              );
              socket.add(
                jsonEncode({
                  'type': 'item',
                  'streamId': frame['streamId'],
                  'value': {
                    'type': 'snapshot',
                    'records': [
                      {
                        'event': {
                          'seq': 1,
                          'type': 'user/message',
                          'data': {
                            'content': [
                              {'type': 'text', 'text': '来自电脑的历史'},
                            ],
                          },
                        },
                      },
                    ],
                  },
                }),
              );
            });
            return;
          }
          final body =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          expect(body['type'], 'client-request');
          expect(request.uri.path, '/api/${body['method']}');
          calls[body['method'] as String] = body;
          Object value = {};
          if (body['method'] == 'session/list') {
            value = [
              {
                'sessionId': 'session-1',
                'updatedAt': 1000,
                'projections': {
                  'values': {'title': '电脑会话'},
                },
              },
              {'sessionId': 'child-1', 'origin': 'subagent', 'updatedAt': 1},
            ];
          } else if (body['method'] == 'session/create') {
            value = {'sessionId': 'session-new'};
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'result': {'ok': true, 'value': value},
            }),
          );
          await request.response.close();
        } catch (error) {
          serverErrors.add(error);
          await request.response.close();
        }
      });
      final gateway = DshGateway();
      addTearDown(() async {
        await gateway.close();
        for (final socket in sockets) {
          await socket.close();
        }
        await listener.cancel();
        await server.close(force: true);
      });
      final profile = ConnectionDraft.parse(
        name: '测试电脑',
        address: 'http://127.0.0.1:${server.port}',
        token: '',
      ).profile;
      await gateway.connect(profile, 'test-launch-token');
      final sessions = await gateway.listSessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.title, '电脑会话');
      expect(await gateway.createSession(), 'session-new');
      final snapshot = await gateway
          .watchSession('session-1')
          .first
          .timeout(const Duration(seconds: 5));
      expect(snapshot.messages.single.text, '来自电脑的历史');
      await gateway.sendMessage('session-1', '手机指令', 'request-stable');
      expect(
        calls['session/prompt']!['payload']['args']['request'],
        containsPair('requestId', 'request-stable'),
      );
      expect(
        calls['session/prompt']!['payload']['args']['request']['sessionId'],
        'session-1',
      );
      await gateway.cancel('session-1');
      expect(
        calls['session/cancel']!['payload']['args']['request']['sessionId'],
        'session-1',
      );
      expect(serverErrors, isEmpty);
    },
  );

  test(
    'an HTML landing page is never accepted as an Agent connection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.write('<html>Login</html>');
        await request.response.close();
      });
      final gateway = DshGateway();
      addTearDown(() async {
        await gateway.close();
        await server.close(force: true);
      });
      final profile = ConnectionDraft.parse(
        name: 'PC',
        address: 'http://127.0.0.1:${server.port}',
        token: '',
      ).profile;
      await expectLater(
        gateway.connect(profile, ''),
        throwsA(isA<AgentException>()),
      );
    },
  );
}
