import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pages/home.dart';
import 'pages/theme_page.dart';

void main() {
  EasyRefresh.defaultHeaderBuilder = () => const ClassicHeader(
    dragText: 'Desliza para actualizar',
    armedText: 'Suelta para actualizar',
    readyText: 'Actualizando...',
    processingText: 'Actualizando...',
    processedText: 'Listo',
    noMoreText: 'No hay más',
    failedText: 'Error',
    messageText: 'Actualizado a las %T',
  );
  Get.put(ThemeController());
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
