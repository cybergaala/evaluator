import 'dart:convert';
import 'dart:io';

import 'package:evaluator/data/models/evaluation_model.dart';
import 'package:evaluator/data/repositories/asset_evaluation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates every bank in assets/evaluations/ against the schema in CLAUDE.md.
void main() {
  final files = Directory(evaluationsDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));

  test('there is at least one evaluation', () => expect(files, isNotEmpty));

  for (final file in files) {
    test(file.path, () {
      final e = EvaluationModel.fromJson(jsonDecode(file.readAsStringSync()));
      final fileId = file.uri.pathSegments.last.replaceAll('.json', '');

      expect(e.id, fileId, reason: 'id must equal the file name');
      expect(e.questions, isNotEmpty);
      expect(
        e.questions.map((q) => q.id).toSet().length,
        e.questions.length,
        reason: 'question ids must be unique',
      );
      for (final q in e.questions) {
        final where = 'question ${q.id}';
        expect(q.options.length, greaterThanOrEqualTo(2), reason: where);
        expect(q.answers, isNotEmpty, reason: where);
        expect(q.answers.toSet().length, q.answers.length, reason: where);
        for (final a in q.answers) {
          expect(a, inInclusiveRange(0, q.options.length - 1), reason: where);
        }
      }
    });
  }
}
