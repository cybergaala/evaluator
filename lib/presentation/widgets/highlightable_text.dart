import 'package:flutter/material.dart';

import '../controllers/highlights_controller.dart';

/// Neon marker colors: yellow, green, pink, cyan, orange.
const neonColors = [
  Color(0xFFFFFF00),
  Color(0xFF39FF14),
  Color(0xFFFF6EC7),
  Color(0xFF00FFFF),
  Color(0xFFFF9F00),
];

/// Text with neon highlights. When [selectable], its selection toolbar paints
/// like a marker. Off by default because selectable text wins horizontal drags
/// on Android, which would block horizontal paging.
class HighlightableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Highlight> highlights;
  final bool selectable;

  /// Paints `[start, end)` with `neonColors[color]`, or erases it when null.
  final void Function(int start, int end, int? color) onPaint;

  const HighlightableText({
    super.key,
    required this.text,
    required this.highlights,
    required this.onPaint,
    this.style,
    this.selectable = false,
  });

  List<TextSpan> _spans() {
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e, c) in highlights) {
      // Skip ranges that no longer fit the text.
      if (s < at || e > text.length) continue;
      if (s > at) spans.add(TextSpan(text: text.substring(at, s)));
      spans.add(
        TextSpan(
          text: text.substring(s, e),
          // Dark text keeps the marker readable in dark mode too.
          style: TextStyle(
            backgroundColor: neonColors[c].withValues(alpha: 0.6),
            color: Colors.black,
          ),
        ),
      );
      at = e;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final span = TextSpan(children: _spans());
    if (!selectable) return Text.rich(span, style: style);
    // Own bucket: SelectableText's inner Scrollable shares the card ListView's
    // PageStorage id, so it would restore that offset and animate back to 0.
    return PageStorage(
      bucket: PageStorageBucket(),
      child: _selectable(context, span),
    );
  }

  Widget _selectable(BuildContext context, TextSpan span) {
    return SelectableText.rich(
      span,
      style: style,
      // SelectableText ignores DefaultTextStyle's alignment, Text.rich doesn't.
      textAlign: DefaultTextStyle.of(context).textAlign,
      contextMenuBuilder: (context, state) {
        final sel = state.textEditingValue.selection;
        void paint(int? color) {
          onPaint(sel.start, sel.end, color);
          state.hideToolbar();
          state.userUpdateTextEditingValue(
            state.textEditingValue.copyWith(
              selection: TextSelection.collapsed(offset: sel.end),
            ),
            SelectionChangedCause.toolbar,
          );
        }

        return AdaptiveTextSelectionToolbar(
          anchors: state.contextMenuAnchors,
          children: [
            for (var i = 0; i < neonColors.length; i++)
              IconButton(
                tooltip: 'Resaltar',
                onPressed: () => paint(i),
                icon: Icon(Icons.circle, color: neonColors[i]),
              ),
            IconButton(
              tooltip: 'Borrar resaltado',
              onPressed: () => paint(null),
              icon: const Icon(Icons.format_color_reset),
            ),
            IconButton(
              tooltip: 'Copiar',
              onPressed: () =>
                  state.copySelection(SelectionChangedCause.toolbar),
              icon: const Icon(Icons.copy),
            ),
          ],
        );
      },
    );
  }
}
