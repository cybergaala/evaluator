import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/bookmarks_controller.dart';
import '../controllers/highlights_controller.dart';
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
                subtitle: const Text('Resaltados y preguntas guardadas'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar $what?'),
        content: const Text(
          'Se borran en todas las evaluaciones. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
        ],
      ),
    );
  }
}
