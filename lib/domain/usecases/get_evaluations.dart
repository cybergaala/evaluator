import '../entities/evaluation.dart';
import '../repositories/evaluation_repository.dart';

class GetEvaluations {
  final EvaluationRepository _repository;

  const GetEvaluations(this._repository);

  Future<List<Evaluation>> call() => _repository.getAll();
}
