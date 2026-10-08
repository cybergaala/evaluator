import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/usecases/get_evaluations.dart';
import '../../domain/usecases/get_attempts.dart';
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
      // ponytail: last 20 per evaluation, the Historial tab has the rest.
      for (final e in evaluations) e.id: await _getAttempts(e.id, limit: 20),
    };
    if (!mounted) return;
    setState(() {
      _evaluations = evaluations;
      _history = history;
      _loaded = true;
    });
  }

  Future<void> _open(Widget page) async {
    Navigator.pop(context); // close the mode sheet
    await Get.to(() => page);
    await _load(); // pick up new scores
  }

  void _showModes(Evaluation evaluation) {
    final history = _history[evaluation.id] ?? [];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                evaluation.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Estudiar'),
              subtitle: const Text('Respuestas resaltadas'),
              onTap: () => _open(StudyPage(evaluation: evaluation)),
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Evaluación'),
              subtitle: const Text('Responde y revisa cada pregunta'),
              onTap: () => _open(ExamPage(evaluation: evaluation)),
            ),
            ExpansionTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              children: [
                if (history.isEmpty)
                  const ListTile(title: Text('Sin intentos todavía')),
                for (final a in history)
                  ListTile(
                    dense: true,
                    title: Text('${a.correct}/${a.total} · ${a.percent}%'),
                    subtitle: Text(formatDate(a.date)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: EasyRefresh(
        header: classicHeader(context),
        refreshOnStart: true,
        // Clamping: the start refresh overlays the list instead of pushing it
        // down (same as the example's refresh_on_start_page.dart).
        refreshOnStartHeader: classicHeader(context, clamping: true),
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Inicio')),
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
                return ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(e.title),
                  subtitle: Text(
                    [
                      '${e.questions.length} preguntas',
                      if (last != null) 'último: ${last.percent}%',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showModes(e),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
