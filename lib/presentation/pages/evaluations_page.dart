import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/usecases/get_evaluations.dart';
import '../../domain/usecases/get_attempts.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/progress_controller.dart';
import '../widgets/refresh_indicators.dart';
import 'exam_page.dart';
import 'study_page.dart';

// Layout follows flutter_easy_refresh v4 example: page/sample/sample_page.dart
class EvaluationsPage extends StatefulWidget {
  const EvaluationsPage({super.key});

  @override
  State<EvaluationsPage> createState() => _EvaluationsPageState();
}

class _EvaluationsPageState extends State<EvaluationsPage>
    with AutomaticKeepAliveClientMixin {
  // Keeps the list alive in the home PageView so switching tabs doesn't
  // rebuild the page and refresh again.
  @override
  bool get wantKeepAlive => true;

  final _getEvaluations = Get.find<GetEvaluations>();
  final _getAttempts = Get.find<GetAttempts>();
  List<Evaluation> _evaluations = [];
  Map<String, List<Attempt>> _history = {};
  bool _loaded = false;

  Future<void> _load() async {
    final evaluations = await _getEvaluations();
    final history = {
      // Only the last attempt, for the subtitle; the Historial tab has the rest.
      for (final e in evaluations) e.id: await _getAttempts(e.id, limit: 1),
    };
    if (!mounted) return;
    setState(() {
      _evaluations = evaluations;
      _history = history;
      _loaded = true;
    });
  }

  Future<void> _open(Widget page) async {
    await Get.to(() => page);
    await _load(); // pick up new scores
  }

  /// Ids of [e]'s questions marked as learned (ignores removed questions).
  Set<int> _learned(Evaluation e) => LearnedController.i.of(e.id).intersection({
    for (final q in e.questions) q.id,
  });

  /// Opens [mode] for [e], asking first whether to resume or start over
  /// when there is an unfinished session, and for a new evaluation, whether
  /// to ask only the learned questions.
  Future<void> _start(String mode, Evaluation e) async {
    final saved = ProgressController.i.load(mode, e);
    var resumed = false;
    if (saved != null) {
      final resume = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Continuar'),
                subtitle: Text(
                  'Pregunta ${saved.index + 1} de ${saved.questions.length}',
                ),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Empezar de nuevo'),
                subtitle: const Text('Se descarta el progreso actual'),
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      );
      if (resume == null) return;
      if (!resume) ProgressController.i.clear(mode, e.id);
      resumed = resume;
    }
    if (mode == 'study') return _open(StudyPage(evaluation: e));
    final learned = _learned(e);
    var onlyLearned = false;
    if (!resumed && learned.isNotEmpty && mounted) {
      final choice = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Todas las preguntas'),
                subtitle: Text('${e.questions.length} preguntas'),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Solo aprendidas'),
                subtitle: Text('${learned.length} preguntas'),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      onlyLearned = choice;
    }
    await _open(ExamPage(evaluation: e, only: onlyLearned ? learned : null));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: EasyRefresh(
        header: classicHeader(context),
        refreshOnStart: true,
        refreshOnStartHeader: classicHeader(context),
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Inicio')),
            const HeaderLocator.sliver(clearExtent: false),
            if (_loaded && _evaluations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('No hay evaluaciones en assets/evaluations/'),
                ),
              ),
            SliverList.builder(
              itemCount: _evaluations.length,
              itemBuilder: (context, index) {
                final e = _evaluations[index];
                final history = _history[e.id] ?? [];
                final last = history.isEmpty ? null : history.first;
                final study = ProgressController.i.load('study', e);
                final exam = ProgressController.i.load('exam', e);
                final learned = _learned(e).length;
                return _EvaluationCard(
                  evaluation: e,
                  learned: learned,
                  lastPercent: last?.percent,
                  study: study == null
                      ? null
                      : '${study.index + 1}/${study.questions.length}',
                  exam: exam == null
                      ? null
                      : '${exam.index + 1}/${exam.questions.length}',
                  onStudy: () => _start('study', e),
                  onExam: () => _start('exam', e),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// An evaluation in the list, on a tint of the theme color: a ring with the
/// learned share, the title, the question count and last score, then a row
/// per mode with its progress when a session is in progress.
class _EvaluationCard extends StatelessWidget {
  final Evaluation evaluation;
  final int learned;
  final int? lastPercent;
  final String? study;
  final String? exam;
  final VoidCallback onStudy;
  final VoidCallback onExam;

  const _EvaluationCard({
    required this.evaluation,
    required this.learned,
    required this.lastPercent,
    required this.study,
    required this.exam,
    required this.onStudy,
    required this.onExam,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCard = scheme.onSecondaryContainer;
    final faint = onCard.withValues(alpha: 0.12);
    final total = evaluation.questions.length;
    final share = total == 0 ? 0.0 : learned / total;
    Widget mode(
      IconData icon,
      String title,
      String? progress,
      VoidCallback onTap,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null)
            Text(progress, style: theme.textTheme.labelLarge),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      iconColor: onCard,
      textColor: onCard,
      onTap: onTap,
    );
    final divider = Divider(height: 1, color: faint);
    return Card(
      color: scheme.secondaryContainer,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Tooltip(
                  message: '$learned de $total aprendidas',
                  child: SizedBox.square(
                    dimension: 56,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: share,
                          strokeWidth: 5,
                          backgroundColor: faint,
                          // ignore: deprecated_member_use
                          year2023: false,
                        ),
                        Center(
                          child: Text(
                            '${(share * 100).round()}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: onCard,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evaluation.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: onCard,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '$total preguntas',
                          if (lastPercent != null) 'último $lastPercent%',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: onCard.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          divider,
          mode(Icons.menu_book, 'Estudiar', study, onStudy),
          divider,
          mode(Icons.assignment, 'Evaluar', exam, onExam),
        ],
      ),
    );
  }
}
