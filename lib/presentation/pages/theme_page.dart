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
        // Read all observables so Obx always subscribes to them.
        controller.mode.value;
        controller.amoled.value;
        controller.seedColor.value;
        final modes = ThemeModel.themes.where((t) => t.color == null);
        final colors = ThemeModel.themes.where((t) => t.color != null);
        return ListView(
          children: [
            for (final model in modes)
              ListTile(
                title: Text(model.name),
                leading: Icon(model.icon),
                selected: controller.isSelected(model),
                trailing: controller.isSelected(model)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => controller.apply(model),
              ),
            const Divider(),
            GridView.extent(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              maxCrossAxisExtent: 72,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                for (final model in colors)
                  Tooltip(
                    message: model.name,
                    child: Material(
                      color: model.color,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => controller.apply(model),
                        child: controller.isSelected(model)
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
