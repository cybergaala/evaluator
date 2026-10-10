import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/save_history_entry.dart';
import '../controllers/progress_controller.dart';
import '../controllers/reading_settings_controller.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/question_card.dart';
import '../widgets/reading_settings_panel.dart';

/// How a new exam picks its questions; the default is every question,
/// shuffled, untimed.
class ExamSetup {
  /// Ids of the questions to draw from ("Learned only"); all when null.
  final Set<int>? only;

  /// Shuffles questions and options; otherwise the bank's order.
  final bool shuffle;

  /// Asks only this many (drawn at random when shuffled); all when null.
  final int? count;

  /// Time per question; the exam is timed when set.
  final Duration? perQuestion;

  const ExamSetup({
    this.only,
    this.shuffle = true,
    this.count,
    this.perQuestion,
  });

  List<Question> pick(Evaluation evaluation) {
    final random = Random();
    final pool = [
      for (final q in evaluation.questions)
        if (only?.contains(q.id) ?? true)
          shuffle ? q.withShuffledOptions(random) : q,
    ];
    if (shuffle) pool.shuffle(random);
    return pool.take(count ?? pool.length).toList();
  }
}

class ExamPage extends StatefulWidget {
  final Evaluation evaluation;

  /// For a new exam; ignored when there is a saved session to resume.
  final ExamSetup setup;

  const ExamPage({
    super.key,
    required this.evaluation,
    this.setup = const ExamSetup(),
  });

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final _save = Get.find<SaveHistoryEntry>();
  final _settings = ReadingSettingsController.i;
  final _progress = ProgressController.i;
  late final _saved = _progress.load('exam', widget.evaluation);
  late List<Question> _questions =
      _saved?.questions ?? widget.setup.pick(widget.evaluation);
  late final bool _shuffle = _saved?.shuffle ?? widget.setup.shuffle;
  late final Duration? _limit =
      _saved?.limit ??
      switch (widget.setup.perQuestion) {
        final d? => d * _questions.length,
        _ => null,
      };
  late DateTime? _deadline = _saved?.deadline ?? _newDeadline();
  Timer? _clock;
  late int _index = _saved?.index ?? 0;
  late final _pageController = PageController(initialPage: _index);
  final Set<int> _selected = {};
  late int _correct = _saved?.correct ?? 0;
  bool _finished = false;
  bool _timeUp = false;

  Question get _current => _questions[_index];
  bool get _answered => _selected.length == _current.answers.length;

  /// A timed exam is a simulation: nothing is revealed until the end.
  bool get _revealAtEnd => _limit != null || _settings.revealAtEnd.value;
  bool get _revealed => _answered && !_revealAtEnd;

  DateTime? _newDeadline() =>
      _limit == null ? null : DateTime.now().add(_limit);

  Duration get _remaining => _deadline!.difference(DateTime.now());

  /// Ticks every second while timed; the clock keeps running while the app
  /// is in the background or the exam is closed, like a real exam.
  void _startClock() {
    _clock?.cancel();
    if (_deadline == null) return;
    void tick() {
      if (_finished) return _clock?.cancel();
      if (_remaining > Duration.zero) return setState(() {});
      _timeUp = true;
      _finish();
    }

    _clock = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    // A resumed exam whose time is already over ends right away.
    if (_remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tick());
    }
  }

  Attempt _attempt() => Attempt(
    widget.evaluation.id,
    widget.evaluation.title,
    DateTime.now(),
    _correct,
    _questions.length,
  );

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _select(int option) {
    if (_revealed) return;
    setState(() {
      // Tapping a selected option again unselects it (matters for multi-answer).
      if (_selected.remove(option)) return;
      if (_answered) {
        // Only reachable with "Reveal at the end": swap a single answer, and
        // ignore extra taps on multi-answer questions.
        if (_current.answers.length > 1) return;
        _selected.clear();
      }
      _selected.add(option);
    });
  }

  Future<void> _next() async {
    if (_index == _questions.length - 1) return _finish();
    if (_current.isCorrect(_selected)) _correct++;
    setState(() {
      _index++;
      _selected.clear();
    });
    // ponytail: saved per answered question; picks on the current one are lost.
    _progress.save(
      'exam',
      widget.evaluation,
      _questions,
      _index,
      _correct,
      _shuffle,
      _limit,
      _deadline,
    );
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Counts the current question if answered; the rest count as wrong.
  Future<void> _finish() async {
    if (_finished) return;
    _clock?.cancel();
    if (_answered && _current.isCorrect(_selected)) _correct++;
    _progress.clear('exam', widget.evaluation.id);
    await _save(_attempt());
    setState(() => _finished = true);
  }

  Future<void> _confirmFinish() async {
    final left = _questions.length - _index - (_answered ? 1 : 0);
    final ok = await showConfirmDialog(
      context,
      icon: Icons.flag_rounded,
      title: 'Finish exam?',
      message: left == 0
          ? 'Your score will be saved.'
          : '$left left unanswered; they count as wrong.',
      confirm: 'Finish',
    );
    if (ok) await _finish();
  }

  /// The same questions again, reshuffled when the exam was shuffled.
  void _restart() {
    final random = Random();
    setState(() {
      if (_shuffle) {
        _questions = [for (final q in _questions) q.withShuffledOptions(random)]
          ..shuffle(random);
      }
      _index = 0;
      _selected.clear();
      _correct = 0;
      _finished = false;
      _timeUp = false;
      _deadline = _newDeadline();
    });
    _startClock();
    // PageView is rebuilt fresh after the result screen, so no jump needed.
  }

  OptionState _stateFor(Question q, int i) {
    if (q != _current) return OptionState.neutral;
    if (!_revealed) {
      return _selected.contains(i) ? OptionState.selected : OptionState.neutral;
    }
    if (q.answers.contains(i)) return OptionState.correct;
    return _selected.contains(i) ? OptionState.wrong : OptionState.neutral;
  }

  @override
  Widget build(BuildContext context) {
    // Obx: settings changed from the sheet apply right away.
    return Obx(
      () => ConfirmExit(
        enabled: !_finished,
        title: 'Leave the exam?',
        message: 'You can continue where you left off.',
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _finished
                  ? widget.evaluation.title
                  : [
                      '${_index + 1}/${_questions.length}',
                      if (!_revealAtEnd) '$_correct correct',
                    ].join(' · '),
            ),
            actions: [
              if (!_finished) ...[
                if (_deadline != null) _ClockChip(_remaining),
                IconButton(
                  tooltip: 'Text size',
                  onPressed: () => ReadingSettingsPanel.showSheet(
                    context,
                    textSizeOnly: true,
                  ),
                  icon: const Icon(Icons.format_size),
                ),
                IconButton(
                  tooltip: 'Finish exam',
                  onPressed: _confirmFinish,
                  icon: const Icon(Icons.flag),
                ),
              ],
            ],
          ),
          body: SafeArea(
            top: false,
            child: _finished ? _result(context) : _exam(),
          ),
        ),
      ),
    );
  }

  Widget _exam() {
    final isLast = _index == _questions.length - 1;
    // Read here: itemBuilder runs lazily, outside Obx's tracking.
    final textScale = _settings.textScale.value;
    final justify = _settings.justify.value;
    final revealed = _revealed;
    return PageView.builder(
      controller: _pageController,
      scrollDirection: _settings.axis,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return QuestionCard(
          question: q,
          optionState: (i) => _stateFor(q, i),
          onTap: _select,
          showExplanation: q == _current && revealed,
          textScale: textScale,
          justify: justify,
          footer: q == _current && _answered
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(isLast ? Icons.flag : Icons.arrow_forward),
                    label: Text(isLast ? 'See result' : 'Next'),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _result(BuildContext context) {
    final attempt = _attempt();
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_timeUp)
            Chip(
              avatar: const Icon(Icons.timer_off_outlined),
              label: const Text("Time's up"),
            ),
          Text('${attempt.percent}%', style: textTheme.displayLarge),
          Text(
            '$_correct of ${_questions.length} correct',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }
}

/// The time left in a timed exam, turning to the error color in the last
/// five minutes.
class _ClockChip extends StatelessWidget {
  final Duration remaining;

  const _ClockChip(this.remaining);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Rounded up, so it shows 0:00 only when time is up.
    final left = Duration(
      seconds: max(0, (remaining.inMilliseconds / 1000).ceil()),
    );
    final low = left < const Duration(minutes: 5);
    String two(int n) => n.toString().padLeft(2, '0');
    final text = [
      if (left.inHours > 0) '${left.inHours}',
      two(left.inMinutes % 60),
      two(left.inSeconds % 60),
    ].join(':');
    return Tooltip(
      message: 'Time left',
      child: Chip(
        avatar: Icon(
          Icons.timer_outlined,
          color: low ? scheme.onErrorContainer : null,
        ),
        label: Text(
          text,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: low ? scheme.onErrorContainer : null,
          ),
        ),
        backgroundColor: low ? scheme.errorContainer : null,
        side: low ? BorderSide.none : null,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
