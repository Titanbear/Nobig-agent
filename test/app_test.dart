import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/app.dart';
import 'package:nobig_agent/app_controller.dart';
import 'package:nobig_agent/data/settings_store.dart';
import 'package:nobig_agent/domain/models.dart';

void main() {
  testWidgets('changing PC address clears credentials for the previous PC', (
    tester,
  ) async {
    final store = MemorySettingsStore();
    await store.saveConnection(
      const ConnectionProfile(name: 'PC A', baseUrl: 'https://a.example.com'),
      'token-for-a',
    );
    final controller = AppController(store);
    await controller.initialize();
    await tester.pumpWidget(NobigApp(controller: controller));
    await tester.tap(find.text('电脑'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      'token-for-a',
    );
    await tester.enterText(fields.at(1), 'https://b.example.com');
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      isEmpty,
    );
    await tester.enterText(
      fields.at(1),
      'https://b.example.com/?token=token-for-b',
    );
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      'token-for-b',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  testWidgets('native phone flow: configure tab, demo chat, send and stop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final controller = AppController(MemorySettingsStore());
    await controller.initialize();
    await tester.pumpWidget(NobigApp(controller: controller));
    expect(find.text('连接我的电脑'), findsOneWidget);
    await tester.tap(find.text('电脑'));
    await tester.pumpAndSettle();
    expect(find.text('保存并连接'), findsOneWidget);
    await tester.tap(find.text('会话').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('先体验演示'));
    await tester.pumpAndSettle();
    expect(find.textContaining('内容为本地模拟'), findsOneWidget);
    await tester.tap(find.text('你好，Nobig'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-input')), '测试手机客户端');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('send-message')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.chat.running, isTrue);
    expect(find.text('测试手机客户端'), findsOneWidget);
    await tester.tap(find.text('停止'));
    await tester.pumpAndSettle();
    expect(controller.chat.running, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  });

  testWidgets('connection form rejects an invalid URL before calling PC', (
    tester,
  ) async {
    final controller = AppController(MemorySettingsStore());
    await tester.pumpWidget(NobigApp(controller: controller));
    await tester.tap(find.text('电脑'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存并连接'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存并连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入完整'), findsOneWidget);
    expect(controller.connected, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
