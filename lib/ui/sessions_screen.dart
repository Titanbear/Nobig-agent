import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../domain/models.dart';
import 'chat_screen.dart';
import 'widgets.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({
    super.key,
    required this.controller,
    required this.onConfigure,
  });
  final AppController controller;
  final VoidCallback onConfigure;
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _creating = false;

  void _open(AgentSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatScreen(controller: widget.controller, session: session),
      ),
    );
  }

  Future<void> _create() async {
    if (_creating) return;
    final directory = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新的对话'),
        content: TextField(
          controller: directory,
          decoration: const InputDecoration(
            labelText: 'PC 工作目录（可选）',
            hintText: '留空使用 PC 服务默认目录',
            helperText: '填写电脑上的路径，不是手机目录。',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    final cwd = directory.text;
    // A dialog can still be animating out; disposal is deferred until it closes.
    Future<void>.delayed(const Duration(milliseconds: 350), directory.dispose);
    if (accepted != true || !mounted) return;
    setState(() => _creating = true);
    final session = await widget.controller.createSession(cwd: cwd);
    if (!mounted) return;
    setState(() => _creating = false);
    if (session != null) _open(session);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    final theme = Theme.of(context);
    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: app.refreshSessions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '会话',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        app.connected ? '延续你与 Agent 的每一次协作' : '从手机，连接电脑上的 AI',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (app.connected)
                  IconButton.filled(
                    tooltip: '新建会话',
                    onPressed: _creating ? null : _create,
                    icon: _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (app.error != null) ErrorNotice(app.error!),
            if (!app.connected) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(size: 54),
                    const SizedBox(height: 28),
                    Text(
                      '电脑上的能力，\n随身带着走。',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '在手机上交代任务，\n让你的 PC Agent 接着完成。',
                      style: TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: app.connecting ? null : widget.onConfigure,
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('连接我的电脑'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: app.connecting ? null : app.enterDemo,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('先体验演示'),
              ),
              const SizedBox(height: 18),
              const Text(
                'PC 需要保持运行。手机与电脑可以使用不同网络。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
            ] else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.desktop_windows_rounded),
                  title: Text(app.demo ? '本地演示' : app.profile?.name ?? '我的电脑'),
                  subtitle: Text(
                    app.demo ? '不调用模型，不操作电脑' : 'PC 承载 Agent · 会话在电脑保存',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onConfigure,
                ),
              ),
              const SizedBox(height: 22),
              Text('最近会话', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              if (app.loadingSessions) const LinearProgressIndicator(),
              if (app.sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_outlined, size: 42),
                      const SizedBox(height: 14),
                      const Text('还没有会话'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _creating ? null : _create,
                        child: const Text('开始第一段对话'),
                      ),
                    ],
                  ),
                ),
              for (final session in app.sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: const Icon(Icons.chat_bubble_outline_rounded),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        session.cwd.isEmpty ? '点击继续对话' : session.cwd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: session.running
                          ? const StatusPill('运行中', active: true)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(session),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
