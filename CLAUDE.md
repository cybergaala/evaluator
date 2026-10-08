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
flutter test test/question_test.dart          # domain scoring rule
```

Requires Flutter ≥ 3.47 (easy_refresh 4.x needs it).

## Architecture

Clean Architecture in three layers. Dependencies only point inward: `presentation → domain ← data`. **`domain/` must not import Flutter or any package.**

- `lib/domain/`: pure Dart.
  - `entities/`: `Evaluation`, `Question` (holds the scoring rule `isCorrect`), `Attempt`.
  - `repositories/`: abstract `EvaluationRepository`, `HistoryRepository`.
  - `usecases/`: `GetEvaluations`, `GetHistory`, `SaveAttempt` (callable classes).
- `lib/data/`:
  - `models/`: `EvaluationModel`/`QuestionModel`/`AttemptModel` extend the entities and add JSON parsing.
  - `repositories/asset_evaluation_repository.dart`: finds evaluations through `AssetManifest`, so **dropping a new JSON in `assets/evaluations/` is enough**: no index file and no code change.
  - `repositories/prefs_history_repository.dart`: score history in `shared_preferences` under the key `history_<evaluationId>`.
- `lib/injection.dart`: `initDependencies()` registers repositories and use cases with GetX (`Get.put`). It is the only file that knows the concrete repository classes. Pages get use cases with `Get.find<...>()`.
- `lib/main.dart`: calls `initDependencies()`, then `GetMaterialApp`, and the theme from `ThemeController`.
- `lib/presentation/`:
  - `controllers/reading_settings_controller.dart`: `ReadingSettingsController` (GetX): text size, vertical/horizontal paging, shuffle questions/options, reveal at end, show the study slider. Persisted in `shared_preferences` (`reading_*` keys). `prepare()` shuffles a question list for a new session.
  - `controllers/bookmarks_controller.dart`: `BookmarksController` (GetX): bookmarked question ids per evaluation in `shared_preferences` (`bookmarks_<evaluationId>`).
  - `controllers/highlights_controller.dart`: `HighlightsController` (GetX): study-mode neon highlights as `[start, end, color]` ranges per question and field (`q`, `o<i>`, `e`) in `shared_preferences` (`highlights_<evaluationId>`). `apply()` is the pure range logic.
  - `controllers/theme_controller.dart`: `ThemeModel` + `ThemeController` (GetX), mode and seed color persisted in `shared_preferences` (`theme_mode`, `theme_color`).
  - `widgets/question_card.dart`: `QuestionCard` + `OptionState`, shared by study and exam modes. `textScale` multiplies the system text scale. Optional `textBuilder` replaces each `Text` (study mode passes `HighlightableText`).
  - `widgets/highlightable_text.dart`: `HighlightableText` draws highlights; when `selectable`, its selection toolbar has the neon colors, an eraser and Copiar. Plain `Text.rich` otherwise, because `SelectableText` wins horizontal drags on Android.
  - `widgets/reading_settings_panel.dart`: reading settings controls, used by Ajustes → Evaluación and as a bottom sheet (`showSheet`) from the study/exam AppBar.
  - `pages/home.dart`: bottom-nav PageView (Evaluaciones / Ajustes).
  - `pages/evaluations_page.dart`: pull-to-refresh list (kept alive in the PageView; ClassicHeader with explicit colors, clamping on start). Tapping an item opens a sheet with Estudiar / Evaluación / Historial.
  - `pages/study_page.dart`: **study mode**. A PageView with correct answers highlighted. The AppBar saves/removes the current question. A persistent bottom sheet (`DraggableScrollableSheet`, always peeking with a handle and tabs) holds Guardadas (jump to/remove a saved question) and Ajustes (reading settings; direction comes from them). In vertical mode a long card hands its overscroll to the pager. A slider above the pager (right under the AppBar, hideable from the settings) jumps between questions. An AppBar marker button toggles marker mode (text selectable → highlight with neon colors).
  - `pages/exam_page.dart`: **evaluation mode**. Answers are revealed once the user has selected `answers.length` options, then a "Siguiente" button. With "revelar al final" nothing is revealed (single answers can be swapped) and the score is counted on "Siguiente". A final score screen saves an `Attempt` through `SaveAttempt`.
  - `pages/theme_page.dart`: theme picker, opened from Ajustes → Tema.
  - `pages/settings_page.dart`: Ajustes tab (large title), a list with Tema, Evaluación (reading settings) and Memoria (clear all highlights / all bookmarks, with a confirm dialog).

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
