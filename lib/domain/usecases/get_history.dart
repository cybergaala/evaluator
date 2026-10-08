import '../entities/history_entry.dart';
import '../repositories/history_repository.dart';

class GetHistory {
  final HistoryRepository _repository;

  const GetHistory(this._repository);

  Future<List<HistoryEntry>> call({required int offset, required int limit}) =>
      _repository.page(offset: offset, limit: limit);
}
