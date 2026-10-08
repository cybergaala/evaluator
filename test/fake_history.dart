import 'package:evaluator/domain/entities/history_entry.dart';
import 'package:evaluator/domain/repositories/history_repository.dart';

/// In-memory [HistoryRepository] for widget tests.
class FakeHistory implements HistoryRepository {
  final entries = <HistoryEntry>[];

  @override
  Future<List<HistoryEntry>> page({
    required int offset,
    required int limit,
  }) async => entries.reversed.skip(offset).take(limit).toList();

  @override
  Future<List<Attempt>> attempts(
    String evaluationId, {
    required int limit,
  }) async => entries.reversed
      .whereType<Attempt>()
      .where((a) => a.evaluationId == evaluationId)
      .take(limit)
      .toList();

  @override
  Future<void> save(HistoryEntry entry) async => entries.add(entry);

  @override
  Future<void> clear() async => entries.clear();
}
