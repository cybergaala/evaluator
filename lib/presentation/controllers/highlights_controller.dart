import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A highlighted range `[start, end)` painted with `neonColors[color]`.
typedef Highlight = (int start, int end, int color);

/// Study-mode highlights per evaluation, persisted in [SharedPreferences]
/// under `highlights_<evaluationId>` as
/// `{"<questionId>": {"<field>": [[start, end, color], ...]}}`.
/// `field` is `q` (question), `o<i>` (option i) or `e` (explanation).
// ponytail: ranges are character offsets; editing a question's text in the
// JSON shifts its highlights. Store a text hash per field if that happens.
class HighlightsController extends GetxController {
  static HighlightsController get i => Get.find();

  final SharedPreferences _prefs;

  HighlightsController(this._prefs);

  Map<String, dynamic> _all(String evaluationId) =>
      jsonDecode(_prefs.getString('highlights_$evaluationId') ?? '{}');

  List<Highlight> of(String evaluationId, int questionId, String field) => [
    for (final r in _all(evaluationId)['$questionId']?[field] ?? [])
      (r[0] as int, r[1] as int, r[2] as int),
  ];

  /// Paints `[start, end)` with [color], or erases it when [color] is null.
  void paint(
    String evaluationId,
    int questionId,
    String field,
    int start,
    int end,
    int? color,
  ) {
    final all = _all(evaluationId);
    final q = (all['$questionId'] ??= <String, dynamic>{}) as Map;
    final ranges = apply(
      of(evaluationId, questionId, field),
      start,
      end,
      color,
    );
    q[field] = [
      for (final (s, e, c) in ranges) [s, e, c],
    ];
    _prefs.setString('highlights_$evaluationId', jsonEncode(all));
  }

  /// Cuts `[start, end)` out of [ranges], then adds it back with [color]
  /// (none when null). Sorted by start; painting over replaces the old color.
  static List<Highlight> apply(
    List<Highlight> ranges,
    int start,
    int end,
    int? color,
  ) => [
    for (final (s, e, c) in ranges) ...[
      if (s < start) (s, e < start ? e : start, c),
      if (e > end) (s > end ? s : end, e, c),
    ],
    if (color != null && start < end) (start, end, color),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}
