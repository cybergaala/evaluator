import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/domain/usecases/save_history_entry.dart';
import 'package:evaluator/presentation/controllers/progress_controller.dart';
import 'package:evaluator/presentation/controllers/reading_settings_controller.dart';
import 'package:evaluator/presentation/pages/exam_page.dart';
import 'package:evaluator/presentation/widgets/exam_setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_history.dart';

void main() {
  testWidgets('Reveal at the end hides answers until the result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reading_reveal_at_end': true});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveHistoryEntry(FakeHistory()));
    Get.put(ProgressController(await SharedPreferences.getInstance()));
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
    // Only the color tells the state: 'a' selected (not green), 'b' neutral.
    ListTile tile(String text) => tester.widget<ListTile>(
      find.ancestor(of: find.text(text), matching: find.byType(ListTile)),
    );
    final scheme = Theme.of(tester.element(find.text('a'))).colorScheme;
    expect(tile('a').tileColor, scheme.secondaryContainer);
    expect(tile('b').tileColor, isNull);
    expect(find.text('1/1'), findsOneWidget); // no running score

    await tester.tap(find.text('See result'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('leaving asks for confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveHistoryEntry(FakeHistory()));
    Get.put(ProgressController(await SharedPreferences.getInstance()));
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
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Q1'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
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
      Get.put(ProgressController(await SharedPreferences.getInstance()));
      addTearDown(Get.reset);
      final evaluation = Evaluation(
        id: 'e',
        title: 'E',
        questions: [
          for (var i = 1; i <= 20; i++)
            Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
        ],
      );

      // Shuffled by default, even with the study shuffle settings off.
      expect(settings.shuffleQuestions.value, isFalse);
      final order = const ExamSetup().pick(evaluation).map((q) => q.id);
      expect(order, isNot([for (var i = 1; i <= 20; i++) i]));

      await tester.pumpWidget(
        GetMaterialApp(home: ExamPage(evaluation: evaluation)),
      );

      await tester.tap(find.byTooltip('Text size'));
      await tester.pumpAndSettle();
      expect(find.text('Text size'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tapAt(const Offset(10, 10)); // close the sheet
      await tester.pumpAndSettle();

      // Answer the first question right, then finish.
      await tester.tap(find.text('a'));
      await tester.pump();
      await tester.tap(find.byTooltip('Finish exam'));
      await tester.pumpAndSettle();
      expect(
        find.text('19 left unanswered; they count as wrong.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 20 correct'), findsOneWidget);
      final saved = history.entries.single as Attempt;
      expect((saved.correct, saved.total), (1, 20));
    },
  );

  testWidgets('resumes where it was left, then clears on finish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put(ReadingSettingsController(prefs));
    Get.put(SaveHistoryEntry(FakeHistory()));
    Get.put(ProgressController(prefs));
    addTearDown(Get.reset);
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        for (var i = 1; i <= 2; i++)
          Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
      ],
    );
    Future<void> open() => tester.pumpWidget(
      GetMaterialApp(
        home: ExamPage(key: UniqueKey(), evaluation: evaluation),
      ),
    );

    await open();
    final first = find.textContaining(RegExp(r'^Q\d$')).evaluate().first;
    final firstText = (first.widget as Text).data!;
    await tester.tap(find.text('a').first);
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await open(); // a fresh page, like reopening it from Home
    await tester.pumpAndSettle();
    expect(find.textContaining('2/2'), findsOneWidget);
    expect(find.text(firstText), findsNothing);

    await tester.tap(find.byIcon(Icons.flag));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(ProgressController.i.load('exam', evaluation), isNull);
  });

  testWidgets('only asks the given questions', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    Get.put(SaveHistoryEntry(FakeHistory()));
    Get.put(ProgressController(await SharedPreferences.getInstance()));
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
      GetMaterialApp(
        home: ExamPage(
          evaluation: evaluation,
          setup: const ExamSetup(only: {2}),
        ),
      ),
    );
    expect(find.text('1/1 · 0 correct'), findsOneWidget);
    expect(find.text('Q2'), findsOneWidget);
  });

  testWidgets('a timed exam reveals nothing and ends when time is up', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    Get.put(ReadingSettingsController(await SharedPreferences.getInstance()));
    final history = FakeHistory();
    Get.put(SaveHistoryEntry(history));
    Get.put(ProgressController(await SharedPreferences.getInstance()));
    addTearDown(Get.reset);
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        for (var i = 1; i <= 2; i++)
          Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
      ],
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExamPage(
          evaluation: evaluation,
          setup: const ExamSetup(perQuestion: Duration(seconds: 30)),
        ),
      ),
    );
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget); // no running score

    await tester.tap(find.text('a').first);
    await tester.pump();
    expect(find.text('Next'), findsOneWidget);

    // Reopened after the deadline: it ends right away.
    ProgressController.i.save(
      'exam',
      evaluation,
      evaluation.questions,
      1,
      0,
      true,
      const Duration(minutes: 1),
      DateTime.now().subtract(const Duration(seconds: 1)),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: ExamPage(key: UniqueKey(), evaluation: evaluation),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Time's up"), findsOneWidget);
    expect((history.entries.single as Attempt).total, 2);
  });

  testWidgets('the setup sheet builds a quick exam of learned questions', (
    tester,
  ) async {
    final evaluation = Evaluation(
      id: 'e',
      title: 'E',
      questions: [
        for (var i = 1; i <= 40; i++)
          Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
      ],
    );
    ExamSetup? setup;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => setup = await showExamSetup(
              context,
              evaluation,
              {for (var i = 1; i <= 15; i++) i},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Start · 40 questions'), findsOneWidget);

    await tester.tap(find.text('Quick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learned · 15'));
    await tester.pumpAndSettle();
    expect(find.text('Start · 15 questions'), findsOneWidget); // 20 > 15
    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start · 10 questions'));
    await tester.pumpAndSettle();

    expect(setup!.count, 10);
    expect(setup!.only, hasLength(15));
    expect(setup!.pick(evaluation).every((q) => q.id <= 15), isTrue);
  });
}
