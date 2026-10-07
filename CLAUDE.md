# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter app for studying question banks ("evaluaciones"). UI text is in Spanish. Banks are bundled as JSON assets. There is no backend.

## Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test                                  # all tests
flutter test test/evaluations_test.dart       # validate every bank in assets/evaluations/
```

Requires Flutter ≥ 3.47 (easy_refresh 4.x needs it).

## Architecture

- `lib/models.dart`: `Evaluation`/`Question` parsing, `loadEvaluations()` and the score history (`Attempt`, `loadHistory`, `saveAttempt`). Evaluations are discovered through `AssetManifest`, so **dropping a new JSON in `assets/evaluations/` is enough**: no index file and no code change. History lives in `shared_preferences` under the key `history_<evaluationId>`.
- `lib/main.dart`: `GetMaterialApp`, the theme from `ThemeController` (GetX, in `pages/theme_page.dart`), and the default EasyRefresh header texts.
- `lib/pages/`:
  - `home.dart`: bottom-nav PageView (Evaluaciones / Tema).
  - `evaluations_page.dart`: pull-to-refresh list. Tapping an item opens a sheet with Estudiar / Evaluación / Historial.
  - `study_page.dart`: **study mode**. A PageView with correct answers highlighted. The AppBar button toggles vertical (TikTok-style) / horizontal scrolling. It also defines `QuestionCard`, which both modes share.
  - `exam_page.dart`: **evaluation mode**. Answers are revealed once the user has selected `answers.length` options, then a "Siguiente" button. A final score screen saves an `Attempt`.

UI patterns are copied from the [flutter_easy_refresh v4 example](https://github.com/xuelongqy/flutter_easy_refresh/tree/v4/example/lib) (`page/home.dart`, `page/sample/sample_page.dart`, `page/sample/page_view_page.dart`, `page/more/theme_page.dart`). Follow that example when adding UI.

## Evaluation JSON format

One file per evaluation: `assets/evaluations/<id>.json`.

```json
{
  "id": "biologia-parcial-1",
  "title": "Biología – Parcial 1",
  "description": "Opcional",
  "questions": [
    {
      "id": 1,
      "question": "¿Cuál es la unidad básica de la vida?",
      "options": ["Átomo", "Célula", "Tejido", "Órgano"],
      "answers": [1],
      "explanation": "Opcional"
    }
  ]
}
```

| Field | Type | Rules |
|---|---|---|
| `id` | string | kebab-case, **must equal the file name** without `.json` |
| `title` | string | shown in the list |
| `description` | string? | optional |
| `questions[].id` | int | unique within the file, sequential from 1 |
| `questions[].question` | string | question text |
| `questions[].options` | string[] | ≥ 2 options, in the source order |
| `questions[].answers` | int[] | **0-based** indexes into `options`, ≥ 1 entry, no duplicates; more than one = multi-answer question |
| `questions[].explanation` | string? | optional, shown after answering / in study mode |

### Converting a question bank (PDF, Excel, JSON) into this format

- Keep the original wording; don't rephrase or translate.
- Strip option prefixes like `a)`, `B.`, `1)`. The app adds its own A, B, C letters.
- Map lettered answers to indexes (`a` → 0, `b` → 1, …). True/false questions become `"options": ["Verdadero", "Falso"]`.
- Leave out `explanation` unless the source has one.
- If an answer is missing or unclear in the source, ask instead of guessing.
- After writing the file, run `flutter test test/evaluations_test.dart`.
