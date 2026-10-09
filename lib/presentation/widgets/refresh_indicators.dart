import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

// Explicit colors: ClassicHeader/ClassicFooter's Theme.of() defaults render
// dark on dark themes here.

/// Shown under the large AppBar: put a `HeaderLocator.sliver(clearExtent:
/// false)` right after it (takes space, so it pushes the list down rather
/// than overlaying it).
/// Clamping, so the AppBar stays still and the header opens below it
/// (as in the example's sample_page.dart).
ClassicHeader classicHeader(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurface;
  return ClassicHeader(
    clamping: true,
    position: IndicatorPosition.locator,
    dragText: 'Desliza para actualizar',
    armedText: 'Suelta para actualizar',
    readyText: 'Actualizando...',
    processingText: 'Actualizando...',
    processedText: 'Listo',
    noMoreText: 'No hay más',
    failedText: 'Error',
    messageText: 'Actualizado a las %T',
    textStyle: TextStyle(color: color),
    messageStyle: TextStyle(color: color),
    iconTheme: IconThemeData(color: color),
  );
}

ClassicFooter classicFooter(BuildContext context) {
  final color = Theme.of(context).colorScheme.onSurface;
  return ClassicFooter(
    position: IndicatorPosition.above,
    dragText: 'Desliza para cargar más',
    armedText: 'Suelta para cargar más',
    readyText: 'Cargando...',
    processingText: 'Cargando...',
    processedText: 'Listo',
    noMoreText: 'No hay más',
    failedText: 'Error',
    showMessage: false,
    textStyle: TextStyle(color: color),
    messageStyle: TextStyle(color: color),
    iconTheme: IconThemeData(color: color),
  );
}

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
