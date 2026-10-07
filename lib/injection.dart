import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/asset_evaluation_repository.dart';
import 'data/repositories/prefs_history_repository.dart';
import 'domain/repositories/evaluation_repository.dart';
import 'domain/repositories/history_repository.dart';
import 'domain/usecases/get_evaluations.dart';
import 'domain/usecases/get_history.dart';
import 'domain/usecases/save_attempt.dart';
import 'presentation/controllers/reading_settings_controller.dart';
import 'presentation/controllers/theme_controller.dart';

/// Wires data → domain → presentation. The only place that knows the
/// concrete repository classes.
Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();

  Get.put<EvaluationRepository>(AssetEvaluationRepository(rootBundle));
  Get.put<HistoryRepository>(PrefsHistoryRepository(prefs));

  Get.put(GetEvaluations(Get.find()));
  Get.put(GetHistory(Get.find()));
  Get.put(SaveAttempt(Get.find()));

  Get.put(ThemeController(prefs));
  Get.put(ReadingSettingsController(prefs));
}
