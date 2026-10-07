import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/evaluation.dart';
import '../../domain/repositories/evaluation_repository.dart';
import '../models/evaluation_model.dart';

const evaluationsDir = 'assets/evaluations/';

/// Every JSON file under [evaluationsDir], found through the asset manifest.
class AssetEvaluationRepository implements EvaluationRepository {
  final AssetBundle _bundle;

  const AssetEvaluationRepository(this._bundle);

  @override
  Future<List<Evaluation>> getAll() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(evaluationsDir) && p.endsWith('.json'))
            .toList()
          ..sort();
    return [
      for (final p in paths)
        EvaluationModel.fromJson(jsonDecode(await _bundle.loadString(p))),
    ];
  }
}
