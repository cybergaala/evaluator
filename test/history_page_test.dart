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

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 45)), '45 s');
    expect(formatDuration(const Duration(minutes: 12)), '12 min');
    expect(formatDuration(const Duration(minutes: 65)), '1 h 5 min');
  });
}
