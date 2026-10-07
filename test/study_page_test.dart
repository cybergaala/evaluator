import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/presentation/controllers/reading_settings_controller.dart';
import 'package:evaluator/presentation/pages/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('swiping the card changes page in both directions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = Get.put(
      ReadingSettingsController(await SharedPreferences.getInstance()),
    );
    addTearDown(Get.reset);
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
    settings.vertical.value = false;
    await tester.pumpAndSettle();
    await tester.drag(find.text('Q2'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });
}
