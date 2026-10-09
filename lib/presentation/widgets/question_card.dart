import 'package:flutter/material.dart';

import '../../domain/entities/question.dart';

enum OptionState { neutral, selected, correct, wrong }

/// One question with its options, without a Card; shared by study and exam
/// modes.
class QuestionCard extends StatelessWidget {
  final Question question;
  final OptionState Function(int index) optionState;
  final ValueChanged<int>? onTap;
  final bool showExplanation;
  final Widget? footer;
  final double textScale;
  final bool justify;

  /// Extra blank space after the content (study mode's zigzag gap).
  final double bottomSpace;

  /// Builds each text (`field`: `q` question, `o<i>` option, `e`
  /// explanation). Defaults to plain [Text]; study mode passes a highlighter.
  final Widget Function(String field, String text, TextStyle? style)?
  textBuilder;

  const QuestionCard({
    super.key,
    required this.question,
    required this.optionState,
    this.onTap,
    this.showExplanation = false,
    this.footer,
    this.textScale = 1,
    this.justify = false,
    this.bottomSpace = 0,
    this.textBuilder,
  });

  // Alignment per text: ListTile's title DefaultTextStyle resets an outer one.
  Widget _text(String field, String text, [TextStyle? style]) =>
      DefaultTextStyle.merge(
        textAlign: justify ? TextAlign.justify : TextAlign.start,
        child:
            textBuilder?.call(field, text, style) ?? Text(text, style: style),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Multiplies the system text scale, so accessibility settings still count.
    final scaler = TextScaler.linear(
      MediaQuery.textScalerOf(context).scale(textScale),
    );
    // No Card: the text sits on the page background, with the full width.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      // No Android stretch effect: its shader distorts the text inside the
      // option boxes on a fast fling.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: ListView(
          // Saves the offset in the route's PageStorage, so a card scrolled
          // away and back (pager disposes it) reopens where it was left.
          key: PageStorageKey('question-${question.id}'),
          // Not primary: only grabs drags when the content overflows, so the
          // study PageView can swipe between cards.
          primary: false,
          // Clamping on every platform, so reaching an edge emits
          // OverscrollNotification (study page hands it to the pager).
          physics: const ClampingScrollPhysics(),
          // Left clears the option letters, which stick out of the tiles.
          padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + bottomSpace),
          children: [
            _text('q', question.question, theme.textTheme.bodyLarge),
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
                padding: const EdgeInsets.only(top: 40),
                // A big faded opening quote behind the start of the text.
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -4,
                      top: -20,
                      child: Text(
                        '\u201C',
                        style: TextStyle(
                          fontSize: 120,
                          height: 1,
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    _text(
                      'e',
                      question.explanation!,
                      theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ?footer,
          ],
        ),
      ),
    );
  }

  Widget _option(BuildContext context, int i, ColorScheme scheme) {
    // The color alone tells the state; no trailing icon, so the text is wider.
    final bg = switch (optionState(i)) {
      OptionState.neutral => null,
      OptionState.selected => scheme.secondaryContainer,
      OptionState.correct => Colors.green.withValues(alpha: 0.25),
      OptionState.wrong => Colors.red.withValues(alpha: 0.25),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // The letter sits on the left border, so the text gets the full width.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Own Material: ListTile paints its color and border on the nearest
          // one, and the page's doesn't follow when the question above changes
          // height.
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              tileColor: bg,
              // Left clears the letter.
              contentPadding: const EdgeInsets.only(left: 20, right: 12),
              title: _text('o$i', question.options[i]),
              onTap: onTap == null ? null : () => onTap!(i),
            ),
          ),
          Positioned(
            left: -14,
            top: 0,
            bottom: 0,
            // Taps on the letter still reach the tile.
            child: IgnorePointer(
              child: Center(
                child: CircleAvatar(
                  radius: 14,
                  child: Text(
                    String.fromCharCode(65 + i), // A, B, C...
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
