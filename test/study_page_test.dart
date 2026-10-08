import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/question.dart';
import 'package:evaluator/domain/usecases/save_history_entry.dart';
import 'package:evaluator/presentation/controllers/bookmarks_controller.dart';
import 'package:evaluator/presentation/controllers/highlights_controller.dart';
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
  Get.put(HighlightsController(prefs));
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

    // One drag: first scrolls the card to its end, the rest moves the pager.
    await tester.drag(find.byType(ListView).first, const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
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
}
