import 'package:flutter/material.dart';

/// Asks before leaving the page (back button, AppBar back or system gesture).
class ConfirmExit extends StatelessWidget {
  final bool enabled;
  final String title;
  final String message;
  final Widget child;

  const ConfirmExit({
    super.key,
    this.enabled = true,
    required this.title,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !enabled,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          // M3 dialog with a hero icon: the title and text center under it.
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.logout_rounded),
            title: Text(title),
            content: Text(message, textAlign: TextAlign.center),
            // Stacked, full width: the main action on top.
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Salir'),
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
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: child,
    );
  }
}
