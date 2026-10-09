import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/highlights_controller.dart';

/// Neon marker colors: yellow, green, pink, cyan, orange.
const neonColors = [
  Color(0xFFFFFF00),
  Color(0xFF39FF14),
  Color(0xFFFF6EC7),
  Color(0xFF00FFFF),
  Color(0xFFFF9F00),
];

/// Opens [text] in Google Translate, always English → Spanish: the app when
/// installed (it handles translate.google.com links), else the browser.
/// Spanish has no Latin American variant there; "es" is the only one.
Future<void> translate(BuildContext context, String text) async {
  final url = Uri.https('translate.google.com', '/', {
    'sl': 'en',
    'tl': 'es',
    'text': text,
    'op': 'translate',
  });
  final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el traductor')),
    );
  }
}

/// Text with neon highlights, always selectable: a long press selects (drags
/// still scroll and page) and the toolbar paints like a marker.
class HighlightableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Highlight> highlights;

  /// Paints `[start, end)` with `neonColors[color]`, or erases it when null.
  final void Function(int start, int end, int? color) onPaint;

  const HighlightableText({
    super.key,
    required this.text,
    required this.highlights,
    required this.onPaint,
    this.style,
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
    return _SelectableHighlight(span: span, style: style, onPaint: onPaint);
  }
}

/// [SelectionArea] plus a listener for the selected offsets.
class _SelectableHighlight extends StatefulWidget {
  final TextSpan span;
  final TextStyle? style;
  final void Function(int start, int end, int? color) onPaint;

  const _SelectableHighlight({
    required this.span,
    required this.style,
    required this.onPaint,
  });

  @override
  State<_SelectableHighlight> createState() => _SelectableHighlightState();
}

class _SelectableHighlightState extends State<_SelectableHighlight> {
  // Tells the selected range as offsets into this text.
  final _selection = SelectionListenerNotifier();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (context, state) {
        // The selection as [start, end); backwards ones come reversed.
        (int, int)? selected() {
          final range = _selection.selection.range;
          if (range == null) return null;
          final (a, b) = (range.startOffset, range.endOffset);
          return a < b ? (a, b) : (b, a);
        }

        void done() {
          state.clearSelection();
          state.hideToolbar();
        }

        void paint(int? color) {
          if (selected() case (final start, final end)) {
            widget.onPaint(start, end, color);
          }
          done();
        }

        return AdaptiveTextSelectionToolbar(
          anchors: state.contextMenuAnchors,
          children: [
            // Yellow, green and cyan only. Pink and orange stay in
            // neonColors so highlights saved with them still draw.
            for (final i in const [0, 1, 3])
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
            // The region's own Copy, which also hides the toolbar.
            for (final item in state.contextMenuButtonItems)
              if (item.type == ContextMenuButtonType.copy)
                IconButton(
                  tooltip: 'Copiar',
                  onPressed: item.onPressed,
                  icon: const Icon(Icons.copy),
                ),
            IconButton(
              tooltip: 'Traducir',
              onPressed: () {
                final text = switch (selected()) {
                  (final start, final end) =>
                    widget.span.toPlainText().substring(start, end),
                  null => null,
                };
                done();
                // The page's context: the toolbar's is gone once hidden.
                if (text != null) translate(this.context, text);
              },
              icon: const Icon(Icons.translate),
            ),
          ],
        );
      },
      child: SelectionListener(
        selectionNotifier: _selection,
        child: Text.rich(widget.span, style: widget.style),
      ),
    );
  }
}
