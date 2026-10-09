import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

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
        final leave = await showConfirmDialog(
          context,
          icon: Icons.logout_rounded,
          title: title,
          message: message,
          confirm: 'Salir',
        );
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: child,
    );
  }
}
