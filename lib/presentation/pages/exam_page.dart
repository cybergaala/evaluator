import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/attempt.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/save_attempt.dart';
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
  final _saveAttempt = Get.find<SaveAttempt>();
  final _settings = ReadingSettingsController.i;
  final _pageController = PageController();
  late List<Question> _questions = _settings.prepare(
    widget.evaluation.questions,
  );
  int _index = 0;
  final Set<int> _selected = {};
  int _correct = 0;
  bool _finished = false;

  Question get _current => _questions[_index];
  bool get _answered => _selected.length == _current.answers.length;
  bool get _revealed => _answered && !_settings.revealAtEnd.value;

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
    if (_current.isCorrect(_selected)) _correct++;
    if (_index == _questions.length - 1) {
      await _saveAttempt(
        widget.evaluation.id,
        Attempt(DateTime.now(), _correct, _questions.length),
      );
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected.clear();
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _restart() {
    setState(() {
      _questions = _settings.prepare(widget.evaluation.questions);
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
              IconButton(
                tooltip: 'Ajustes de lectura',
                onPressed: () => ReadingSettingsPanel.showSheet(context),
                icon: const Icon(Icons.tune),
              ),
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
    final attempt = Attempt(DateTime.now(), _correct, _questions.length);
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
