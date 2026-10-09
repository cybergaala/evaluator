import 'dart:async' show scheduleMicrotask;

import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _learned = LearnedController.i;
  late Set<int> _learnedIds = _learned.of(widget.evaluation.id);
  // Learned questions are hidden unless "Mostrar aprendidas", or all of them
  // are learned (nothing to show otherwise).
  late bool _showLearned = _questions.every((q) => _learnedIds.contains(q.id));
  bool _onlySaved = false;
  // What the pager shows: a snapshot of [_questions] with the filters above.
  // [_page] indexes this list.
  // ponytail: snapshot, so (un)marking a question doesn't yank the current
  // page; it applies when a filter changes or on the next session.
  late List<Question> _shown = _filter(_showLearned, _onlySaved);
  late int _page = _pageOf(_questions[_saved?.index ?? 0], _shown);
  // Answers revealed in this session while "Ocultar respuestas" is on.
  final _revealed = <int>{};
  // While dragging the slider, progress is saved once on release.
  bool _sliding = false;
  // The pager's drag while a long card hands its overscroll over.
  Drag? _pagerDrag;
  // The page (in pixels) the hand-over left: moving back ends it there.
  double _handOverFrom = 0;
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
  late final _tabs = TabController(length: 3, vsync: this);
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

  void _toggleLearned(int questionId) {
    setState(
      () => _learnedIds = _learned.toggle(widget.evaluation.id, questionId),
    );
    if (_learnedIds.contains(questionId) && !_showLearned) {
      ScaffoldMessenger.of(context).showSnackBar(
        // Short: it covers the sheet's tabs while shown.
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Aprendida: no se mostrará en la próxima sesión'),
        ),
      );
    }
  }

  void _goTo(int index) {
    _setPage(index);
    _pageController.jumpToPage(index);
  }

  /// Also saves where the session is, to resume it next time.
  void _setPage(int index) {
    setState(() => _page = index);
    if (!_sliding) _saveProgress();
  }

  void _saveProgress() => _progress.save(
    'study',
    widget.evaluation,
    _questions,
    _questions.indexOf(_shown[_page]),
  );

  List<Question> _filter(bool showLearned, bool onlySaved) => [
    for (final q in _questions)
      if ((showLearned || !_learnedIds.contains(q.id)) &&
          (!onlySaved || _bookmarked.contains(q.id)))
        q,
  ];

  /// Page of [current] in [shown], or of the next question after it that is
  /// shown (it may be filtered out).
  // ponytail: O(n²) scan, fine for banks of a few hundred questions.
  int _pageOf(Question current, List<Question> shown) {
    for (var i = _questions.indexOf(current); i < _questions.length; i++) {
      final page = shown.indexOf(_questions[i]);
      if (page >= 0) return page;
    }
    return 0;
  }

  /// Applies the filters; ignored when nothing would be left to show.
  void _refilter({bool? showLearned, bool? onlySaved}) {
    showLearned ??= _showLearned;
    onlySaved ??= _onlySaved;
    final shown = _filter(showLearned, onlySaved);
    if (shown.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quedarían preguntas para mostrar')),
      );
      return;
    }
    final index = _pageOf(_shown[_page], shown);
    setState(() {
      _showLearned = showLearned!;
      _onlySaved = onlySaved!;
      _shown = shown;
      _page = index;
    });
    // After the pager rebuilds with the new item count.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pageController.jumpToPage(index),
    );
  }

  Future<void> _search() async {
    final index = await showSearch(
      context: context,
      delegate: _QuestionSearch(_shown),
    );
    if (index != null && mounted) _goTo(index);
  }

  /// TikTok-style paging for long cards: once the card's own scroll hits an
  /// edge, the rest of the drag drives a drag on the pager, so it stays put
  /// while the finger holds still and, on release, snaps like a normal swipe
  /// (page physics: distance and fling velocity).
  // Not jumpTo: it ends with a ballistic snap, so the page sprang back on its
  // own while the finger was still down.
  /// Meanwhile the card is held ([_HeldPhysics]): moving back returns the
  /// pager to its page first, and only then scrolls the card again.
  bool _handOver(ScrollNotification n) {
    if (n is OverscrollNotification && n.dragDetails != null) {
      final pager = _pageController.position;
      if (_pagerDrag == null) {
        _handOverFrom = _pageController.page!.round() * pager.viewportDimension;
        _pagerDrag = pager.drag(
          DragStartDetails(globalPosition: n.dragDetails!.globalPosition),
          () => _pagerDrag = null,
        );
      }
      // A reversed card (opened at its end) counts its offset upwards.
      var delta = n.metrics.axisDirection == AxisDirection.up
          ? n.overscroll
          : -n.overscroll;
      // Back on (or past) the page it left: stop there and release the card.
      final off = pager.pixels - _handOverFrom;
      final back = off != 0 && (off - delta).sign != off.sign;
      if (back) delta = off;
      _pagerDrag!.update(
        DragUpdateDetails(
          globalPosition: n.dragDetails!.globalPosition,
          delta: Offset(0, delta),
          primaryDelta: delta,
        ),
      );
      if (back) _pagerDrag?.end(DragEndDetails(primaryVelocity: 0));
    } else if (n is ScrollEndNotification) {
      _pagerDrag?.end(n.dragDetails ?? DragEndDetails(primaryVelocity: 0));
    }
    return false;
  }

  /// On lifting the finger, after the gesture recognizers ran (microtask):
  /// - Ends a hand-over drag still alive: a card that flings back (the finger
  ///   moved back before lifting) sends no ScrollEnd until its fling stops, so
  ///   the pager stayed between two pages.
  /// - Lets the cards take touches during the snap: it inherits the drag's
  ///   "ignore touches" flag, so for its ~300 ms a swipe on the arriving card
  ///   dragged the pager on instead, leaving both pages cut. A card that hands
  ///   over at its edge still interrupts the snap.
  void _releasePager(PointerEvent _) => scheduleMicrotask(() {
    _pagerDrag?.end(DragEndDetails(primaryVelocity: 0));
    if (_pageController.hasClients) {
      _pageController.position.context.setIgnorePointer(false);
    }
  });

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

  /// Questions in [ids], in session order, so they match the slider and the
  /// counter. Tap to jump; [removable] adds a trailing "Quitar" bookmark.
  List<Widget> _questionTiles(
    Set<int> ids,
    String empty,
    double minSize, {
    bool removable = false,
  }) {
    final pages = [
      for (var i = 0; i < _shown.length; i++)
        if (ids.contains(_shown[i].id)) i,
    ];
    if (pages.isEmpty) return [ListTile(title: Text(empty))];
    return [
      for (final i in pages)
        ListTile(
          leading: Text('${i + 1}'),
          title: Text(
            _shown[i].question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          selected: i == _page,
          trailing: removable
              ? IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.bookmark_remove),
                  onPressed: () => _toggleBookmark(_shown[i].id),
                )
              : null,
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
        color: scheme.surfaceContainerHigh,
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
                    // No underline: the selected icon's color is enough.
                    indicator: const BoxDecoration(),
                    onTap: (_) {
                      setState(() {});
                      _expandSheet();
                    },
                    // Icons only; the tooltip names each tab.
                    tabs: [
                      const Tab(
                        icon: Tooltip(
                          message: 'Ajustes',
                          child: Icon(Icons.tune),
                        ),
                      ),
                      Tab(
                        icon: Tooltip(
                          message: 'Guardadas',
                          child: Badge.count(
                            count: _bookmarked.length,
                            isLabelVisible: _bookmarked.isNotEmpty,
                            child: const Icon(Icons.bookmarks_outlined),
                          ),
                        ),
                      ),
                      const Tab(
                        icon: Tooltip(
                          message: 'Resaltadas',
                          child: Icon(Icons.border_color_outlined),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_sheetOpen)
              const SliverToBoxAdapter()
            else if (_tabs.index == 0)
              SliverList.list(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.school_outlined),
                    title: const Text('Mostrar aprendidas'),
                    subtitle: Text('${_learnedIds.length} aprendidas'),
                    value: _showLearned,
                    onChanged: (v) => _refilter(showLearned: v),
                  ),
                  const ReadingSettingsPanel(showRevealAtEnd: false),
                ],
              )
            else if (_tabs.index == 1)
              SliverList.list(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.filter_list),
                    title: const Text('Estudiar solo guardadas'),
                    value: _onlySaved,
                    onChanged: _onlySaved || _bookmarked.isNotEmpty
                        ? (v) => _refilter(onlySaved: v)
                        : null,
                  ),
                  ..._questionTiles(
                    _bookmarked,
                    'Sin preguntas guardadas',
                    minSize,
                    removable: true,
                  ),
                ],
              )
            else
              SliverList.list(
                children: _questionTiles(
                  _highlights.questionIds(widget.evaluation.id),
                  'Sin preguntas resaltadas',
                  minSize,
                ),
              ),
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
    final current = _shown[_page];
    return ConfirmExit(
      title: '¿Salir del modo estudio?',
      message: 'Al volver seguirás en esta pregunta.',
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_page + 1}/${_shown.length}'),
          actions: [
            IconButton(
              tooltip: 'Buscar',
              onPressed: _search,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: _marker ? 'Dejar de resaltar' : 'Resaltar texto',
              isSelected: _marker,
              onPressed: () => setState(() => _marker = !_marker),
              icon: const Icon(Icons.border_color_outlined),
              selectedIcon: const Icon(Icons.border_color),
            ),
            if (_learnedIds.contains(current.id))
              IconButton(
                tooltip: 'Quitar de aprendidas',
                onPressed: () => _toggleLearned(current.id),
                icon: const Icon(Icons.school),
              )
            else
              IconButton(
                tooltip: 'Marcar como aprendida',
                onPressed: () => _toggleLearned(current.id),
                icon: const Icon(Icons.school_outlined),
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
            // The pager runs behind the sheet: each page ends in a [peek]
            // blank space, so a zigzag left there by a cancelled swipe hides
            // behind the sheet.
            return Stack(
              children: [
                _pager(peek),
                _slider(peek),
                _bottomSheet(context, minSize),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _pager(double peek) => Obx(() {
    // Read here: itemBuilder runs lazily, outside Obx's tracking.
    final textScale = _settings.textScale.value;
    final justify = _settings.justify.value;
    final vertical = _settings.axis == Axis.vertical;
    final hideAnswers = _settings.hideAnswers.value;
    // Also room for the slider pill, so the last lines can scroll above it.
    final bottomSpace = peek + (_hasSlider ? _pillHeight + 8 : 0);
    final pager = PageView.builder(
      controller: _pageController,
      physics: const _SnapPhysics(parent: ClampingScrollPhysics()),
      scrollDirection: _settings.axis,
      itemCount: _shown.length,
      onPageChanged: _setPage,
      itemBuilder: (context, index) {
        final q = _shown[index];
        final hidden = hideAnswers && !_revealed.contains(q.id);
        void reveal() => setState(() => _revealed.add(q.id));
        Widget card([bool reverse = false]) => QuestionCard(
          question: q,
          reverse: reverse,
          physics: vertical
              ? _HeldPhysics(() => _pagerDrag != null)
              : const ClampingScrollPhysics(),
          optionState: (i) => !hidden && q.answers.contains(i)
              ? OptionState.correct
              : OptionState.neutral,
          showExplanation: !hidden,
          onTap: hidden ? (_) => reveal() : null,
          footer: hidden
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: reveal,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Mostrar respuesta'),
                  ),
                )
              : null,
          textScale: textScale,
          justify: justify,
          // Behind the sheet, inside the scroll so the text can still reach
          // above it; the zigzag of the next page sits in the middle of it.
          bottomSpace: bottomSpace,
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
        if (!vertical) return card();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handOver,
              // Entering from above (going back), so it shows its end. The
              // pager's real position, not _page: a fast swipe can cross the
              // middle before this page is first built.
              child: _CardScroll(atEnd: index < _pagerPosition, builder: card),
            ),
            // Above the page, centered in the previous page's bottom space, so
            // both questions get the same room around it (blank: a page
            // entering from above opens at its end). Seen only while
            // swiping: the pager clips it once the page settles.
            if (index > 0)
              Positioned(
                top: -(bottomSpace + _Zigzag.height) / 2,
                left: 0,
                right: 0,
                child: _Zigzag(),
              ),
          ],
        );
      },
    );
    return Listener(
      onPointerUp: _releasePager,
      onPointerCancel: _releasePager,
      child: pager,
    );
  });

  double get _pagerPosition =>
      _pageController.hasClients && _pageController.position.haveDimensions
      ? _pageController.page!
      : _page.toDouble();

  bool get _hasSlider => _settings.showSlider.value && _shown.length > 1;

  /// Quick jump between questions: a pill floating above the sheet, hidden
  /// while the sheet is open.
  Widget _slider(double peek) => Positioned(
    left: 16,
    right: 16,
    bottom: peek + 8,
    child: Obx(() {
      if (!_hasSlider) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final number = Theme.of(context).textTheme.titleMedium;
      return IgnorePointer(
        ignoring: _sheetOpen,
        child: AnimatedSlide(
          offset: Offset(0, _sheetOpen ? 0.5 : 0),
          duration: const Duration(milliseconds: 200),
          child: AnimatedOpacity(
            opacity: _sheetOpen ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: scheme.surfaceContainerHigh,
              shape: const StadiumBorder(),
              child: SizedBox(
                height: _pillHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Text('${_page + 1}', style: number),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          tickMarkShape: _EveryNTickMark(_shown.length),
                        ),
                        child: Slider(
                          // ignore: deprecated_member_use
                          year2023: false,
                          value: _page.toDouble(),
                          max: _shown.length - 1.0,
                          divisions: _shown.length - 1,
                          label: '${_page + 1}',
                          onChangeStart: (_) => _sliding = true,
                          onChanged: (v) {
                            // One tick per question jumped, not per drag event.
                            if (v.round() == _page) return;
                            HapticFeedback.selectionClick();
                            _goTo(v.round());
                          },
                          onChangeEnd: (_) {
                            _sliding = false;
                            _saveProgress();
                          },
                        ),
                      ),
                    ),
                    Text('${_shown.length}', style: number),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

const _pillHeight = 56.0;

/// Finds a question by its text or options; returns its page.
class _QuestionSearch extends SearchDelegate<int?> {
  final List<Question> questions;

  _QuestionSearch(this.questions) : super(searchFieldLabel: 'Buscar pregunta');

  /// Lowercase without accents, so "celula" finds "Célula".
  static String _fold(String s) => s.toLowerCase().replaceAllMapped(
    RegExp('[áéíóúü]'),
    (m) => 'aeiouu'['áéíóúü'.indexOf(m[0]!)],
  );

  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Borrar',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final text = _fold(query.trim());
    final pages = [
      for (var i = 0; i < questions.length; i++)
        if ([
          questions[i].question,
          ...questions[i].options,
        ].any((s) => _fold(s).contains(text)))
          i,
    ];
    if (pages.isEmpty) {
      return const ListTile(title: Text('Sin resultados'));
    }
    return ListView(
      children: [
        for (final i in pages)
          ListTile(
            leading: Text('${i + 1}'),
            title: Text(
              questions[i].question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => close(context, i),
          ),
      ],
    );
  }
}

/// A page's card, opened at its end when [atEnd], so a page coming back from
/// above meets the next one with its blank bottom space, under the zigzag,
/// instead of half its text.
class _CardScroll extends StatefulWidget {
  final bool atEnd;
  final Widget Function(bool reverse) builder;

  const _CardScroll({required this.atEnd, required this.builder});

  @override
  State<_CardScroll> createState() => _CardScrollState();
}

class _CardScrollState extends State<_CardScroll> {
  // Fixed on creation: the current page changes halfway through a swipe.
  late final _atEnd = widget.atEnd;

  // Own bucket, so no offset is restored: a page always enters at the edge
  // that faces the page it comes from (and a reversed offset means another
  // spot anyway).
  final _bucket = PageStorageBucket();

  @override
  Widget build(BuildContext context) =>
      PageStorage(bucket: _bucket, child: widget.builder(_atEnd));
}

/// A card's scroll that stays put while [held]: the whole move comes out as
/// overscroll, which the study page hands to the pager.
class _HeldPhysics extends ClampingScrollPhysics {
  final bool Function() held;

  const _HeldPhysics(this.held, {super.parent});

  @override
  _HeldPhysics applyTo(ScrollPhysics? ancestor) =>
      _HeldPhysics(held, parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) => held()
      ? value - position.pixels
      : super.applyBoundaryConditions(position, value);
}

/// A quicker page snap. While the pager animates it keeps touches from the
/// cards, and the default spring crawls its last pixel for ~800 ms: a swipe
/// to read the page that had just arrived moved the pager instead, cutting it.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({super.parent});

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 500, ratio: 1);
}

/// A zigzag line across the page, between questions in vertical paging.
class _Zigzag extends StatelessWidget {
  static const height = 10.0;

  const _Zigzag();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, height),
    painter: _ZigzagPainter(Theme.of(context).colorScheme.outlineVariant),
  );
}

class _ZigzagPainter extends CustomPainter {
  final Color color;

  _ZigzagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const step = 10.0;
    const stroke = 2.0;
    // Inset by the stroke, so no tip spills out of the box into the page.
    const top = stroke;
    final bottom = size.height - stroke;
    final path = Path()..moveTo(0, bottom);
    for (var x = 0.0; x < size.width; x += step) {
      path
        ..lineTo(x + step / 2, top)
        ..lineTo(x + step, bottom);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ZigzagPainter old) => old.color != color;
}

/// One slider dot every [step] questions, so long banks still show a few.
/// Zero preferred size: the slider never skips the ticks as "too dense".
class _EveryNTickMark extends SliderTickMarkShape {
  // ponytail: the slider paints ticks left to right without their index, so
  // it is counted here; assumes a left-to-right slider.
  _EveryNTickMark(int count)
    : step = count <= 20 ? 1 : (count / 20 / 5).ceil() * 5;

  final int step;
  int _index = 0;
  double _lastX = double.infinity;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) => Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    // A new pass over the ticks starts back at the left.
    _index = center.dx <= _lastX ? 0 : _index + 1;
    _lastX = center.dx;
    if (_index % step != 0) return;
    final active = center.dx <= thumbCenter.dx;
    final color = active
        ? sliderTheme.activeTickMarkColor
        : sliderTheme.inactiveTickMarkColor;
    context.canvas.drawCircle(center, 2, Paint()..color = color!);
  }
}
