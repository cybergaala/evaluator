import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/presentation/pages/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

void main() {
  testWidgets('swiping the card changes page in both directions', (
    tester,
  ) async {
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        for (var i = 1; i <= 3; i++)
          Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    // Vertical (default).
    await tester.drag(find.text('Q1'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    // Horizontal.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Q2'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });
}
