import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/usecases/get_evaluations.dart';
import '../../domain/usecases/get_attempts.dart';
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

  /// Opens [mode] for [e], asking first whether to resume or start over
  /// when there is an unfinished session.
  Future<void> _start(String mode, Evaluation e) async {
    final saved = ProgressController.i.load(mode, e);
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
    }
    await _open(
      mode == 'study' ? StudyPage(evaluation: e) : ExamPage(evaluation: e),
    );
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
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(e.title),
                        subtitle: Text(
                          [
                            '${e.questions.length} preguntas',
                            if (last != null) 'último: ${last.percent}%',
                            if (study != null)
                              'estudio: ${study.index + 1}/${study.questions.length}',
                            if (exam != null)
                              'evaluación: ${exam.index + 1}/${exam.questions.length}',
                          ].join(' · '),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.menu_book),
                                label: const Text('Estudiar'),
                                onPressed: () => _start('study', e),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.assignment),
                                label: const Text('Evaluar'),
                                onPressed: () => _start('exam', e),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
