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
          const SliverAppBar.large(title: Text('Settings')),
          SliverList.list(
            children: [
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Theme'),
                subtitle: const Text('Light/dark mode and color'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const ThemePage()),
              ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Reading'),
                subtitle: const Text('Text, paging, shuffle and reveal'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.to(() => const _EvaluationSettingsPage()),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('Storage'),
                subtitle: const Text('Highlights, saved, learned and history'),
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
      appBar: AppBar(title: const Text('Reading')),
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
      title: 'Clear $what?',
      message: "It applies to every question bank. This can't be undone.",
      confirm: 'Clear',
    );
    if (!ok) return;
    await clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cleared $what')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.format_color_reset),
            title: const Text('Clear highlights'),
            subtitle: const Text('Removes the highlighted text in study mode'),
            onTap: () =>
                _clear(context, 'highlights', HighlightsController.i.clearAll),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_remove),
            title: const Text('Clear saved questions'),
            subtitle: const Text('Removes every bookmark'),
            onTap: () => _clear(
              context,
              'saved questions',
              BookmarksController.i.clearAll,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Clear learned questions'),
            subtitle: const Text('They show up again in study mode'),
            onTap: () => _clear(
              context,
              'learned questions',
              LearnedController.i.clearAll,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_toggle_off),
            title: const Text('Clear history'),
            subtitle: const Text('Removes study sessions and scores'),
            onTap: () =>
                _clear(context, 'history', Get.find<ClearHistory>().call),
          ),
        ],
      ),
    );
  }
}
