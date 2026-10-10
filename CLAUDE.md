# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter app for studying question banks ("evaluaciones"). UI text is in English. Banks are bundled as JSON assets. There is no backend.

## Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test                                  # all tests
flutter test test/evaluations_test.dart       # validate every bank in assets/evaluations/
flutter test test/question_test.dart          # domain scoring rule
flutter test test/history_repository_test.dart # SQLite paging + prefs migration (sqflite_common_ffi)
```

Android release (signed) to Firebase App Distribution (project `gaala-evaluator`):

```bash
scripts/distribute.sh "release notes" [testers-group]  # flutter build apk --release + upload
```

Signing reads `android/key.properties` (`keyAlias=evaluator`, `storeFile=evaluator-keystore.jks` in `android/app/`); both are git-ignored, so without them the release build falls back to debug keys. Bump `version:` in `pubspec.yaml` before each upload:

- Each release bumps only the **patch** (third digit) and the build number: `1.8.0+9` → `1.8.1+10`. Releases are small and frequent, so minor/major jumps would run out fast.
- Bump the minor (`1.9.0`) or major (`2.0.0`) only when the user asks for it.
- The build number (after `+`) always goes up by 1, it is Android's `versionCode`.

Requires Flutter ≥ 3.47 (easy_refresh 4.x needs it).

## Architecture

Clean Architecture in three layers. Dependencies only point inward: `presentation → domain ← data`. **`domain/` must not import Flutter or any package.**

- `lib/domain/`: pure Dart.
  - `entities/`: `Evaluation`, `Question` (holds the scoring rule `isCorrect`), `HistoryEntry` (sealed: `StudySession` with a duration, `Attempt` with a score; both keep the evaluation title).
  - `repositories/`: abstract `EvaluationRepository`, `HistoryRepository`.
  - `usecases/`: `GetEvaluations`, `GetHistory` (paged, all evaluations), `GetAttempts` (one evaluation), `SaveHistoryEntry`, `ClearHistory` (callable classes).
- `lib/data/`:
  - `models/`: `EvaluationModel`/`QuestionModel` extend the entities and add JSON parsing.
  - `repositories/asset_evaluation_repository.dart`: finds evaluations through `AssetManifest`, so **dropping a new JSON in `assets/evaluations/` is enough**: no index file and no code change.
  - `repositories/sqlite_history_repository.dart`: history in SQLite (`sqflite`, `evaluator.db`, table `history` indexed by date), so pages are `LIMIT/OFFSET` queries. Android/iOS/macOS only. `injection.dart`'s `migratePrefsHistory` moves the old `history_<evaluationId>` prefs lists into it once.
- `lib/injection.dart`: `initDependencies()` registers repositories and use cases with GetX (`Get.put`). It is the only file that knows the concrete repository classes. Pages get use cases with `Get.find<...>()`.
- `lib/main.dart`: calls `initDependencies()`, then `GetMaterialApp`, and the theme from `ThemeController`.
- `lib/presentation/`:
  - `controllers/reading_settings_controller.dart`: `ReadingSettingsController` (GetX): text size, left/justified alignment, vertical/horizontal paging, shuffle questions/options, reveal at end, show the study slider, hide answers in study mode. Persisted in `shared_preferences` (`reading_*` keys). `prepare()` shuffles a question list for a new study session.
  - `controllers/bookmarks_controller.dart`: `BookmarksController` (GetX): bookmarked question ids per evaluation in `shared_preferences` (`bookmarks_<evaluationId>`). `LearnedController` subclasses it with the `learned_<evaluationId>` key: questions marked as learned.
  - `controllers/highlights_controller.dart`: `HighlightsController` (GetX): study-mode neon highlights as `[start, end, color]` ranges per question and field (`q`, `o<i>`, `e`) in `shared_preferences` (`highlights_<evaluationId>`). `apply()` is the pure range logic.
  - `controllers/progress_controller.dart`: `ProgressController` (GetX): unfinished study/exam sessions (question order, option order, current index, exam score, and for exams whether a retry reshuffles plus the time limit and deadline) in `shared_preferences` (`progress_study_<id>`, `progress_exam_<id>`). Both pages resume from it; the exam clears it on finish. Discarded if the evaluation JSON no longer matches.
  - `controllers/theme_controller.dart`: `ThemeModel` + `ThemeController` (GetX), mode (incl. AMOLED: dark with black surfaces) and seed color persisted in `shared_preferences` (`theme_mode`, `theme_amoled`, `theme_color`).
  - `widgets/question_card.dart`: `QuestionCard` + `OptionState` (no Card, text on the page background), shared by study and exam modes. `textScale` multiplies the system text scale. Optional `textBuilder` replaces each `Text` (study mode passes `HighlightableText`).
  - `widgets/highlightable_text.dart`: `HighlightableText` draws highlights and is always selectable through `SelectionArea` (long press; `SelectionListener` gives the offsets), whose toolbar has the neon colors, an eraser, Copy and Translate. `translate()` translates English → Spanish on device with ML Kit (`google_mlkit_translation`, the model downloads on first use) paragraph by paragraph and shows it in a bottom sheet; other platforms open translate.google.com. Not `SelectableText`: its inner scrollable eats the pager's drags.
  - `widgets/reading_settings_panel.dart`: reading settings controls, used by Settings → Reading, the study sheet, and as a bottom sheet (`showSheet`) from the exam AppBar with `textSizeOnly`.
  - `pages/home.dart`: bottom-nav PageView (Home (rocket) / History / Settings).
  - `pages/evaluations_page.dart`: Home tab, pull-to-refresh list (kept alive in the PageView; ClassicHeader with explicit colors, clamping, under the large AppBar via `HeaderLocator.sliver(clearExtent: false)`). Each item is a card tinted `secondaryContainer` (`_EvaluationCard`): a ring with the learned %, title, question count and last score, then Study / Exam list rows showing `n/total` while a session is in progress. A new exam opens the setup sheet (`widgets/exam_setup_sheet.dart`, `showExamSetup` → `ExamSetup`): Full (all, shuffled or in order), Quick (10/20/30 at random) or Timed (60 at random, 2 min each = 2 h), and All / Learned only when some are learned.
  - `pages/history_page.dart`: History tab, EasyRefresh (header under the large AppBar via `HeaderLocator.sliver(clearExtent: false)`) with pages of 30 (`onLoad` until a short page → `noMore`). Not kept alive, so it reloads on each visit.
  - `widgets/refresh_indicators.dart`: `classicHeader` (clamping, `IndicatorPosition.locator`)/`classicFooter` with explicit colors, and `formatDate`.
  - `pages/study_page.dart`: **study mode**. A PageView with correct answers highlighted. The AppBar saves/removes the current question and marks it as learned. Learned questions are hidden by default (shown when "Show learned" in the sheet's Settings tab, or when all are learned); marking applies on the next session or filter change. A persistent bottom sheet (`DraggableScrollableSheet`, always peeking with a handle and tabs) holds (as icon tabs) Settings, Saved (jump to/remove a saved question, "Study saved only" filters the pager to a snapshot of them) and Highlights (jump to a highlighted question), plus a Translate icon that translates the current question and options. The AppBar search (`_QuestionSearch`, accent-insensitive) jumps to a question. With "Hide answers", answers and explanation stay hidden until an option or "Show answer" is tapped. Settings holds the reading settings (direction comes from them). In vertical mode a long card hands its overscroll to the pager as a real `position.drag()` (holding still keeps the offset; while the pager is off its page the card is held (`_HeldPhysics`), so moving back returns the pager to its page before the card scrolls again; release snaps with page physics; lifting the finger always releases the pager, since a card that flings back sends no ScrollEnd until its fling stops), and a zigzag line (`_Zigzag`) sits centered in the blank space at the bottom of the previous page (the pager runs behind the bottom sheet and each page ends in a peek-sized space, so a cancelled swipe tucks it behind the sheet). A page entering from above opens at its end (reversed scroll, decided by the pager's real position); the pager snaps with a stiff spring (`_SnapPhysics`), and on finger up `_releasePager` lifts the snap's inherited "ignore touches" flag, so a swipe during the snap scrolls the arriving card instead of dragging the pager on (which left both pages cut). A slider pill (number, M3 2024 `Slider(year2023: false)`, total) floats above the bottom sheet, hides while the sheet is open (and from the settings), follows the cards' scroll behind the sheet (down hides, up shows; on release it finishes towards the nearer side), and jumps between questions; pages add its height to their bottom space. Text is always selectable (long press → highlight with neon colors); in horizontal mode the pager runs with half the touch slop, because `SelectionArea`'s horizontal drag would otherwise win the swipe on Android. Study time (paused in background) is saved as a `StudySession` on leave if ≥ 10 s.
  - `pages/exam_page.dart`: **evaluation mode**. Answers are revealed once the user has selected `answers.length` options, then a "Next" button. With "Reveal at the end" nothing is revealed (single answers can be swapped) and the score is counted on "Next". `ExamSetup.pick` chooses the questions (shuffled with their options unless "In order"). A timed exam shows a countdown chip in the AppBar (red in the last 5 min), forces "Reveal at the end", keeps an absolute deadline (it runs while the app is closed) and finishes itself with "Time's up". Retry asks the same questions again, reshuffled. The AppBar only offers text size and "Finish exam" (confirm, unanswered count as wrong). A final score screen saves an `Attempt` through `SaveHistoryEntry`.
  - `pages/theme_page.dart`: theme picker, opened from Settings → Theme.
  - `pages/settings_page.dart`: Settings tab (large title), a list with Theme, Reading (reading settings) and Storage (clear all highlights / all bookmarks / all learned / the history, with a confirm dialog).

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
