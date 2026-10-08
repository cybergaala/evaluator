import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bookmarked question ids per evaluation, persisted in [SharedPreferences]
/// under `bookmarks_<evaluationId>`.
class BookmarksController extends GetxController {
  static BookmarksController get i => Get.find();

  final SharedPreferences _prefs;

  BookmarksController(this._prefs);

  Set<int> of(String evaluationId) => {
    for (final id in _prefs.getStringList('bookmarks_$evaluationId') ?? [])
      int.parse(id),
  };

  /// Adds or removes [questionId]; returns the updated set.
  Set<int> toggle(String evaluationId, int questionId) {
    final ids = of(evaluationId);
    if (!ids.remove(questionId)) ids.add(questionId);
    _prefs.setStringList('bookmarks_$evaluationId', [
      for (final id in ids) '$id',
    ]);
    return ids;
  }

  /// Removes them from every evaluation.
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().where(
      (k) => k.startsWith('bookmarks_'),
    )) {
      await _prefs.remove(key);
    }
  }
}
