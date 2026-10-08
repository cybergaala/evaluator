import 'package:flutter/material.dart';

import '../../domain/entities/question.dart';

enum OptionState { neutral, selected, correct, wrong }

/// One question with its options; shared by study and exam modes.
class QuestionCard extends StatelessWidget {
  final Question question;
  final OptionState Function(int index) optionState;
  final ValueChanged<int>? onTap;
  final bool showExplanation;
  final Widget? footer;
  final double textScale;

  const QuestionCard({
    super.key,
    required this.question,
    required this.optionState,
    this.onTap,
    this.showExplanation = false,
    this.footer,
    this.textScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Multiplies the system text scale, so accessibility settings still count.
    final scaler = TextScaler.linear(
      MediaQuery.textScalerOf(context).scale(textScale),
    );
    return Card(
      margin: const EdgeInsets.all(16),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: ListView(
          // Not primary: only grabs drags when the content overflows, so the
          // study PageView can swipe between cards.
          primary: false,
          // Clamping on every platform, so reaching an edge emits
          // OverscrollNotification (study page hands it to the pager).
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(question.question, style: theme.textTheme.titleLarge),
            if (question.isMultiAnswer)
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
