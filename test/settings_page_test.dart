import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/usecases/clear_history.dart';
import 'package:evaluator/presentation/controllers/bookmarks_controller.dart';
import 'package:evaluator/presentation/controllers/highlights_controller.dart';
import 'package:evaluator/presentation/pages/settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_history.dart';

void main() {
  testWidgets('Memoria clears highlights, bookmarks and history separately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'bookmarks_a': ['1'],
      'highlights_a': '{"1":{"q":[[0,2,0]]}}',
      'theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    Get.put(BookmarksController(prefs));
    Get.put(HighlightsController(prefs));
    final history = FakeHistory()
      ..entries.add(Attempt('a', 'A', DateTime(2026), 1, 2));
    Get.put(ClearHistory(history));
    addTearDown(Get.reset);
    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));

    await tester.tap(find.text('Memoria'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Borrar resaltados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(prefs.getKeys(), {'bookmarks_a', 'theme_mode'});

    // Cancel keeps them.
    await tester.tap(find.text('Borrar preguntas guardadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(prefs.getKeys(), contains('bookmarks_a'));

    await tester.tap(find.text('Borrar preguntas guardadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(prefs.getKeys(), {'theme_mode'});

    await tester.tap(find.text('Borrar historial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(history.entries, isEmpty);
  });
}
