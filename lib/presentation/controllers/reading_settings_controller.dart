import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/question.dart';

/// Reading settings for study and evaluation modes, persisted in
/// [SharedPreferences].
class ReadingSettingsController extends GetxController {
  static ReadingSettingsController get i => Get.find();

  final SharedPreferences _prefs;

  late final textScale = _double('reading_text_scale', 1.0);
  late final justify = _bool('reading_justify', false);
  late final vertical = _bool('reading_vertical', true);
  late final shuffleQuestions = _bool('reading_shuffle_questions', false);
  late final shuffleOptions = _bool('reading_shuffle_options', false);
  late final revealAtEnd = _bool('reading_reveal_at_end', false);
  late final showSlider = _bool('reading_show_slider', true);

  ReadingSettingsController(this._prefs);

  Axis get axis => vertical.value ? Axis.vertical : Axis.horizontal;

  /// The questions for a new session, shuffled as configured.
  /// [alwaysShuffle] ignores the shuffle settings (evaluation mode).
  List<Question> prepare(
    List<Question> questions, {
    bool alwaysShuffle = false,
  }) {
    final random = Random();
    final result = [
      for (final q in questions)
        alwaysShuffle || shuffleOptions.value
            ? q.withShuffledOptions(random)
            : q,
    ];
    if (alwaysShuffle || shuffleQuestions.value) result.shuffle(random);
    return result;
  }

  RxBool _bool(String key, bool initial) {
    final rx = (_prefs.getBool(key) ?? initial).obs;
    ever(rx, (v) => _prefs.setBool(key, v));
    return rx;
  }

  RxDouble _double(String key, double initial) {
    final rx = (_prefs.getDouble(key) ?? initial).obs;
    ever(rx, (v) => _prefs.setDouble(key, v));
    return rx;
  }
}
