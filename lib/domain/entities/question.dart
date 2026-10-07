class Question {
  final int id;
  final String question;
  final List<String> options;
  final List<int> answers;
  final String? explanation;

  const Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answers,
    this.explanation,
  });

  bool get isMultiAnswer => answers.length > 1;

  /// Right only if exactly the correct options were picked.
  bool isCorrect(Set<int> selected) =>
      selected.length == answers.length && selected.every(answers.contains);
}
