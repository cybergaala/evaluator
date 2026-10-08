import '../repositories/history_repository.dart';

class ClearHistory {
  final HistoryRepository _repository;

  const ClearHistory(this._repository);

  Future<void> call() => _repository.clear();
}
