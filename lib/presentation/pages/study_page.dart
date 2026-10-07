import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/entities/question.dart';
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
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
            return PageView.builder(
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
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
