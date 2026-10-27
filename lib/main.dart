import 'package:flutter/material.dart';
import 'app.dart';
import 'app_controller.dart';
import 'data/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(DeviceSettingsStore());
  await controller.initialize();
  runApp(NobigApp(controller: controller));
}
