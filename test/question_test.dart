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
}
