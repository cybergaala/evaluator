import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/usecases/clear_history.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/highlights_controller.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/reading_settings_panel.dart';
import 'theme_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Large title like the Evaluaciones tab.
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Ajustes')),
          SliverList.list(
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Tema'),
                subtitle: const Text('Modo claro/oscuro y color'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const ThemePage()),
              ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Evaluación'),
                subtitle: const Text(
                  'Texto, desplazamiento, mezcla y revelado',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const _EvaluationSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Memoria'),
                subtitle: const Text(
                  'Resaltados, guardadas, aprendidas e historial',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const _MemorySettingsPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvaluationSettingsPage extends StatelessWidget {
  const _EvaluationSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluación')),
      body: const SingleChildScrollView(child: ReadingSettingsPanel()),
    );
  }
}

class _MemorySettingsPage extends StatelessWidget {
  const _MemorySettingsPage();

  /// Asks first, then clears and confirms with a SnackBar.
  Future<void> _clear(
    BuildContext context,
    String what,
    Future<void> Function() clear,
  ) async {
    final ok = await showConfirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: '¿Borrar $what?',
      message: 'Se borran en todas las evaluaciones. No se puede deshacer.',
      confirm: 'Borrar',
    );
    if (!ok) return;
    await clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Se borraron $what')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memoria')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.format_color_reset),
            title: const Text('Borrar resaltados'),
            subtitle: const Text(
              'Quita los textos resaltados del modo estudio',
            ),
            onTap: () => _clear(
              context,
              'los resaltados',
              HighlightsController.i.clearAll,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_remove),
            title: const Text('Borrar preguntas guardadas'),
            subtitle: const Text('Quita todos los marcadores'),
            onTap: () => _clear(
              context,
              'las preguntas guardadas',
              BookmarksController.i.clearAll,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Borrar preguntas aprendidas'),
            subtitle: const Text('Vuelven a mostrarse en el modo estudio'),
            onTap: () => _clear(
              context,
              'las preguntas aprendidas',
              LearnedController.i.clearAll,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_toggle_off),
            title: const Text('Borrar historial'),
            subtitle: const Text('Quita sesiones de estudio y resultados'),
            onTap: () =>
                _clear(context, 'el historial', Get.find<ClearHistory>().call),
          ),
        ],
      ),
    );
  }
}
