import 'package:flutter/material.dart';

/// The app's only dialog: M3 hero icon, centered title and text, and stacked
/// full-width buttons with the main action on top. True when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ],
    ),
  );
  return ok == true;
}
