import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/attempt.dart';
import '../../domain/repositories/history_repository.dart';
import '../models/attempt_model.dart';

class PrefsHistoryRepository implements HistoryRepository {
  final SharedPreferences _prefs;

  const PrefsHistoryRepository(this._prefs);

  String _key(String evaluationId) => 'history_$evaluationId';

  @override
  Future<List<Attempt>> getAll(String evaluationId) async {
    final raw = _prefs.getStringList(_key(evaluationId)) ?? [];
    return [for (final s in raw.reversed) AttemptModel.fromJson(jsonDecode(s))];
  }

  @override
  Future<void> save(String evaluationId, Attempt attempt) async {
    final key = _key(evaluationId);
    final raw = _prefs.getStringList(key) ?? [];
    final json = jsonEncode(AttemptModel.fromEntity(attempt).toJson());
    await _prefs.setStringList(key, [...raw, json]);
  }
}
