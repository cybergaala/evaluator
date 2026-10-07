import '../entities/attempt.dart';
import '../repositories/history_repository.dart';

class GetHistory {
  final HistoryRepository _repository;

  const GetHistory(this._repository);

  Future<List<Attempt>> call(String evaluationId) =>
      _repository.getAll(evaluationId);
}
