import 'package:flutter/material.dart';
import 'app_controller.dart';
import 'ui/connection_screen.dart';
import 'ui/sessions_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/widgets.dart';

class NobigApp extends StatelessWidget {
  const NobigApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (_, _) => MaterialApp(
      title: 'Nobig Agent',
      debugShowCheckedModeBanner: false,
      themeMode: controller.themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _AppShell(controller: controller),
    ),
  );

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5961E8),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF11131B)
          : const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF1D202D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1D202D) : Colors.white,
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF161923) : Colors.white,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.controller});
  final AppController controller;
  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.resume();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller.pause();
    }
  }

  void _tab(int index) => setState(() => _index = index);
  Future<void> _demo() async {
    await widget.controller.enterDemo();
    if (mounted && widget.controller.connected) _tab(0);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BrandMark(size: 28),
            SizedBox(width: 10),
            Text(
              'Nobig',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StatusPill(
              app.connectionLabel,
              active: app.connected && !app.demo,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (app.demo) const DemoNotice(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  SessionsScreen(controller: app, onConfigure: () => _tab(1)),
                  ConnectionScreen(controller: app, onSessions: () => _tab(0)),
                  SettingsScreen(controller: app, onDemo: _demo),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _tab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '会话',
          ),
          NavigationDestination(
            icon: Icon(Icons.desktop_windows_outlined),
            selectedIcon: Icon(Icons.desktop_windows_rounded),
            label: '电脑',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
