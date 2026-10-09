import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'injection.dart';
import 'presentation/controllers/theme_controller.dart';
import 'presentation/pages/home.dart';

// The emulator the UI was designed on: 1080 px at 440 dpi, font size 115%.
const _designWidth = 1080 / 2.75;
const _designText = TextScaler.linear(1.15);

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
        builder: (context, child) => _DesignScale(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
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
        ),
      );
    });
  }
}

/// Scales the whole UI (pages, dialogs, sheets) to the design screen, so it
/// keeps the same proportions on any device. The phone's font size is ignored.
// ponytail: one global scale, no per-widget .w/.sp (no screenutil).
class _DesignScale extends StatelessWidget {
  final Widget child;

  const _DesignScale({required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // shortestSide, so landscape doesn't blow the UI up.
    final s = mq.size.shortestSide / _designWidth;
    final size = mq.size / s;
    // FittedBox scales painting and hit testing together.
    return FittedBox(
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            devicePixelRatio: mq.devicePixelRatio * s,
            padding: mq.padding / s,
            viewPadding: mq.viewPadding / s,
            viewInsets: mq.viewInsets / s, // keyboard
            systemGestureInsets: mq.systemGestureInsets / s,
            textScaler: _designText,
          ),
          child: child,
        ),
      ),
    );
  }
}
