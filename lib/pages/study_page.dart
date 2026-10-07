import 'package:flutter/material.dart';

import '../models.dart';

// Based on flutter_easy_refresh v4 example: page/sample/page_view_page.dart
// ponytail: no EasyRefresh wrapper, a fixed question list has nothing to refresh or load.
class StudyPage extends StatefulWidget {
  final Evaluation evaluation;

  const StudyPage({super.key, required this.evaluation});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final _pageController = PageController();
  Axis _scrollDirection = Axis.vertical;
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.evaluation.questions;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_page + 1}/${questions.length}'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _scrollDirection = _scrollDirection == Axis.horizontal
                    ? Axis.vertical
                    : Axis.horizontal;
              });
            },
            icon: Icon(
              _scrollDirection == Axis.horizontal
                  ? Icons.horizontal_distribute
                  : Icons.vertical_distribute,
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: _scrollDirection,
        itemCount: questions.length,
        onPageChanged: (index) => setState(() => _page = index),
        itemBuilder: (context, index) {
          final q = questions[index];
          return QuestionCard(
            question: q,
            optionState: (i) => q.answers.contains(i)
                ? OptionState.correct
                : OptionState.neutral,
            showExplanation: true,
          );
        },
      ),
    );
  }
}

enum OptionState { neutral, selected, correct, wrong }

/// One question with its options; shared by study and exam modes.
class QuestionCard extends StatelessWidget {
  final Question question;
  final OptionState Function(int index) optionState;
  final ValueChanged<int>? onTap;
  final bool showExplanation;
  final Widget? footer;

  const QuestionCard({
    super.key,
    required this.question,
    required this.optionState,
    this.onTap,
    this.showExplanation = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final multi = question.answers.length > 1;
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(question.question, style: theme.textTheme.titleLarge),
          if (multi)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Selecciona ${question.answers.length} respuestas',
                style: theme.textTheme.labelMedium,
              ),
            ),
          const SizedBox(height: 20),
          for (var i = 0; i < question.options.length; i++)
            _option(context, i, scheme),
          if (showExplanation && question.explanation != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                question.explanation!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ?footer,
        ],
      ),
    );
  }

  Widget _option(BuildContext context, int i, ColorScheme scheme) {
    final state = optionState(i);
    final (Color? bg, IconData? icon) = switch (state) {
      OptionState.neutral => (null, null),
      OptionState.selected => (
        scheme.secondaryContainer,
        Icons.radio_button_checked,
      ),
      OptionState.correct => (
        Colors.green.withValues(alpha: 0.25),
        Icons.check_circle,
      ),
      OptionState.wrong => (Colors.red.withValues(alpha: 0.25), Icons.cancel),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        tileColor: bg,
        leading: CircleAvatar(
          radius: 14,
          child: Text(String.fromCharCode(65 + i)), // A, B, C...
        ),
        title: Text(question.options[i]),
        trailing: icon == null ? null : Icon(icon),
        onTap: onTap == null ? null : () => onTap!(i),
      ),
    );
  }
}
