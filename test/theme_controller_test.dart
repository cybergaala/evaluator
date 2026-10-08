import 'package:evaluator/presentation/controllers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dark = ThemeModel.themes.firstWhere((t) => t.mode == ThemeMode.dark);
    final blue = ThemeModel.themes.firstWhere((t) => t.color == Colors.blue);

    ThemeController(prefs)
      ..apply(dark)
      ..apply(blue);

    final restarted = ThemeController(prefs);
    expect(restarted.mode.value, ThemeMode.dark);
    expect(restarted.isSelected(blue), isTrue);
  });
}
