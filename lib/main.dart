import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'injection.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/pages/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the gesture bar so it takes the app's background color.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
          amoled: theme.amoled.value,
        ),
        home: const HomePage(),
        // A region at the bottom of every route: Flutter takes the gesture bar
        // style from it, otherwise the AppBar's style leaves it opaque.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            systemNavigationBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child!,
        ),
      );
    });
  }
}
