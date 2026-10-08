import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/repositories/history_repository.dart';

/// History in SQLite, so the history tab reads one indexed page at a time
/// instead of loading everything.
class SqliteHistoryRepository implements HistoryRepository {
  final Database _db;

  const SqliteHistoryRepository(this._db);

  static Future<SqliteHistoryRepository> open([String? path]) async {
    final db = await openDatabase(
      path ?? join(await getDatabasesPath(), 'evaluator.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kind TEXT NOT NULL,
            evaluation_id TEXT NOT NULL,
            evaluation_title TEXT NOT NULL,
            date INTEGER NOT NULL,
            correct INTEGER,
            total INTEGER,
            duration_ms INTEGER
          )''');
        await db.execute('CREATE INDEX history_date ON history (date)');
        await db.execute(
          'CREATE INDEX history_attempts ON history (evaluation_id, kind, date)',
        );
      },
    );
    return SqliteHistoryRepository(db);
  }

  static HistoryEntry _fromRow(Map<String, Object?> r) {
    final id = r['evaluation_id'] as String;
    final title = r['evaluation_title'] as String;
    final date = DateTime.fromMillisecondsSinceEpoch(r['date'] as int);
    return r['kind'] == 'study'
        ? StudySession(
            id,
            title,
            date,
            Duration(milliseconds: r['duration_ms'] as int),
          )
        : Attempt(id, title, date, r['correct'] as int, r['total'] as int);
  }

  @override
  Future<List<HistoryEntry>> page({
    required int offset,
    required int limit,
  }) async => [
    for (final r in await _db.query(
      'history',
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    ))
      _fromRow(r),
  ];

  @override
  Future<List<Attempt>> attempts(
    String evaluationId, {
    required int limit,
  }) async => [
    for (final r in await _db.query(
      'history',
      where: "evaluation_id = ? AND kind = 'exam'",
      whereArgs: [evaluationId],
      orderBy: 'date DESC, id DESC',
      limit: limit,
    ))
      _fromRow(r) as Attempt,
  ];

  @override
  Future<void> save(HistoryEntry entry) => _db.insert('history', {
    'evaluation_id': entry.evaluationId,
    'evaluation_title': entry.evaluationTitle,
    'date': entry.date.millisecondsSinceEpoch,
    ...switch (entry) {
      StudySession(:final duration) => {
        'kind': 'study',
        'duration_ms': duration.inMilliseconds,
      },
      Attempt(:final correct, :final total) => {
        'kind': 'exam',
        'correct': correct,
        'total': total,
      },
    },
  });

  @override
  Future<void> clear() => _db.delete('history');
}
