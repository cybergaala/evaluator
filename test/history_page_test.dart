import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/usecases/get_history.dart';
import 'package:evaluator/presentation/pages/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'fake_history.dart';

void main() {
  testWidgets('loads the next page at the end of the list', (tester) async {
    final history = FakeHistory();
    for (var i = 0; i < 35; i++) {
      history.entries.add(
        i.isEven
            ? Attempt('a', 'Bank $i', DateTime(2026, 1, 1, 0, i), 1, 2)
            : StudySession(
                'a',
                'Bank $i',
                DateTime(2026),
                Duration(minutes: i),
              ),
      );
    }
    Get.put(GetHistory(history));
    addTearDown(Get.reset);
    await tester.pumpWidget(const MaterialApp(home: HistoryPage()));
    await tester.pumpAndSettle();

    // Newest first.
    expect(find.text('Bank 34'), findsOneWidget);
    expect(find.textContaining('Evaluación · 1/2 · 50%'), findsWidgets);

    // Fling to the end until the oldest entry (only on page 2) shows up.
    await tester.scrollUntilVisible(
      find.text('Bank 0'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bank 0'), findsOneWidget);
  });

  testWidgets('pull to refresh opens under the AppBar', (tester) async {
    Get.put(GetHistory(FakeHistory()));
    addTearDown(Get.reset);
    await tester.pumpWidget(const MaterialApp(home: HistoryPage()));
    await tester.pumpAndSettle();

    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    // Empty history ends in noMore, so look for the header's time message.
    final header = find.textContaining('Actualizado a las');
    expect(header, findsOneWidget);
    expect(tester.getRect(header).top, greaterThanOrEqualTo(appBarBottom));
    // The AppBar stays still (clamping).
    expect(tester.getRect(find.byType(AppBar)).bottom, appBarBottom);
    await gesture.up();
    // Let the refresh finish and its "Listo" timer run out.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 5));
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 45)), '45 s');
    expect(formatDuration(const Duration(minutes: 12)), '12 min');
    expect(formatDuration(const Duration(minutes: 65)), '1 h 5 min');
  });
}
