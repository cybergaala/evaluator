import 'package:flutter/material.dart';

/// Asks before leaving the page (back button, AppBar back or system gesture).
class ConfirmExit extends StatelessWidget {
  final bool enabled;
  final String message;
  final Widget child;

  const ConfirmExit({
    super.key,
    this.enabled = true,
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
          builder: (context) => AlertDialog(
            title: const Text('¿Salir?'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir'),
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
