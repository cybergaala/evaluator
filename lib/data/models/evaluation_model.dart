import '../../domain/entities/evaluation.dart';
import '../../domain/entities/question.dart';

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.question,
    required super.options,
    required super.answers,
    super.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
    id: json['id'] as int,
    question: json['question'] as String,
    options: List<String>.from(json['options'] as List),
    answers: List<int>.from(json['answers'] as List),
    explanation: json['explanation'] as String?,
  );
}

class EvaluationModel extends Evaluation {
  const EvaluationModel({
    required super.id,
    required super.title,
    super.description,
    required super.questions,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) =>
      EvaluationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        questions: [
          for (final q in json['questions'] as List)
            QuestionModel.fromJson(q as Map<String, dynamic>),
        ],
      );
}
