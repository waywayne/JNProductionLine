import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'models/test_state.dart';
import 'models/log_state.dart';
import 'models/ota_state.dart';
import 'config/production_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化产测配置
  await ProductionConfig().init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LogState()),
        ChangeNotifierProvider(create: (_) => TestState()),
        ChangeNotifierProvider(create: (_) => OTAState()),
      ],
      child: MaterialApp(
        title: 'JN Production Line',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // 配置字体回退，确保中文显示正常
          fontFamily: 'Roboto',
          fontFamilyFallback: const [
            'Noto Sans CJK SC',
            'Noto Sans CJK',
            'WenQuanYi Micro Hei',
            'WenQuanYi Zen Hei',
            'Droid Sans Fallback',
          ],
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
