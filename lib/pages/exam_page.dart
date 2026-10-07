import 'package:flutter/material.dart';

import '../models.dart';
import 'study_page.dart';

class ExamPage extends StatefulWidget {
  final Evaluation evaluation;

  const ExamPage({super.key, required this.evaluation});

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  final _pageController = PageController();
  int _index = 0;
  final Set<int> _selected = {};
  int _correct = 0;
  bool _finished = false;

  List<Question> get _questions => widget.evaluation.questions;
  Question get _current => _questions[_index];
  bool get _revealed => _selected.length == _current.answers.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int option) {
    if (_revealed) return;
    setState(() {
      // Tapping a selected option again unselects it (matters for multi-answer).
      if (!_selected.remove(option)) _selected.add(option);
      if (_revealed && _selected.every(_current.answers.contains)) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index == _questions.length - 1) {
      await saveAttempt(
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _finished
              ? widget.evaluation.title
              : '${_index + 1}/${_questions.length} · $_correct correctas',
        ),
      ),
      body: _finished ? _result(context) : _exam(),
    );
  }

  Widget _exam() {
    final isLast = _index == _questions.length - 1;
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final q = _questions[index];
        return QuestionCard(
          question: q,
          optionState: (i) => _stateFor(q, i),
          onTap: _select,
          showExplanation: q == _current && _revealed,
          footer: q == _current && _revealed
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
