import '../entities/attempt.dart';
import '../repositories/history_repository.dart';

class SaveAttempt {
  final HistoryRepository _repository;

  const SaveAttempt(this._repository);

  Future<void> call(String evaluationId, Attempt attempt) =>
      _repository.save(evaluationId, attempt);
}
