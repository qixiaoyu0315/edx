import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'services/mqtt_storage.dart';
import 'screens/temperature_page.dart';
import 'screens/countdown_page.dart';
import 'screens/settings_page.dart';
import 'pages/turtle_growth_home_page.dart'; // 导入新的成长记录页面

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MqttConfigStorage().init();
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
      home: const MainScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const TemperaturePage(),
    const CountdownPage(),
    const TurtleGrowthHomePage(), // 添加成长页面
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: ShadTabs<int>(
        value: _currentIndex,
        onChanged: (value) => setState(() => _currentIndex = value),
        tabBarConstraints: const BoxConstraints(maxHeight: 80),
        contentConstraints: const BoxConstraints(),
        tabs: [
          ShadTab(
            value: 0,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.thermostat_auto),
                Text('温度'),
              ],
            ),
            content: const SizedBox.shrink(),
          ),
          ShadTab(
            value: 1,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fastfood),
                Text('干饭'),
              ],
            ),
            content: const SizedBox.shrink(),
          ),
          ShadTab(
            value: 2,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.theaters),
                Text('成长'),
              ],
            ),
            content: const SizedBox.shrink(),
          ),
          ShadTab(
            value: 3,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings),
                Text('设置'),
              ],
            ),
            content: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
