import '../entities/history_entry.dart';
import '../repositories/history_repository.dart';

class SaveHistoryEntry {
  final HistoryRepository _repository;

  const SaveHistoryEntry(this._repository);

  Future<void> call(HistoryEntry entry) => _repository.save(entry);
}
