import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/domain/usecases/save_history_entry.dart';
import 'package:evaluator/presentation/controllers/reading_settings_controller.dart';
import 'package:evaluator/presentation/pages/exam_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_history.dart';

void main() {
  testWidgets('revelar al final hides answers until the result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reading_reveal_at_end': true});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveHistoryEntry(FakeHistory()));
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
    Get.put(SaveHistoryEntry(FakeHistory()));
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

  testWidgets(
    'finish early counts unanswered as wrong; sheet is text size only',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = Get.put(
        ReadingSettingsController(await SharedPreferences.getInstance()),
      );
      final history = FakeHistory();
      Get.put(SaveHistoryEntry(history));
      addTearDown(Get.reset);
      final evaluation = Evaluation(
        id: 'e',
        title: 'E',
        questions: [
          for (var i = 1; i <= 20; i++)
            Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
        ],
      );

      // Always shuffled, even with the shuffle settings off.
      expect(settings.shuffleQuestions.value, isFalse);
      final order = settings
          .prepare(evaluation.questions, alwaysShuffle: true)
          .map((q) => q.id);
      expect(order, isNot([for (var i = 1; i <= 20; i++) i]));

      await tester.pumpWidget(
        GetMaterialApp(home: ExamPage(evaluation: evaluation)),
      );

      await tester.tap(find.byTooltip('Tamaño de texto'));
      await tester.pumpAndSettle();
      expect(find.text('Tamaño de texto'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();

      // Answer the first question right, then finish.
      await tester.tap(find.text('a'));
      await tester.pump();
      await tester.tap(find.byTooltip('Finalizar evaluación'));
      await tester.pumpAndSettle();
      expect(
        find.text('Quedan 19 sin responder; cuentan como incorrectas.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();

      expect(find.text('1 de 20 correctas'), findsOneWidget);
      final saved = history.entries.single as Attempt;
      expect((saved.correct, saved.total), (1, 20));
    },
  );
}
