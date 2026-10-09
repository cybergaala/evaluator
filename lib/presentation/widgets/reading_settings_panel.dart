import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reading_settings_controller.dart';

/// Reading settings controls; shown in Settings → Reading and as a bottom sheet
/// in study and evaluation modes.
class ReadingSettingsPanel extends StatelessWidget {
  /// Hidden in study mode, where answers are always shown.
  final bool showRevealAtEnd;

  /// Evaluation mode: only the text size and alignment can change there.
  final bool textSizeOnly;

  const ReadingSettingsPanel({
    super.key,
    this.showRevealAtEnd = true,
    this.textSizeOnly = false,
  });

  static void showSheet(
    BuildContext context, {
    bool showRevealAtEnd = true,
    bool textSizeOnly = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: ReadingSettingsPanel(
            showRevealAtEnd: showRevealAtEnd,
            textSizeOnly: textSizeOnly,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ReadingSettingsController.i;
    return Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.format_size),
            title: const Text('Text size'),
            trailing: Text('${(s.textScale.value * 100).round()}%'),
          ),
          Slider(
            value: s.textScale.value,
            min: 0.5,
            max: 1.6,
            divisions: 11,
            onChanged: (v) => s.textScale.value = v,
          ),
          ListTile(
            leading: const Icon(Icons.format_align_left),
            title: const Text('Text alignment'),
            trailing: _choice(
              value: s.justify,
              no: (Icons.format_align_left, 'Left'),
              yes: (Icons.format_align_justify, 'Justified'),
            ),
          ),
          if (!textSizeOnly) ...[
            ListTile(
              leading: const Icon(Icons.swipe),
              title: const Text('Paging'),
              trailing: _choice(
                value: s.vertical,
                no: (Icons.swap_horiz, 'Horizontal'),
                yes: (Icons.swap_vert, 'Vertical'),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.shuffle),
              title: const Text('Shuffle questions'),
              subtitle: const Text(
                'In study mode, on start. Exams always shuffle',
              ),
              value: s.shuffleQuestions.value,
              onChanged: (v) => s.shuffleQuestions.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.low_priority),
              title: const Text('Shuffle options'),
              subtitle: const Text(
                'In study mode, on start. Exams always shuffle',
              ),
              value: s.shuffleOptions.value,
              onChanged: (v) => s.shuffleOptions.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.quiz_outlined),
              title: const Text('Hide answers'),
              subtitle: const Text(
                'In study mode, until you tap an option or Show answer',
              ),
              value: s.hideAnswers.value,
              onChanged: (v) => s.hideAnswers.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.linear_scale),
              title: const Text('Question slider'),
              subtitle: const Text('In study mode, to jump between questions'),
              value: s.showSlider.value,
              onChanged: (v) => s.showSlider.value = v,
            ),
            if (showRevealAtEnd)
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('Reveal at the end'),
                subtitle: const Text(
                  'In exams, answers show only in the result',
                ),
                value: s.revealAtEnd.value,
                onChanged: (v) => s.revealAtEnd.value = v,
              ),
          ],
        ],
      ),
    );
  }

  /// Two-option segmented control (iOS-like) for a setting that is a choice
  /// rather than an on/off toggle.
  Widget _choice({
    required RxBool value,
    required (IconData, String) no,
    required (IconData, String) yes,
  }) => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: [
      for (final (v, (icon, label)) in [(false, no), (true, yes)])
        ButtonSegment(value: v, icon: Icon(icon), tooltip: label),
    ],
    selected: {value.value},
    onSelectionChanged: (v) => value.value = v.first,
  );
}
