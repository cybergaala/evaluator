import '../entities/history_entry.dart';

abstract interface class HistoryRepository {
  /// Every entry, newest first, one page at a time.
  Future<List<HistoryEntry>> page({required int offset, required int limit});

  /// Exam attempts of one evaluation, newest first.
  Future<List<Attempt>> attempts(String evaluationId, {required int limit});

  Future<void> save(HistoryEntry entry);

  Future<void> clear();
}
