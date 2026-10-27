// Optional visual QA: flutter test tool/preview_test.dart
// Outputs are local build artifacts; system fonts are never copied into the app.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nobig_agent/app.dart';
import 'package:nobig_agent/app_controller.dart';
import 'package:nobig_agent/data/settings_store.dart';

void main() {
  testWidgets('capture native mobile skeleton screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fontPath = Platform.environment['NOBIG_PREVIEW_FONT'];
    if (fontPath != null && File(fontPath).existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await loader.load();
    }
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconLoader.load();
    final controller = AppController(MemorySettingsStore());
    await controller.initialize();
    const boundaryKey = Key('preview-boundary');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: NobigApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) => tester
        .runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/previews/$name.png');
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        })
        .then((_) {});
    await capture('sessions');
    await tester.tap(find.text('电脑'));
    await tester.pumpAndSettle();
    await capture('connection');
    await controller.enterDemo();
    await tester.tap(find.text('会话').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('你好，Nobig'));
    await tester.pumpAndSettle();
    await capture('chat');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
