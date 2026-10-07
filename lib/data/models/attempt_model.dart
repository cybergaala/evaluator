import '../../domain/entities/attempt.dart';

class AttemptModel extends Attempt {
  const AttemptModel(super.date, super.correct, super.total);

  factory AttemptModel.fromEntity(Attempt a) =>
      AttemptModel(a.date, a.correct, a.total);

  factory AttemptModel.fromJson(Map<String, dynamic> json) => AttemptModel(
    DateTime.parse(json['date'] as String),
    json['correct'] as int,
    json['total'] as int,
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'correct': correct,
    'total': total,
  };
}
