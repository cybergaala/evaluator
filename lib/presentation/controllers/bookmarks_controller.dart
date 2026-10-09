import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bookmarked question ids per evaluation, persisted in [SharedPreferences]
/// under `<prefix>_<evaluationId>` (`bookmarks_` here, `learned_` in
/// [LearnedController]).
class BookmarksController extends GetxController {
  static BookmarksController get i => Get.find();

  final SharedPreferences _prefs;
  final String _prefix;

  BookmarksController(this._prefs, [this._prefix = 'bookmarks']);

  Set<int> of(String evaluationId) => {
    for (final id in _prefs.getStringList('${_prefix}_$evaluationId') ?? [])
      int.parse(id),
  };

  /// Adds or removes [questionId]; returns the updated set.
  Set<int> toggle(String evaluationId, int questionId) {
    final ids = of(evaluationId);
    if (!ids.remove(questionId)) ids.add(questionId);
    _prefs.setStringList('${_prefix}_$evaluationId', [
      for (final id in ids) '$id',
    ]);
    return ids;
  }

  /// Removes them from every evaluation.
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('${_prefix}_'),
    )) {
      await _prefs.remove(key);
    }
  }
}

/// Question ids marked as learned per evaluation, under
/// `learned_<evaluationId>`. Hidden by default in study mode, and the only
/// ones asked in a "Solo aprendidas" evaluation.
class LearnedController extends BookmarksController {
  static LearnedController get i => Get.find();

  LearnedController(SharedPreferences prefs) : super(prefs, 'learned');
}
