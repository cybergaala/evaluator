import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/evaluation.dart';
import '../pages/exam_page.dart';

enum _Mode { complete, quick, timed }

/// Questions in a timed exam, like the real one, and the time for each
/// (60 × 2 min = 2 hours).
const _timedCount = 60;
const _perQuestion = Duration(minutes: 2);
const _quickSizes = [10, 20, 30];

/// Asks how to run a new exam of [evaluation]: full (all, shuffled or
/// in order), quick (10/20/30 at random) or timed (the real exam), and from
/// all questions or only the [learned] ones. Null when dismissed.
Future<ExamSetup?> showExamSetup(
  BuildContext context,
  Evaluation evaluation,
  Set<int> learned,
) => showModalBottomSheet<ExamSetup>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => _ExamSetupSheet(evaluation, learned),
);

class _ExamSetupSheet extends StatefulWidget {
  final Evaluation evaluation;
  final Set<int> learned;

  const _ExamSetupSheet(this.evaluation, this.learned);

  @override
  State<_ExamSetupSheet> createState() => _ExamSetupSheetState();
}

class _ExamSetupSheetState extends State<_ExamSetupSheet> {
  var _mode = _Mode.complete;
  var _learnedOnly = false;
  var _shuffle = true;
  var _size = 20;

  int get _pool =>
      _learnedOnly ? widget.learned.length : widget.evaluation.questions.length;

  int get _count => switch (_mode) {
    _Mode.complete => _pool,
    _Mode.quick => min(_size, _pool),
    _Mode.timed => min(_timedCount, _pool),
  };

  ExamSetup get _setup => ExamSetup(
    only: _learnedOnly ? widget.learned : null,
    shuffle: _mode != _Mode.complete || _shuffle,
    count: _mode == _Mode.complete ? null : _count,
    perQuestion: _mode == _Mode.timed ? _perQuestion : null,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New exam', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            widget.evaluation.title,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.complete,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('Full'),
              ),
              ButtonSegment(
                value: _Mode.quick,
                icon: Icon(Icons.bolt),
                label: Text('Quick'),
              ),
              ButtonSegment(
                value: _Mode.timed,
                icon: Icon(Icons.timer_outlined),
                label: Text('Timed'),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (s) => setState(() => _mode = s.single),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              switch (_mode) {
                _Mode.complete => 'Every question, at your own pace.',
                _Mode.quick => 'A short round of random questions.',
                _Mode.timed => 'Simulates the real exam against the clock.',
              },
              key: ValueKey(_mode),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: switch (_mode) {
              _Mode.complete => _section(
                'Order',
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.shuffle),
                      label: Text('Shuffled'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.format_list_numbered),
                      label: Text('In order'),
                    ),
                  ],
                  selected: {_shuffle},
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  onSelectionChanged: (s) =>
                      setState(() => _shuffle = s.single),
                ),
              ),
              _Mode.quick => _section(
                'Length',
                SegmentedButton<int>(
                  segments: [
                    for (final n in _quickSizes)
                      ButtonSegment(
                        value: n,
                        label: Text('$n'),
                        // ponytail: sizes above the pool are greyed out; the
                        // selected one still clamps to the pool via _count.
                        enabled: n <= _pool || n == _quickSizes.first,
                      ),
                  ],
                  selected: {_size},
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  onSelectionChanged: (s) => setState(() => _size = s.single),
                ),
              ),
              _Mode.timed => _section('Rules', _TimedRules(_count)),
            },
          ),
          if (widget.learned.isNotEmpty)
            _section(
              'Questions',
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.layers_outlined),
                    label: Text('All · ${widget.evaluation.questions.length}'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.school_outlined),
                    label: Text('Learned · ${widget.learned.length}'),
                  ),
                ],
                selected: {_learnedOnly},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: (s) =>
                    setState(() => _learnedOnly = s.single),
              ),
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _setup),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'Start · $_count ${_count == 1 ? 'question' : 'questions'}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, Widget child) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// What a timed exam will be: questions and time, and that nothing is
/// revealed until the end.
class _TimedRules extends StatelessWidget {
  final int count;

  const _TimedRules(this.count);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = _perQuestion * count;
    final h = limit.inHours, m = limit.inMinutes % 60;
    final time = [if (h > 0) '$h h', if (m > 0 || h == 0) '$m min'].join(' ');
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count questions · $time',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The clock starts now and keeps running if you leave. '
                    'Answers are revealed at the end.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
