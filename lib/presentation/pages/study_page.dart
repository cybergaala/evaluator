import 'package:flutter/material.dart';

import '../../domain/entities/evaluation.dart';
import '../widgets/question_card.dart';

// Based on flutter_easy_refresh v4 example: page/sample/page_view_page.dart
// ponytail: no EasyRefresh wrapper, a fixed question list has nothing to refresh or load.
class StudyPage extends StatefulWidget {
  final Evaluation evaluation;

  const StudyPage({super.key, required this.evaluation});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final _pageController = PageController();
  Axis _scrollDirection = Axis.vertical;
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.evaluation.questions;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_page + 1}/${questions.length}'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _scrollDirection = _scrollDirection == Axis.horizontal
                    ? Axis.vertical
                    : Axis.horizontal;
              });
            },
            icon: Icon(
              _scrollDirection == Axis.horizontal
                  ? Icons.horizontal_distribute
                  : Icons.vertical_distribute,
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: _scrollDirection,
        itemCount: questions.length,
        onPageChanged: (index) => setState(() => _page = index),
        itemBuilder: (context, index) {
          final q = questions[index];
          return QuestionCard(
            question: q,
            optionState: (i) => q.answers.contains(i)
                ? OptionState.correct
                : OptionState.neutral,
            showExplanation: true,
          );
        },
      ),
    );
  }
}
