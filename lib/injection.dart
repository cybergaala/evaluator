import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/repositories/asset_evaluation_repository.dart';
import 'data/repositories/sqlite_history_repository.dart';
import 'domain/entities/history_entry.dart';
import 'domain/repositories/evaluation_repository.dart';
import 'domain/repositories/history_repository.dart';
import 'domain/usecases/clear_history.dart';
import 'domain/usecases/get_attempts.dart';
import 'domain/usecases/get_evaluations.dart';
import 'domain/usecases/get_history.dart';
import 'domain/usecases/save_history_entry.dart';
import 'presentation/controllers/bookmarks_controller.dart';
import 'presentation/controllers/highlights_controller.dart';
import 'presentation/controllers/reading_settings_controller.dart';
import 'presentation/controllers/theme_controller.dart';

/// Wires data → domain → presentation. The only place that knows the
/// concrete repository classes.
Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final evaluations = AssetEvaluationRepository(rootBundle);
  final history = await SqliteHistoryRepository.open();
  await migratePrefsHistory(prefs, history, evaluations);

  Get.put<EvaluationRepository>(evaluations);
  Get.put<HistoryRepository>(history);

  Get.put(GetEvaluations(Get.find()));
  Get.put(GetHistory(Get.find()));
  Get.put(GetAttempts(Get.find()));
  Get.put(SaveHistoryEntry(Get.find()));
  Get.put(ClearHistory(Get.find()));

  Get.put(ThemeController(prefs));
  Get.put(ReadingSettingsController(prefs));
  Get.put(BookmarksController(prefs));
  Get.put(HighlightsController(prefs));
}

/// One-time move of the old `history_<evaluationId>` lists (exam attempts
/// only) from shared_preferences into [history]. Each key is removed after
/// it is copied, so this is a no-op once done.
Future<void> migratePrefsHistory(
  SharedPreferences prefs,
  HistoryRepository history,
  EvaluationRepository evaluations,
) async {
  final keys = prefs.getKeys().where((k) => k.startsWith('history_')).toList();
  if (keys.isEmpty) return;
  final titles = {for (final e in await evaluations.getAll()) e.id: e.title};
  for (final key in keys) {
    final id = key.substring('history_'.length);
    for (final raw in prefs.getStringList(key) ?? <String>[]) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      await history.save(
        Attempt(
          id,
          titles[id] ?? id,
          DateTime.parse(json['date'] as String),
          json['correct'] as int,
          json['total'] as int,
        ),
      );
    }
    await prefs.remove(key);
  }
}
