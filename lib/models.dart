import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const evaluationsDir = 'assets/evaluations/';

class Question {
  final int id;
  final String question;
  final List<String> options;
  final List<int> answers;
  final String? explanation;

  const Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answers,
    this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as int,
    question: json['question'] as String,
    options: List<String>.from(json['options'] as List),
    answers: List<int>.from(json['answers'] as List),
    explanation: json['explanation'] as String?,
  );
}

class Evaluation {
  final String id;
  final String title;
  final String? description;
  final List<Question> questions;

  const Evaluation({
    required this.id,
    required this.title,
    this.description,
    required this.questions,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) => Evaluation(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    questions: [
      for (final q in json['questions'] as List)
        Question.fromJson(q as Map<String, dynamic>),
    ],
  );
}

/// Every JSON file under [evaluationsDir], found through the asset manifest.
Future<List<Evaluation>> loadEvaluations() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths =
      manifest
          .listAssets()
          .where((p) => p.startsWith(evaluationsDir) && p.endsWith('.json'))
          .toList()
        ..sort();
  return [
    for (final p in paths)
      Evaluation.fromJson(jsonDecode(await rootBundle.loadString(p))),
  ];
}

class Attempt {
  final DateTime date;
  final int correct;
  final int total;

  const Attempt(this.date, this.correct, this.total);

  int get percent => total == 0 ? 0 : (correct * 100 / total).round();

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'correct': correct,
    'total': total,
  };

  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
    DateTime.parse(json['date'] as String),
    json['correct'] as int,
    json['total'] as int,
  );
}

String _historyKey(String evaluationId) => 'history_$evaluationId';

/// Newest first.
Future<List<Attempt>> loadHistory(String evaluationId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_historyKey(evaluationId)) ?? [];
  return [for (final s in raw.reversed) Attempt.fromJson(jsonDecode(s))];
}

Future<void> saveAttempt(String evaluationId, Attempt attempt) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _historyKey(evaluationId);
  final raw = prefs.getStringList(key) ?? [];
  await prefs.setStringList(key, [...raw, jsonEncode(attempt.toJson())]);
}
