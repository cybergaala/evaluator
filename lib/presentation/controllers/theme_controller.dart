import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Adapted from flutter_easy_refresh v4 example: page/more/theme_page.dart
class ThemeModel {
  final String name;
  final Color? color;
  final ThemeMode? mode;
  final IconData? icon;

  const ThemeModel({required this.name, this.color, this.mode, this.icon});

  static ThemeData generateTheme({
    required Brightness brightness,
    required Color colorSchemeSeed,
  }) {
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorSchemeSeed: colorSchemeSeed,
    );
  }

  static final themes = [
    ThemeModel(
      name: 'Sistema',
      mode: ThemeMode.system,
      icon: GetPlatform.isMobile ? Icons.phone_android : Icons.computer,
    ),
    const ThemeModel(
      name: 'Claro',
      mode: ThemeMode.light,
      icon: Icons.light_mode,
    ),
    const ThemeModel(
      name: 'Oscuro',
      mode: ThemeMode.dark,
      icon: Icons.dark_mode,
    ),
    const ThemeModel(name: 'Azul', color: Colors.blue),
    const ThemeModel(name: 'Rojo', color: Colors.red),
    const ThemeModel(name: 'Rosa', color: Colors.pink),
    const ThemeModel(name: 'Morado', color: Colors.purple),
    const ThemeModel(name: 'Índigo', color: Colors.indigo),
    const ThemeModel(name: 'Cian', color: Colors.cyan),
    const ThemeModel(name: 'Verde azulado', color: Colors.teal),
    const ThemeModel(name: 'Verde', color: Colors.green),
    const ThemeModel(name: 'Ámbar', color: Colors.amber),
    const ThemeModel(name: 'Naranja', color: Colors.deepOrange),
    const ThemeModel(name: 'Marrón', color: Colors.brown),
    const ThemeModel(name: 'Gris azulado', color: Colors.blueGrey),
  ];
}

/// Persists the chosen mode and seed color in [SharedPreferences].
class ThemeController extends GetxController {
  static ThemeController get i => Get.find();

  static const _modeKey = 'theme_mode';
  static const _colorKey = 'theme_color';

  final SharedPreferences _prefs;
  final mode = ThemeMode.system.obs;
  final seedColor = Rx<Color>(Colors.green);

  ThemeController(this._prefs) {
    final modeIndex = _prefs.getInt(_modeKey);
    if (modeIndex != null && modeIndex < ThemeMode.values.length) {
      mode.value = ThemeMode.values[modeIndex];
    }
    // Look the color up in [ThemeModel.themes]: a plain Color(argb) never
    // equals a MaterialColor, which would break [isSelected].
    final argb = _prefs.getInt(_colorKey);
    final saved = ThemeModel.themes
        .map((t) => t.color)
        .where((c) => c != null && c.toARGB32() == argb)
        .firstOrNull;
    if (saved != null) seedColor.value = saved;
  }

  /// Mode entries switch [mode]; color entries switch [seedColor].
  void apply(ThemeModel model) {
    if (model.mode != null) {
      mode.value = model.mode!;
      _prefs.setInt(_modeKey, model.mode!.index);
    } else if (model.color != null) {
      seedColor.value = model.color!;
      _prefs.setInt(_colorKey, model.color!.toARGB32());
    }
  }

  bool isSelected(ThemeModel model) =>
      model.mode == mode.value || model.color == seedColor.value;
}
