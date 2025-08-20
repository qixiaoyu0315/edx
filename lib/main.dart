import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    return const MaterialApp(
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
      title: '龟龟温度计',
      // 添加本地化支持
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: Locale('zh', 'CN'),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  // 更新页面列表，加入成长记录页面
  final List<Widget> _pages = [
    TemperaturePage(),
    CountdownPage(),
    TurtleGrowthHomePage(), // 添加成长页面
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 确保所有标签都可见
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.thermostat_auto),
            label: '温度',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: '干饭'),
          BottomNavigationBarItem(icon: Icon(Icons.theaters), label: '成长'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
