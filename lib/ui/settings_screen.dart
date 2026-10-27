import 'package:flutter/material.dart';
import '../app_controller.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.onDemo,
  });
  final AppController controller;
  final VoidCallback onDemo;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '设置',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(size: 54),
                  const SizedBox(height: 18),
                  Text(
                    'Nobig Agent',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('你的 PC Agent，随身协作。'),
                  const SizedBox(height: 14),
                  const StatusPill('客户端骨架 · v0.1.0'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('外观', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemeMode>(
            initialValue: controller.themeMode,
            decoration: const InputDecoration(
              labelText: '主题',
              prefixIcon: Icon(Icons.palette_outlined),
            ),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
            ],
            onChanged: (value) {
              if (value != null) controller.setTheme(value);
            },
          ),
          const SizedBox(height: 24),
          Text('体验与说明', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('体验本地演示'),
              subtitle: const Text('模拟聊天，不调用模型或操作电脑'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: controller.connecting ? null : onDemo,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '会话与任务保存在 PC，手机提供远程交互。\n\n连接 Token 使用系统安全存储。模型 API Key 在 PC 配置。\n\n当前支持文本聊天和基础工具状态。附件、完整工具日志与通知将在后续版本加入。',
                style: TextStyle(fontSize: 13, height: 1.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
