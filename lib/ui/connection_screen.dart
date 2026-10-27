import 'package:flutter/material.dart';
import '../app_controller.dart';
import '../domain/models.dart';
import 'widgets.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    required this.controller,
    required this.onSessions,
  });
  final AppController controller;
  final VoidCallback onSessions;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _token;
  bool _obscure = true;
  String? _localError;
  String? _credentialScope;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.controller.profile?.name ?? '我的电脑',
    );
    _url = TextEditingController(
      text: widget.controller.profile?.baseUrl ?? '',
    );
    _token = TextEditingController(text: widget.controller.savedToken);
    _credentialScope = widget.controller.profile?.baseUrl;
  }

  void _addressChanged(String value) {
    try {
      final draft = ConnectionDraft.parse(
        name: _name.text,
        address: value,
        token: '',
      );
      if (_credentialScope != draft.profile.baseUrl) _token.clear();
      _credentialScope = draft.profile.baseUrl;
      if (draft.token.isNotEmpty) _token.text = draft.token;
    } on FormatException {
      _token.clear();
      _credentialScope = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    try {
      final draft = ConnectionDraft.parse(
        name: _name.text,
        address: _url.text,
        token: _token.text,
      );
      setState(() => _localError = null);
      _url.text = draft.profile.baseUrl;
      _token.text = draft.token;
      FocusScope.of(context).unfocus();
      await widget.controller.connect(draft);
      if (mounted && widget.controller.connected) widget.onSessions();
    } on FormatException catch (e) {
      setState(() => _localError = e.message);
    }
  }

  Future<void> _forget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本机连接配置？'),
        content: const Text('将删除这台手机保存的地址和连接凭据。PC 上的会话和文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.forgetConnection();
    if (!mounted) return;
    _name.text = '我的电脑';
    _url.clear();
    _token.clear();
    setState(() => _localError = null);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    final theme = Theme.of(context);
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '连接电脑',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text('手机负责交互，电脑负责执行。'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.desktop_windows_rounded, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.profile?.name ?? '你的 PC Agent',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text('DSH 服务', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusPill(
                    app.connectionLabel,
                    active: app.connected && !app.demo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (_localError != null || app.error != null)
            ErrorNotice(_localError ?? app.error!),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !app.connecting,
                  decoration: const InputDecoration(
                    labelText: '电脑名称',
                    prefixIcon: Icon(Icons.computer_rounded),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _url,
                  onChanged: _addressChanged,
                  enabled: !app.connecting,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '服务地址',
                    hintText: 'https://agent.example.com',
                    prefixIcon: Icon(Icons.link_rounded),
                    helperText: '填写可访问的 DSH 地址，也可粘贴带 Token 的连接链接。',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    try {
                      ConnectionDraft.parse(
                        name: _name.text,
                        address: value ?? '',
                        token: '',
                      );
                      return null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _token,
                  enabled: !app.connecting,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: '连接 Token',
                    prefixIcon: const Icon(Icons.key_rounded),
                    helperText: '使用 PC 服务的连接凭据，无需填写模型 API Key。',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      tooltip: _obscure ? '显示 Token' : '隐藏 Token',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (!app.connecting) _connect();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: app.connecting ? null : _connect,
            icon: app.connecting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bolt_rounded),
            label: Text(app.connecting ? '正在验证连接…' : '保存并连接'),
          ),
          if (app.connected) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: app.disconnect,
              child: const Text('断开连接'),
            ),
          ],
          if (app.profile != null)
            TextButton(
              onPressed: app.connecting ? null : _forget,
              child: const Text('清除本机配置'),
            ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接前准备', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  const Text(
                    '1. 在电脑上启动 DSH，并配置好模型。\n2. 为服务配置手机可访问的地址。\n3. 保持电脑运行，填入地址和连接 Token。',
                    style: TextStyle(height: 1.8, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
