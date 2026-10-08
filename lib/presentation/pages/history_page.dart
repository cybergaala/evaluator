import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/history_entry.dart';
import '../../domain/usecases/get_history.dart';
import '../widgets/refresh_indicators.dart';

// Layout follows flutter_easy_refresh v4 example: page/sample/sample_page.dart
// Not kept alive: the home PageView rebuilds it on each visit, so new
// sessions and scores show up without a manual refresh.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _pageSize = 30;
  final _getHistory = Get.find<GetHistory>();
  final List<HistoryEntry> _entries = [];
  bool _loaded = false;

  Future<IndicatorResult> _refresh() async {
    final page = await _getHistory(offset: 0, limit: _pageSize);
    if (!mounted) return IndicatorResult.none;
    setState(() {
      _entries
        ..clear()
        ..addAll(page);
      _loaded = true;
    });
    return page.length < _pageSize
        ? IndicatorResult.noMore
        : IndicatorResult.success;
  }

  Future<IndicatorResult> _loadMore() async {
    final page = await _getHistory(offset: _entries.length, limit: _pageSize);
    if (!mounted) return IndicatorResult.none;
    setState(() => _entries.addAll(page));
    return page.length < _pageSize
        ? IndicatorResult.noMore
        : IndicatorResult.success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EasyRefresh(
        header: classicHeader(context),
        footer: classicFooter(context),
        refreshOnStart: true,
        refreshOnStartHeader: classicHeader(context, clamping: true),
        onRefresh: _refresh,
        onLoad: _loadMore,
        child: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Historial')),
            if (_loaded && _entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Sin historial todavía')),
              ),
            SliverList.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) => _tile(_entries[index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(HistoryEntry entry) {
    final (icon, detail) = switch (entry) {
      StudySession(:final duration) => (
        Icons.menu_book,
        'Estudio · ${formatDuration(duration)}',
      ),
      Attempt(:final correct, :final total, :final percent) => (
        Icons.assignment,
        'Evaluación · $correct/$total · $percent%',
      ),
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(entry.evaluationTitle),
      subtitle: Text('$detail · ${formatDate(entry.date)}'),
    );
  }
}

/// `45 s`, `12 min`, `1 h 5 min`.
String formatDuration(Duration d) {
  if (d.inMinutes == 0) return '${d.inSeconds} s';
  if (d.inHours == 0) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}
