import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'injection.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/pages/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = ThemeController.i;
      return GetMaterialApp(
        title: 'Evaluator',
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode.value,
        theme: ThemeModel.generateTheme(
          brightness: Brightness.light,
          colorSchemeSeed: theme.seedColor.value,
        ),
        darkTheme: ThemeModel.generateTheme(
          brightness: Brightness.dark,
          colorSchemeSeed: theme.seedColor.value,
        ),
        home: const HomePage(),
      );
    });
  }
}
