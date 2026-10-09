import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/domain/usecases/save_history_entry.dart';
import 'package:evaluator/presentation/controllers/bookmarks_controller.dart';
import 'package:evaluator/presentation/controllers/highlights_controller.dart';
import 'package:evaluator/presentation/controllers/progress_controller.dart';
import 'package:evaluator/presentation/controllers/reading_settings_controller.dart';
import 'package:evaluator/presentation/pages/study_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_history.dart';

final evaluation = Evaluation(
  id: 'e',
  title: 'E',
  questions: [
    for (var i = 1; i <= 3; i++)
      Question(id: i, question: 'Q$i', options: ['a', 'b'], answers: [0]),
  ],
);

Future<ReadingSettingsController> setUpControllers() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put(BookmarksController(prefs));
  Get.put(LearnedController(prefs));
  Get.put(HighlightsController(prefs));
  Get.put(ProgressController(prefs));
  Get.put(SaveHistoryEntry(FakeHistory()));
  // Typed: inside an async return, Get.put would infer FutureOr<...>.
  return Get.put<ReadingSettingsController>(ReadingSettingsController(prefs));
}

void main() {
  testWidgets('swiping the card changes page in both directions', (
    tester,
  ) async {
    final settings = await setUpControllers();
    addTearDown(Get.reset);
    await tester.pumpWidget(
      MaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    // Vertical (default).
    await tester.drag(find.text('Q1'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    // The zigzag above Q2 sits outside the pager once the page settles.
    final zigzag = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Zigzag',
    );
    expect(
      tester.getRect(zigzag.first).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(PageView)).top),
    );

    // Horizontal.
    settings.vertical.value = false;
    await tester.pumpAndSettle();
    await tester.drag(find.text('Q2'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('a long card hands the drag to the pager at its end', (
    tester,
  ) async {
    await setUpControllers();
    addTearDown(Get.reset);
    final long = Evaluation(
      id: 'l',
      title: 'L',
      questions: [
        for (var i = 1; i <= 2; i++)
          Question(
            id: i,
            question: 'Q$i ${'long text ' * 300}',
            options: ['a', 'b'],
            answers: [0],
          ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: StudyPage(evaluation: long)));

    // Drag the card to its end and a bit past it, then hold still: the
    // pager keeps its offset instead of springing back.
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SingleChildScrollView).first),
    );
    for (var i = 0; i < 40; i++) {
      await gesture.moveBy(const Offset(0, -500));
      await tester.pump();
    }
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    final held = pager.page!;
    expect(held, greaterThan(0));
    await tester.pump(const Duration(seconds: 1));
    expect(pager.page, held);

    // Release past the middle: it snaps to the next question.
    await gesture.moveBy(const Offset(0, -400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);

    // Back up: card 2 hands over at its start, and card 1 comes back opened
    // at its end (reversed scroll), so the drag keeps paging back.
    final back = await tester.startGesture(
      tester.getCenter(find.byType(SingleChildScrollView).last),
    );
    for (var i = 0; i < 4; i++) {
      await back.moveBy(const Offset(0, 300));
      await tester.pump();
    }
    await back.up();
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    final card1 = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(card1.reverse, isTrue);
  });

  testWidgets('a swipe right after a page snaps scrolls the new card', (
    tester,
  ) async {
    await setUpControllers();
    addTearDown(Get.reset);
    final ev = Evaluation(
      id: 's',
      title: 'S',
      questions: [
        Question(id: 1, question: 'Q1', options: ['a', 'b'], answers: [0]),
        Question(
          id: 2,
          question: 'Q2 ${'long text ' * 300}',
          options: ['a', 'b'],
          answers: [0],
        ),
        Question(id: 3, question: 'Q3', options: ['a', 'b'], answers: [0]),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: StudyPage(evaluation: ev)));
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;

    await tester.fling(find.text('Q1'), const Offset(0, -300), 2000);
    // Looks settled, but the default spring was still crawling here, and
    // while it animates the pager keeps touches from the cards.
    await tester.pump(); // starts the snap animation's clock
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(PageView), const Offset(0, -300));
    await tester.pump();
    expect(pager.page, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('slider jumps and bookmarks persist', (tester) async {
    await setUpControllers();
    addTearDown(Get.reset);
    await tester.pumpWidget(
      GetMaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    // Slider end = last question.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    // Save from the AppBar.
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quitar de guardadas'), findsOneWidget);
    expect(BookmarksController.i.of('e'), {3});

    // Jump back to Q1, then open the list and pick the bookmark.
    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    await tester.tap(find.textContaining('Guardadas ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q3').last);
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    // Remove it from the list's trailing action.
    await tester.tap(find.textContaining('Guardadas ('));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin preguntas guardadas'), findsOneWidget);
    expect(BookmarksController.i.of('e'), isEmpty);
  });
  testWidgets('marker mode paints the selection and persists it', (
    tester,
  ) async {
    await setUpControllers();
    addTearDown(Get.reset);
    await tester.pumpWidget(
      GetMaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    await tester.tap(find.byTooltip('Resaltar texto'));
    await tester.pumpAndSettle();
    // Long press on the word (the text box is full width) selects it, then
    // the toolbar shows the colors.
    await tester.longPressAt(
      tester.getTopLeft(find.text('Q1')) + const Offset(5, 5),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Resaltar').first);
    await tester.pumpAndSettle();
    expect(HighlightsController.i.of('e', 1, 'q'), [(0, 2, 0)]);

    // Erase it again.
    await tester.longPressAt(
      tester.getTopLeft(find.text('Q1')) + const Offset(5, 5),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Borrar resaltado'));
    await tester.pumpAndSettle();
    expect(HighlightsController.i.of('e', 1, 'q'), isEmpty);
  });

  testWidgets('hide answers, search, only bookmarked and highlighted list', (
    tester,
  ) async {
    final settings = await setUpControllers();
    addTearDown(Get.reset);
    settings.hideAnswers.value = true;
    BookmarksController.i.toggle('e', 2);
    HighlightsController.i.paint('e', 3, 'q', 0, 1, 0);
    await tester.pumpWidget(
      GetMaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    // Hidden until "Mostrar respuesta".
    expect(find.text('Mostrar respuesta'), findsOneWidget);
    await tester.tap(find.text('Mostrar respuesta'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrar respuesta'), findsNothing);

    // Search by text.
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'q3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Q3').last);
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    // Highlighted list shows Q3.
    await tester.tap(find.text('Resaltadas'));
    await tester.pumpAndSettle();
    expect(find.text('Q3'), findsNWidgets(2));

    // Only bookmarked: one page, the bookmarked Q2.
    await tester.tap(find.textContaining('Guardadas ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estudiar solo guardadas'));
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Q2'), findsNWidgets(2));
  });

  testWidgets('learned questions are hidden by default', (tester) async {
    await setUpControllers();
    addTearDown(Get.reset);
    LearnedController.i.toggle('e', 1);
    await tester.pumpWidget(
      GetMaterialApp(home: StudyPage(evaluation: evaluation)),
    );

    // Q1 is learned: the session starts at Q2, out of 2.
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Q2'), findsOneWidget);

    // Mark Q2 from the AppBar; it stays until the next session.
    await tester.tap(find.byTooltip('Marcar como aprendida'));
    await tester.pumpAndSettle();
    expect(LearnedController.i.of('e'), {1, 2});
    expect(find.text('1/2'), findsOneWidget);
    // The SnackBar covers the sheet's tabs.
    ScaffoldMessenger.of(tester.element(find.text('Q2')))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // "Mostrar aprendidas" brings them back, keeping Q2 on screen.
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar aprendidas'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });
}
