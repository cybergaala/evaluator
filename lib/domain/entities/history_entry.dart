/// One row of the history: a study session or an exam attempt.
///
/// Keeps the evaluation title so the history tab doesn't load the banks and
/// rows keep a name after a bank is removed.
sealed class HistoryEntry {
  final String evaluationId;
  final String evaluationTitle;
  final DateTime date;

  const HistoryEntry(this.evaluationId, this.evaluationTitle, this.date);
}

/// Time spent in study mode.
class StudySession extends HistoryEntry {
  final Duration duration;

  const StudySession(
    super.evaluationId,
    super.evaluationTitle,
    super.date,
    this.duration,
  );
}

/// Score of a finished exam.
class Attempt extends HistoryEntry {
  final int correct;
  final int total;

  const Attempt(
    super.evaluationId,
    super.evaluationTitle,
    super.date,
    this.correct,
    this.total,
  );

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();
}
