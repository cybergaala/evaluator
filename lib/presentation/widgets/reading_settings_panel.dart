import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reading_settings_controller.dart';

/// Reading settings controls; shown in Ajustes → Evaluación and as a bottom sheet
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
            title: const Text('Tamaño de texto'),
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
            title: const Text('Alineación de texto'),
            trailing: _choice(
              value: s.justify,
              no: (Icons.format_align_left, 'Izquierda'),
              yes: (Icons.format_align_justify, 'Justificado'),
            ),
          ),
          if (!textSizeOnly) ...[
            ListTile(
              leading: const Icon(Icons.swipe),
              title: const Text('Desplazamiento'),
              trailing: _choice(
                value: s.vertical,
                no: (Icons.swap_horiz, 'Horizontal'),
                yes: (Icons.swap_vert, 'Vertical'),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.shuffle),
              title: const Text('Mezclar preguntas'),
              subtitle: const Text(
                'En modo estudio, al iniciar. La evaluación siempre mezcla',
              ),
              value: s.shuffleQuestions.value,
              onChanged: (v) => s.shuffleQuestions.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.low_priority),
              title: const Text('Mezclar opciones'),
              subtitle: const Text(
                'En modo estudio, al iniciar. La evaluación siempre mezcla',
              ),
              value: s.shuffleOptions.value,
              onChanged: (v) => s.shuffleOptions.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.quiz_outlined),
              title: const Text('Ocultar respuestas'),
              subtitle: const Text(
                'En modo estudio, hasta tocar una opción o Mostrar respuesta',
              ),
              value: s.hideAnswers.value,
              onChanged: (v) => s.hideAnswers.value = v,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.linear_scale),
              title: const Text('Barra de preguntas'),
              subtitle: const Text(
                'En modo estudio, para saltar entre preguntas',
              ),
              value: s.showSlider.value,
              onChanged: (v) => s.showSlider.value = v,
            ),
            if (showRevealAtEnd)
              SwitchListTile(
                secondary: const Icon(Icons.visibility_off),
                title: const Text('Revelar al final'),
                subtitle: const Text(
                  'En evaluación, los aciertos se ven solo en el resultado',
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
