import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/reading_settings_controller.dart';

/// Reading settings controls; shown in Ajustes → Evaluación and as a bottom sheet
/// in study and evaluation modes.
class ReadingSettingsPanel extends StatelessWidget {
  /// Hidden in study mode, where answers are always shown.
  final bool showRevealAtEnd;

  const ReadingSettingsPanel({super.key, this.showRevealAtEnd = true});

  static void showSheet(BuildContext context, {bool showRevealAtEnd = true}) {
    Get.bottomSheet(
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ReadingSettingsPanel(showRevealAtEnd: showRevealAtEnd),
          ),
        ),
      ),
      isScrollControlled: true,
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
            min: 0.8,
            max: 1.6,
            divisions: 8,
            onChanged: (v) => s.textScale.value = v,
          ),
          SwitchListTile(
            secondary: Icon(
              s.vertical.value ? Icons.swap_vert : Icons.swap_horiz,
            ),
            title: const Text('Modo de desplazamiento'),
            subtitle: Text(s.vertical.value ? 'Vertical' : 'Horizontal'),
            value: s.vertical.value,
            onChanged: (v) => s.vertical.value = v,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.shuffle),
            title: const Text('Mezclar preguntas'),
            subtitle: const Text('Se aplica al iniciar'),
            value: s.shuffleQuestions.value,
            onChanged: (v) => s.shuffleQuestions.value = v,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.low_priority),
            title: const Text('Mezclar opciones'),
            subtitle: const Text('Se aplica al iniciar'),
            value: s.shuffleOptions.value,
            onChanged: (v) => s.shuffleOptions.value = v,
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
      ),
    );
  }
}
