import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'bootstrap/termux_bootstrap.dart';
import 'l10n/app_localizations.dart';
import 'providers/settings_provider.dart';
import 'providers/terminal_provider.dart';
import 'providers/ssh_provider.dart';
import 'providers/task_provider.dart';
import 'screens/bootstrap_screen.dart';
import 'screens/terminal_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeepThoughtApp());
}

/// Deep Thought Terminal 应用入口
class DeepThoughtApp extends StatelessWidget {
  const DeepThoughtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(create: (_) => SSHProvider()..init()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..init()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          debugPrint('MaterialApp rebuilding with locale: ${settings.locale}');
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            // 本地化配置
            locale: settings.locale,
            supportedLocales: L10n.all,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settings.themeMode,
            theme: _buildTheme(settings.terminalTheme, Brightness.light),
            darkTheme: _buildTheme(settings.terminalTheme, Brightness.dark),
            home: settings.initialized
                ? const _AppContent()
                : const _LoadingScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(dynamic terminalTheme, Brightness brightness) {
    final bg = Color(terminalTheme.background.value);
    final fg = Color(terminalTheme.foreground.value);
    final primary = Color(terminalTheme.blue.value);
    final secondary = Color(terminalTheme.cursor.value);

    // Calculate a slightly different surface color for contrast
    // In dark mode, make it slightly lighter. In light mode, slightly darker.
    final isDark = brightness == Brightness.dark;
    final surface = isDark 
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), bg)
        : Color.alphaBlend(Colors.black.withOpacity(0.05), bg);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      background: bg,
      surface: surface,
      onBackground: fg,
      onSurface: fg,
      primary: primary,
      secondary: secondary,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        // Add a subtle border to the right side of the drawer
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// 应用主内容 - 处理Bootstrap初始化
class _AppContent extends StatefulWidget {
  const _AppContent();

  @override
  State<_AppContent> createState() => _AppContentState();
}

class _AppContentState extends State<_AppContent> {
  bool _checking = true;
  bool _bootstrapReady = false;

  @override
  void initState() {
    super.initState();
    _checkBootstrap();
  }

  Future<void> _checkBootstrap() async {
    if (Platform.isAndroid) {
      // Android: 检查bootstrap是否已安装
      final isInstalled = await TermuxBootstrap.isInstalled();
      if (mounted) {
        setState(() {
          _bootstrapReady = isInstalled;
          _checking = false;
        });
      }
    } else {
      // 非Android平台直接进入终端
      if (mounted) {
        setState(() {
          _bootstrapReady = true;
          _checking = false;
        });
      }
    }
  }

  void _onBootstrapComplete() {
    setState(() {
      _bootstrapReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const _LoadingScreen();
    }

    if (!_bootstrapReady && Platform.isAndroid) {
      return BootstrapScreen(
        onComplete: _onBootstrapComplete,
      );
    }

    return const TerminalScreen();
  }
}

/// 加载屏幕
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.terminal,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Loading...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
