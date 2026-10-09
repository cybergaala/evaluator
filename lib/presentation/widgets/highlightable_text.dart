import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
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

// ponytail: one translator for the whole app, never closed; ML Kit keeps the
// model loaded between calls.
final _translator = OnDeviceTranslator(
  sourceLanguage: TranslateLanguage.english,
  targetLanguage: TranslateLanguage.spanish,
);

/// Shows [text] translated English → Spanish in a bottom sheet, on device
/// with ML Kit (the first time downloads the ~30 MB model). Platforms ML Kit
/// doesn't support open Google Translate in the browser instead.
Future<void> translate(BuildContext context, String text) async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    final url = Uri.https('translate.google.com', '/', {
      'sl': 'en',
      'tl': 'es',
      'text': text,
      'op': 'translate',
    });
    await launchUrl(url, mode: LaunchMode.externalApplication);
    return;
  }
  // Paragraph by paragraph: ML Kit joins the lines, which merged the
  // question and its A, B, C options into one block.
  final translation = Future.wait(
    text.split('\n\n').map(_translator.translateText),
  ).then((parts) => parts.join('\n\n'));
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TranslationSheet(text, translation),
  );
}

class _TranslationSheet extends StatelessWidget {
  final String text;
  final Future<String> translation;

  const _TranslationSheet(this.text, this.translation);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: SingleChildScrollView(
        // Above the gesture bar.
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder(
              future: translation,
              builder: (context, snapshot) => switch (snapshot) {
                AsyncSnapshot(:final data?) => SelectableText(
                  data,
                  style: theme.textTheme.bodyLarge,
                ),
                AsyncSnapshot(hasError: true) => const Text(
                  "Couldn't translate. The first translation needs an "
                  'internet connection to download the language model.',
                ),
                _ => const Row(
                  children: [
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Expanded(child: Text('Translating...')),
                  ],
                ),
              },
            ),
            // The original below, so a long question shows its translation
            // first.
            const Divider(height: 32),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
                tooltip: 'Highlight',
                onPressed: () => paint(i),
                icon: Icon(Icons.circle, color: neonColors[i]),
              ),
            IconButton(
              tooltip: 'Erase highlight',
              onPressed: () => paint(null),
              icon: const Icon(Icons.format_color_reset),
            ),
            // The region's own Copy, which also hides the toolbar.
            for (final item in state.contextMenuButtonItems)
              if (item.type == ContextMenuButtonType.copy)
                IconButton(
                  tooltip: 'Copy',
                  onPressed: item.onPressed,
                  icon: const Icon(Icons.copy),
                ),
            IconButton(
              tooltip: 'Translate',
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
