import '../entities/history_entry.dart';
import '../repositories/history_repository.dart';

class GetAttempts {
  final HistoryRepository _repository;

  const GetAttempts(this._repository);

  Future<List<Attempt>> call(String evaluationId, {required int limit}) =>
      _repository.attempts(evaluationId, limit: limit);
}
