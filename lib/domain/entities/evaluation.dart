import 'question.dart';

class Evaluation {
  final String id;
  final String title;
  final String? description;
  final List<Question> questions;

  const Evaluation({
    required this.id,
    required this.title,
    this.description,
    required this.questions,
  });
}
