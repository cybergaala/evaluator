import 'dart:math';

import 'package:evaluator/domain/entities/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const q = Question(
    id: 1,
    question: '?',
    options: ['a', 'b', 'c'],
    answers: [0, 2],
  );

  test('isCorrect needs exactly the right options', () {
    expect(q.isCorrect({0, 2}), isTrue);
    expect(q.isCorrect({2, 0}), isTrue);
    expect(q.isCorrect({0}), isFalse);
    expect(q.isCorrect({0, 1}), isFalse);
    expect(q.isCorrect({0, 1, 2}), isFalse);
  });

  test('withShuffledOptions keeps answers pointing at the same text', () {
    for (var seed = 0; seed < 20; seed++) {
      final s = q.withShuffledOptions(Random(seed));
      expect(s.options.toSet(), q.options.toSet());
      expect(
        {for (final a in s.answers) s.options[a]},
        {for (final a in q.answers) q.options[a]},
      );
    }
  });
}
