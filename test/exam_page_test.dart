import 'package:evaluator/domain/entities/attempt.dart';
import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/domain/repositories/history_repository.dart';
import 'package:evaluator/domain/usecases/save_attempt.dart';
import 'package:evaluator/presentation/controllers/reading_settings_controller.dart';
import 'package:evaluator/presentation/pages/exam_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoHistory implements HistoryRepository {
  @override
  Future<List<Attempt>> getAll(String evaluationId) async => [];

  @override
  Future<void> save(String evaluationId, Attempt attempt) async {}
}

void main() {
  testWidgets('revelar al final hides answers until the result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reading_reveal_at_end': true});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveAttempt(_NoHistory()));
    addTearDown(Get.reset);
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        Question(id: 1, question: 'Q1', options: ['a', 'b'], answers: [0]),
      ],
    );
    await tester.pumpWidget(
      GetMaterialApp(home: ExamPage(evaluation: evaluation)),
    );

    // A wrong pick can be swapped, and nothing is revealed.
    await tester.tap(find.text('b'));
    await tester.tap(find.text('a'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget); // no running score

    await tester.tap(find.text('Ver resultado'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('leaving asks for confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveAttempt(_NoHistory()));
    addTearDown(Get.reset);
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        Question(id: 1, question: 'Q1', options: ['a', 'b'], answers: [0]),
      ],
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Get.to(() => ExamPage(evaluation: evaluation)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Q1'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
