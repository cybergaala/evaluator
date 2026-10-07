import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/reading_settings_panel.dart';
import 'theme_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
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
            subtitle: const Text('Texto, desplazamiento, mezcla y revelado'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const _EvaluationSettingsPage()),
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
