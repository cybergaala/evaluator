import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/history_entry.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/save_history_entry.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/highlights_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/reading_settings_controller.dart';
import '../widgets/confirm_exit.dart';
import '../widgets/highlightable_text.dart';
import '../widgets/question_card.dart';
import '../widgets/reading_settings_panel.dart';

// Based on flutter_easy_refresh v4 example: page/sample/page_view_page.dart
// ponytail: no EasyRefresh wrapper, a fixed question list has nothing to refresh or load.
class StudyPage extends StatefulWidget {
  final Evaluation evaluation;

  const StudyPage({super.key, required this.evaluation});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage>
    with SingleTickerProviderStateMixin {
  static const _expanded = 0.7;
  final _settings = ReadingSettingsController.i;
  final _progress = ProgressController.i;
  late final _saved = _progress.load('study', widget.evaluation);
  late final List<Question> _questions =
      _saved?.questions ?? _settings.prepare(widget.evaluation.questions);
  late int _page = _saved?.index ?? 0;
  late final _pageController = PageController(initialPage: _page);
  final _bookmarks = BookmarksController.i;
  late Set<int> _bookmarked = _bookmarks.of(widget.evaluation.id);
  final _highlights = HighlightsController.i;
  // Marker mode: text becomes selectable, so swiping on it no longer pages.
  bool _marker = false;
  // Content is only built while the sheet is open, so the peek shows just
  // the handle and tabs.
  bool _sheetOpen = false;
  final _sheet = DraggableScrollableController();
  late final _tabs = TabController(length: 2, vsync: this);
  final _saveHistory = Get.find<SaveHistoryEntry>();
  // Study time; paused while the app is in the background.
  final _clock = Stopwatch()..start();
  late final _lifecycle = AppLifecycleListener(
    onHide: _clock.stop,
    onShow: _clock.start,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // late: create it now so it starts listening.
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // ponytail: fixed 10 s minimum so opening by mistake isn't logged.
    if (_clock.elapsed >= const Duration(seconds: 10)) {
      _saveHistory(
        StudySession(
          widget.evaluation.id,
          widget.evaluation.title,
          DateTime.now(),
          _clock.elapsed,
        ),
      );
    }
    _pageController.dispose();
    _sheet.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _toggleBookmark(int questionId) => setState(
    () => _bookmarked = _bookmarks.toggle(widget.evaluation.id, questionId),
  );

  void _goTo(int index) {
    _setPage(index);
    _pageController.jumpToPage(index);
  }

  /// Also saves where the session is, to resume it next time.
  void _setPage(int index) {
    setState(() => _page = index);
    _progress.save('study', widget.evaluation, _questions, index);
  }

  /// TikTok-style paging for long cards: once the card's own scroll hits an
  /// edge, the rest of the drag moves the pager, then it snaps on release.
  bool _handOver(ScrollNotification n, int index) {
    final pager = _pageController.position;
    if (n is OverscrollNotification && n.dragDetails != null) {
      pager.jumpTo(
        (pager.pixels + n.overscroll).clamp(
          pager.minScrollExtent,
          pager.maxScrollExtent,
        ),
      );
    } else if (n is ScrollEndNotification) {
      final delta = _pageController.page! - index;
      // ponytail: fixed 20% threshold, add a fling-velocity rule if short
      // flicks feel sticky.
      if (delta != 0) {
        _pageController.animateToPage(
          delta.abs() > 0.2 ? index + delta.sign.toInt() : index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
    return false;
  }

  void _expandSheet() => _sheet.animateTo(
    _expanded,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  void _collapseSheet(double min) => _sheet.animateTo(
    min,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  /// Bookmarks in session order, so they match the slider and the counter.
  List<Widget> _bookmarkTiles(double minSize) {
    final saved = [
      for (var i = 0; i < _questions.length; i++)
        if (_bookmarked.contains(_questions[i].id)) i,
    ];
    if (saved.isEmpty) {
      return const [ListTile(title: Text('Sin preguntas guardadas'))];
    }
    return [
      for (final i in saved)
        ListTile(
          leading: Text('${i + 1}'),
          title: Text(
            _questions[i].question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          selected: i == _page,
          trailing: IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.bookmark_remove),
            onPressed: () => _toggleBookmark(_questions[i].id),
          ),
          onTap: () {
            _goTo(i);
            _collapseSheet(minSize);
          },
        ),
    ];
  }

  /// Always peeking at the bottom: handle + tabs. Tap a tab or drag up to open.
  Widget _bottomSheet(BuildContext context, double minSize) {
    final scheme = Theme.of(context).colorScheme;
    final sheet = DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: _expanded,
      snap: true,
      builder: (context, scrollController) => Material(
        color: scheme.surfaceContainerLow,
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  TabBar(
                    controller: _tabs,
                    dividerHeight: 0,
                    onTap: (_) {
                      setState(() {});
                      _expandSheet();
                    },
                    tabs: [
                      const Tab(text: 'Ajustes'),
                      Tab(
                        text: _bookmarked.isEmpty
                            ? 'Guardadas'
                            : 'Guardadas (${_bookmarked.length})',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_sheetOpen)
              const SliverToBoxAdapter()
            else if (_tabs.index == 0)
              const SliverToBoxAdapter(
                child: ReadingSettingsPanel(showRevealAtEnd: false),
              )
            else
              SliverList.list(children: _bookmarkTiles(minSize)),
            // Room for the gesture bar.
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        final open = n.extent > n.minExtent + 0.01;
        if (open != _sheetOpen) setState(() => _sheetOpen = open);
        return false;
      },
      child: sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _questions[_page];
    return ConfirmExit(
      message: '¿Quieres salir del modo estudio?',
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_page + 1}/${_questions.length}'),
          actions: [
            IconButton(
              tooltip: _marker ? 'Dejar de resaltar' : 'Resaltar texto',
              isSelected: _marker,
              onPressed: () => setState(() => _marker = !_marker),
              icon: const Icon(Icons.border_color_outlined),
              selectedIcon: const Icon(Icons.border_color),
            ),
            if (_bookmarked.contains(current.id))
              IconButton(
                tooltip: 'Quitar de guardadas',
                onPressed: () => _toggleBookmark(current.id),
                icon: const Icon(Icons.bookmark_added),
              )
            else
              IconButton(
                tooltip: 'Guardar',
                onPressed: () => _toggleBookmark(current.id),
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Handle (22) + TabBar (48), plus the gesture bar under them.
            final peek = 70 + MediaQuery.paddingOf(context).bottom;
            final minSize = (peek / constraints.maxHeight).clamp(0.0, 0.5);
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: peek),
                  child: _pager(),
                ),
                _bottomSheet(context, minSize),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pager() => Obx(() {
    // Read here: itemBuilder runs lazily, outside Obx's tracking.
    final textScale = _settings.textScale.value;
    final justify = _settings.justify.value;
    final vertical = _settings.axis == Axis.vertical;
    final pager = PageView.builder(
      controller: _pageController,
      scrollDirection: _settings.axis,
      itemCount: _questions.length,
      onPageChanged: _setPage,
      itemBuilder: (context, index) {
        final q = _questions[index];
        final card = QuestionCard(
          question: q,
          optionState: (i) =>
              q.answers.contains(i) ? OptionState.correct : OptionState.neutral,
          showExplanation: true,
          textScale: textScale,
          justify: justify,
          textBuilder: (field, text, style) => HighlightableText(
            text: text,
            style: style,
            selectable: _marker,
            highlights: _highlights.of(widget.evaluation.id, q.id, field),
            onPaint: (start, end, color) => setState(
              () => _highlights.paint(
                widget.evaluation.id,
                q.id,
                field,
                start,
                end,
                color,
              ),
            ),
          ),
        );
        // Horizontal paging doesn't fight the card's vertical scroll.
        if (!vertical) return card;
        return NotificationListener<ScrollNotification>(
          onNotification: (n) => _handOver(n, index),
          child: card,
        );
      },
    );
    return Column(
      children: [
        // Quick jump between questions.
        if (_settings.showSlider.value && _questions.length > 1)
          Slider(
            value: _page.toDouble(),
            max: _questions.length - 1.0,
            divisions: _questions.length - 1,
            label: '${_page + 1}',
            onChanged: (v) => _goTo(v.round()),
          ),
        Expanded(child: pager),
      ],
    );
  });
}
