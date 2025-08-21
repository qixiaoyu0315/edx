import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/mqtt_storage.dart';
import 'screens/temperature_page.dart';
import 'screens/countdown_page.dart';
import 'screens/settings_page.dart';
import 'pages/turtle_growth_home_page.dart'; // 导入新的成长记录页面

Future<void> applySystemUi({required bool fullscreen}) async {
  if (fullscreen) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  } else {
    // 非全屏下，跟随系统明暗色设置系统栏样式
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool isDark = platformBrightness == Brightness.dark;
    if (isDark) {
      // 透明 + 浅色图标，避免暗色模式下出现白色状态栏
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } else {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.black12,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MqttConfigStorage().init();
  // 应用持久化的全屏设置（默认不全屏）
  final prefs = await SharedPreferences.getInstance();
  final full = prefs.getBool('fullscreen') ?? false;
  await applySystemUi(fullscreen: full);
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadBlueColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadBlueColorScheme.dark(),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const TemperaturePage(),
    const CountdownPage(),
    const TurtleGrowthHomePage(), // 添加成长页面
    const SettingsPage(),
  ];

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
  void didChangePlatformBrightness() async {
    // 系统主题变化时，重新应用系统栏样式，保持与系统一致
    final prefs = await SharedPreferences.getInstance();
    final full = prefs.getBool('fullscreen') ?? false;
    // 仅当不在全屏或需要时也可应用透明样式（applySystemUi 内部会处理）
    await applySystemUi(fullscreen: full);
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // 从后台回到前台时，某些 ROM 会重置系统栏样式，这里重新应用
      final prefs = await SharedPreferences.getInstance();
      final full = prefs.getBool('fullscreen') ?? false;
      await applySystemUi(fullscreen: full);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ShadTheme.of(context).brightness == Brightness.dark;
    final overlayStyle = isDark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.black12,
            systemStatusBarContrastEnforced: false,
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        body: _pages[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (value) => setState(() => _currentIndex = value),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.thermostat_auto, color: Colors.deepOrange),
              label: '温度',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fastfood, color: Colors.orange),
              label: '干饭',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.theaters, color: Colors.green),
              label: '成长',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings, color: Colors.blue),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
