import 'package:evaluator/data/repositories/sqlite_history_repository.dart';
import 'package:evaluator/domain/entities/evaluation.dart';
import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/repositories/evaluation_repository.dart';
import 'package:evaluator/injection.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _OneEvaluation implements EvaluationRepository {
  @override
  Future<List<Evaluation>> getAll() async => [
    const Evaluation(id: 'a', title: 'A', questions: []),
  ];
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('pages newest first, filters attempts, clears', () async {
    final repo = await SqliteHistoryRepository.open(inMemoryDatabasePath);
    final start = DateTime(2026);
    for (var i = 0; i < 45; i++) {
      final date = start.add(Duration(minutes: i));
      await repo.save(
        i.isEven
            ? Attempt('a', 'A', date, i, 50)
            : StudySession('b', 'B', date, Duration(seconds: i)),
      );
    }

    final first = await repo.page(offset: 0, limit: 30);
    final second = await repo.page(offset: 30, limit: 30);
    expect(first.length, 30);
    expect(second.length, 15);
    expect(first.first.date, start.add(const Duration(minutes: 44)));
    expect(second.last.date, start);
    // Both kinds come back with their own fields (i = 14, then 13).
    expect((second[0] as Attempt).correct, 14);
    expect((second[1] as StudySession).duration, const Duration(seconds: 13));

    final attempts = await repo.attempts('a', limit: 100);
    expect(attempts.length, 23);
    expect(attempts.first.correct, 44);
    expect(await repo.attempts('b', limit: 100), isEmpty);

    await repo.clear();
    expect(await repo.page(offset: 0, limit: 30), isEmpty);
  });

  test('moves the old shared_preferences history once', () async {
    SharedPreferences.setMockInitialValues({
      'history_a': ['{"date":"2026-01-01T10:00:00.000","correct":3,"total":4}'],
      'history_gone': [
        '{"date":"2026-01-02T10:00:00.000","correct":1,"total":2}',
      ],
      'theme_mode': 'dark',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = await SqliteHistoryRepository.open(inMemoryDatabasePath);

    await migratePrefsHistory(prefs, repo, _OneEvaluation());
    await migratePrefsHistory(prefs, repo, _OneEvaluation()); // no-op

    final all = await repo.page(offset: 0, limit: 10);
    expect(all.length, 2);
    // Unknown bank keeps its id as the title.
    expect(all.map((e) => e.evaluationTitle), ['gone', 'A']);
    expect((all.last as Attempt).correct, 3);
    expect(prefs.getKeys(), {'theme_mode'});
  });
}
