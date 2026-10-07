import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/attempt.dart';
import '../../domain/entities/evaluation.dart';
import '../../domain/usecases/get_evaluations.dart';
import '../../domain/usecases/get_history.dart';
import 'exam_page.dart';
import 'study_page.dart';

// Layout follows flutter_easy_refresh v4 example: page/sample/sample_page.dart
class EvaluationsPage extends StatefulWidget {
  const EvaluationsPage({super.key});

  @override
  State<EvaluationsPage> createState() => _EvaluationsPageState();
}

class _EvaluationsPageState extends State<EvaluationsPage> {
  final _getEvaluations = Get.find<GetEvaluations>();
  final _getHistory = Get.find<GetHistory>();
  List<Evaluation> _evaluations = [];
  Map<String, List<Attempt>> _history = {};

  Future<void> _load() async {
    final evaluations = await _getEvaluations();
    final history = {
      for (final e in evaluations) e.id: await _getHistory(e.id),
    };
    if (!mounted) return;
    setState(() {
      _evaluations = evaluations;
      _history = history;
    });
  }

  Future<void> _open(Widget page) async {
    Get.back(); // close the mode sheet
    await Get.to(() => page);
    await _load(); // pick up new scores
  }

  void _showModes(Evaluation evaluation) {
    final history = _history[evaluation.id] ?? [];
    Get.bottomSheet(
      Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SafeArea(
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
                title: Text('Historial (${history.length})'),
                children: [
                  if (history.isEmpty)
                    const ListTile(title: Text('Sin intentos todavía')),
                  for (final a in history)
                    ListTile(
                      dense: true,
                      title: Text('${a.correct}/${a.total} · ${a.percent}%'),
                      subtitle: Text(_formatDate(a.date)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EasyRefresh(
        refreshOnStart: true,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Evaluaciones')),
            if (_evaluations.isEmpty)
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

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
