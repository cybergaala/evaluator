import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/question.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/reading_settings_controller.dart';
import '../widgets/confirm_exit.dart';
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

class _StudyPageState extends State<StudyPage> {
  final _settings = ReadingSettingsController.i;
  final _pageController = PageController();
  late final List<Question> _questions = _settings.prepare(
    widget.evaluation.questions,
  );
  final _bookmarks = BookmarksController.i;
  late Set<int> _bookmarked = _bookmarks.of(widget.evaluation.id);
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleBookmark(int questionId) => setState(
    () => _bookmarked = _bookmarks.toggle(widget.evaluation.id, questionId),
  );

  void _goTo(int index) {
    setState(() => _page = index);
    _pageController.jumpToPage(index);
  }

  void _showBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            // In session order, so it matches the slider and the counter.
            final saved = [
              for (var i = 0; i < _questions.length; i++)
                if (_bookmarked.contains(_questions[i].id)) i,
            ];
            return ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(
                    'Guardadas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (saved.isEmpty)
                  const ListTile(title: Text('Sin preguntas guardadas')),
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
                      onPressed: () {
                        _toggleBookmark(_questions[i].id);
                        setSheetState(() {});
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(i);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConfirmExit(
      message: '¿Quieres salir del modo estudio?',
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_page + 1}/${_questions.length}'),
          actions: [
            IconButton(
              tooltip: 'Ajustes de lectura',
              onPressed: () => ReadingSettingsPanel.showSheet(
                context,
                showRevealAtEnd: false,
              ),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Obx(() {
            // Read here: itemBuilder runs lazily, outside Obx's tracking.
            final textScale = _settings.textScale.value;
            final pager = PageView.builder(
              controller: _pageController,
              scrollDirection: _settings.axis,
              itemCount: _questions.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final q = _questions[index];
                return QuestionCard(
                  question: q,
                  optionState: (i) => q.answers.contains(i)
                      ? OptionState.correct
                      : OptionState.neutral,
                  showExplanation: true,
                  textScale: textScale,
                  action: _bookmarked.contains(q.id)
                      ? IconButton(
                          tooltip: 'Quitar de guardadas',
                          onPressed: () => _toggleBookmark(q.id),
                          icon: const Icon(Icons.bookmark_added),
                        )
                      : IconButton(
                          tooltip: 'Guardar',
                          onPressed: () => _toggleBookmark(q.id),
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
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
          }),
        ),
        // Floats over the pager instead of taking space from it.
        floatingActionButton: FloatingActionButton(
          onPressed: _showBookmarks,
          tooltip: 'Marcadores',
          elevation: 0,
          highlightElevation: 0,
          child: Badge.count(
            count: _bookmarked.length,
            isLabelVisible: _bookmarked.isNotEmpty,
            child: const Icon(Icons.bookmarks),
          ),
        ),
      ),
    );
  }
}
