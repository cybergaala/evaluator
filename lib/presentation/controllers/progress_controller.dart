import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/question.dart';

/// A session to resume: the questions in session order (options as shown),
/// the current one and, in evaluation mode, the running score.
typedef Progress = ({List<Question> questions, int index, int correct});

/// Unfinished study/evaluation sessions in [SharedPreferences] under
/// `progress_<mode>_<evaluationId>` as
/// `{"order": [[questionId, [originalOptionIndex, ...]], ...], "index": i, "correct": c}`.
class ProgressController extends GetxController {
  static ProgressController get i => Get.find();

  final SharedPreferences _prefs;

  ProgressController(this._prefs);

  /// The saved session, or null when there is none or the evaluation's
  /// JSON changed since (a question or option is gone).
  Progress? load(String mode, Evaluation evaluation) {
    final raw = _prefs.getString('progress_${mode}_${evaluation.id}');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final byId = {for (final q in evaluation.questions) q.id: q};
    final questions = <Question>[];
    for (final [id, order] in json['order'] as List) {
      final q = byId[id];
      final perm = (order as List).cast<int>();
      if (q == null || perm.length != q.options.length) return null;
      questions.add(q.withOptionOrder(perm));
    }
    final index = json['index'] as int;
    if (index >= questions.length) return null;
    return (
      questions: questions,
      index: index,
      correct: json['correct'] as int,
    );
  }

  void save(
    String mode,
    Evaluation evaluation,
    List<Question> questions,
    int index, [
    int correct = 0,
  ]) {
    final byId = {for (final q in evaluation.questions) q.id: q};
    _prefs.setString(
      'progress_${mode}_${evaluation.id}',
      jsonEncode({
        'order': [
          for (final q in questions)
            [
              q.id,
              // ponytail: maps shown options back by text; two identical
              // options in one question would both map to the first.
              [for (final o in q.options) byId[q.id]!.options.indexOf(o)],
            ],
        ],
        'index': index,
        'correct': correct,
      }),
    );
  }

  void clear(String mode, String evaluationId) =>
      _prefs.remove('progress_${mode}_$evaluationId');
}
