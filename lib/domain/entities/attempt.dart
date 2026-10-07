class Attempt {
  final DateTime date;
  final int correct;
  final int total;

  const Attempt(this.date, this.correct, this.total);

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();
}
