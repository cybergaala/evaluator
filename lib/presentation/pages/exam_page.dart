import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/save_history_entry.dart';
import '../controllers/reading_settings_controller.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/question_card.dart';
import '../widgets/reading_settings_panel.dart';

class ExamPage extends StatefulWidget {
  final Evaluation evaluation;

  const ExamPage({super.key, required this.evaluation});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final _save = Get.find<SaveHistoryEntry>();
  final _settings = ReadingSettingsController.i;
  final _pageController = PageController();
  late List<Question> _questions = _prepare();
  int _index = 0;
  final Set<int> _selected = {};
  int _correct = 0;
  bool _finished = false;

  Question get _current => _questions[_index];
  bool get _answered => _selected.length == _current.answers.length;
  bool get _revealed => _answered && !_settings.revealAtEnd.value;

  List<Question> _prepare() =>
      _settings.prepare(widget.evaluation.questions, alwaysShuffle: true);

  Attempt _attempt() => Attempt(
    widget.evaluation.id,
    widget.evaluation.title,
    DateTime.now(),
    _correct,
    _questions.length,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int option) {
    if (_revealed) return;
    setState(() {
      // Tapping a selected option again unselects it (matters for multi-answer).
      if (_selected.remove(option)) return;
      if (_answered) {
        // Only reachable with "revelar al final": swap a single answer, and
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
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Counts the current question if answered; the rest count as wrong.
  Future<void> _finish() async {
    if (_answered && _current.isCorrect(_selected)) _correct++;
    await _save(_attempt());
    setState(() => _finished = true);
  }

  Future<void> _confirmFinish() async {
    final left = _questions.length - _index - (_answered ? 1 : 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Finalizar evaluación?'),
        content: Text(
          left == 0
              ? 'Se guardará tu resultado.'
              : 'Quedan $left sin responder; cuentan como incorrectas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  void _restart() {
    setState(() {
      _questions = _prepare();
      _index = 0;
      _selected.clear();
      _correct = 0;
      _finished = false;
    });
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
        message: 'Perderás el progreso de esta evaluación.',
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _finished
                  ? widget.evaluation.title
                  : [
                      '${_index + 1}/${_questions.length}',
                      if (!_settings.revealAtEnd.value) '$_correct correctas',
                    ].join(' · '),
            ),
            actions: [
              if (!_finished) ...[
                IconButton(
                  tooltip: 'Tamaño de texto',
                  onPressed: () => ReadingSettingsPanel.showSheet(
                    context,
                    textSizeOnly: true,
                  ),
                  icon: const Icon(Icons.format_size),
                ),
                IconButton(
                  tooltip: 'Finalizar evaluación',
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
          footer: q == _current && _answered
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(isLast ? Icons.flag : Icons.arrow_forward),
                    label: Text(isLast ? 'Ver resultado' : 'Siguiente'),
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
          Text('${attempt.percent}%', style: textTheme.displayLarge),
          Text(
            '$_correct de ${_questions.length} correctas',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.replay),
            label: const Text('Reintentar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
