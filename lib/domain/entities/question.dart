import 'dart:math';

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

  /// Same question with its options in random order; [answers] follow them.
  Question withShuffledOptions(Random random) =>
      withOptionOrder(List.generate(options.length, (i) => i)..shuffle(random));

  /// Same question showing `options[order[0]], options[order[1]], …`.
  Question withOptionOrder(List<int> order) {
    return Question(
      id: id,
      question: question,
      options: [for (final i in order) options[i]],
      answers: [for (final a in answers) order.indexOf(a)],
      explanation: explanation,
    );
  }
}
