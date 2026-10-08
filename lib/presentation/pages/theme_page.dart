import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: Obx(() {
        final controller = ThemeController.i;
        // Read both observables so Obx always subscribes to them.
        controller.mode.value;
        controller.seedColor.value;
        return ListView(
          children: [
            for (final model in ThemeModel.themes)
              ListTile(
                title: Text(model.name),
                leading: model.icon == null
                    ? CircleAvatar(radius: 12, backgroundColor: model.color)
                    : Icon(model.icon),
                selected: controller.isSelected(model),
                trailing: controller.isSelected(model)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => controller.apply(model),
              ),
          ],
        );
      }),
    );
  }
}
