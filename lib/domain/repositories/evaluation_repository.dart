import '../entities/evaluation.dart';

abstract interface class EvaluationRepository {
  Future<List<Evaluation>> getAll();
}
