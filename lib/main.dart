import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'models/test_state.dart';
import 'models/log_state.dart';
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
      ],
      child: MaterialApp(
        title: 'JN Production Line',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
