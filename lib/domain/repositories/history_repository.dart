import '../entities/attempt.dart';

abstract interface class HistoryRepository {
  /// Newest first.
  Future<List<Attempt>> getAll(String evaluationId);

  Future<void> save(String evaluationId, Attempt attempt);
}
