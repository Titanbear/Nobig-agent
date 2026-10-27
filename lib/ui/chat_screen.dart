import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../domain/models.dart';
import 'widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.controller,
    required this.session,
  });
  final AppController controller;
  final AgentSession session;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.openSession(widget.session.id);
    });
  }

  void _updated() {
    if (!mounted) return;
    final follow = !_scroll.hasClients || _scroll.position.extentAfter < 120;
    setState(() {});
    if (follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updated);
    if (widget.controller.activeSessionId == widget.session.id) {
      widget.controller.leaveSession();
    }
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    final accepted = await widget.controller.sendMessage(text);
    if (mounted && accepted && _text.text == text) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.session.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              app.demo ? '本地演示' : app.profile?.name ?? 'PC Agent',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '刷新会话',
            onPressed: app.retryChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: Column(
            children: [
              if (app.demo) const DemoNotice(),
              if (app.streamError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ErrorNotice(app.streamError!, onRetry: app.retryChat),
                ),
              Expanded(
                child: app.loadingChat
                    ? const Center(child: CircularProgressIndicator())
                    : app.chat.messages.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BrandMark(size: 58),
                              SizedBox(height: 20),
                              Text(
                                '有什么想交给 Agent？',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text('从一个明确的小任务开始。', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: app.chat.messages.length,
                        itemBuilder: (_, index) =>
                            _MessageBubble(message: app.chat.messages[index]),
                      ),
              ),
              if (app.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorNotice(app.error!),
                ),
              if (app.chat.running)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.demo ? '正在生成演示回复' : 'PC Agent 正在执行',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: app.stopping ? null : app.stopTask,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(app.stopping ? '停止中' : '停止'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('chat-input'),
                        controller: _text,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: '给 Agent 发消息…',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('send-message'),
                      tooltip: '发送消息',
                      onPressed:
                          !app.connected ||
                              app.loadingChat ||
                              app.streamError != null ||
                              app.sending ||
                              app.chat.running ||
                              _text.text.trim().isEmpty
                          ? null
                          : _send,
                      padding: const EdgeInsets.all(14),
                      icon: app.sending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final AgentMessage message;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final user = message.role == MessageRole.user;
    final tool = message.role == MessageRole.tool;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 16,
          left: user ? 40 : 0,
          right: user ? 0 : 24,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: user ? colors.primaryContainer : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tool ? Icons.build_outlined : Icons.auto_awesome_rounded,
                    size: 13,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tool ? '工具' : 'Nobig',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(
              message.text,
              style: TextStyle(fontSize: tool ? 13 : 15, height: 1.65),
            ),
          ],
        ),
      ),
    );
  }
}
