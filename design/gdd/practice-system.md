---
status: reverse-documented
source: shuyi_playland/scripts/ui/practice_screen.gd + scripts/question_types/question_renderer.gd
date: 2026-05-18
verified-by: user
---

# Practice System Design

## Overview

The practice system manages all question-answering sessions. It supports six session modes, delegates question rendering to `QuestionRenderer`, records answers through `AppState`, and calculates results via `ContentService.calculate_result()`. It is the app's core loop: start session → answer questions → see results → earn rewards.

## Player Fantasy

Students pick how they want to practice — follow the level path, drill weak areas, take a test, or review mistakes — and feel immediate progress when they finish.

## Detailed Rules

### Session Modes

| Mode | ID | Source | Questions | Purpose |
|------|----|--------|-----------|---------|
| Level | `level` | `ContentService.get_questions_for_level(level_id)` | 10 (configurable per level) | Follow the level path |
| Special Practice | `special_practice` | `ContentService.get_questions_by_filters(filters)` | 10 | Drill specific grade/module/knowledge point |
| Random Practice | `random_practice` | `ContentService.get_random_questions(10)` | 10 | Random mixed practice |
| Mock Test | `mock_test` | `ContentService.get_mock_test_questions(grade_id, 10)` | 10 | Simulated test (only `include_in_mock_test` questions) |
| Wrong Retry | `wrong_retry` | `AppState.get_wrong_question_ids_for_retry(10)` → `ContentService.get_wrong_retry_questions(ids)` | 10 (or fewer if not enough wrong answers) | Review mistakes |
| Mini Game | `mini_game` | Hardcoded in `MiniGameScreen` | 5 per mode (3 modes) | Quick-play reward break |

### Question Flow

1. `PracticeScreen.start_session(config)` receives config with `mode`, optionally `level_id`, `grade_id`, `knowledge_point_id`, `question_ids`
2. `_resolve_questions(config)` fetches questions from ContentService based on mode
3. Question index starts at 0; `show_question()` renders current question via `QuestionRenderer.render()`
4. Student selects an option or types an answer, then submits
5. `ContentService.evaluate_answer(question, user_answer)` checks correctness
6. `AppState.record_answer(question_id, is_correct, user_answer)` records the result
7. If incorrect, `AppState._record_wrong_question()` adds to wrong book
8. After all questions, `_finish_session()` calculates results via `ContentService.calculate_result()`
9. `AppState.complete_session(mode, level_id, correct_count, total_count, result)` updates progress, tasks, achievements
10. Signal `session_finished(summary)` emitted back to App for result screen navigation

### Answer Evaluation

- **Choice / True-False**: Exact string match after `strip_edges().to_lower()`
- **Fill-blank / Mental math**: Numeric comparison (`is_equal_approx`) if both are valid floats, otherwise exact text match
- **Complex types** (matching, drag_drop, sorting, shape_puzzle, application, multi_step): Normalized string comparison — spaces removed, `，` → `,`, `→` or `-` → `>`, `=` removed, then lowercased

### Result Calculation

**Formula** (`ContentService.calculate_result()`):
```
accuracy = correct_count / max(1, total_count)
stars = best matching threshold from star_rules
reward = level_data.reward (or mode-specific default from reward_rules) if mode == "mock_test" or "random_practice" or "mini_game" use mode-specific reward_override
```

## Formulas

- `accuracy = correct_count / max(1.0, total_count)`
- `stars = max threshold where accuracy >= accuracy_gte` (from `star_rules.json`)
- `reward.exp` and `reward.gold` per mode (see `reward_rules.json` or level override)
- Level completion tracks: `levels_completed_count += 1` if mode is level/practice/wrong_retry/test
- `study_minutes += 5` per session (hardcoded estimate)

## Edge Cases

- **Wrong retry with fewer than 10 wrong answers**: Returns available wrong answers only (up to limit)
- **Double sign-in prevention**: `AppState.mark_sign_in()` checks if `last_sign_in == today` before awarding
- **Already-claimed task**: Returns error "奖励已经领取过了"
- **Already-claimed achievement**: Returns error "成就奖励已经领取"
- **Achievement progress tracking**: Evaluated after every answer and every session completion
- **Answer history cap**: Capped at 200 entries, oldest sliced off

## Dependencies

- ContentService (question fetching, answer evaluation, result calculation)
- AppState (answer recording, session completion, wrong book, task updates)
- QuestionRenderer (question UI rendering)
- GrowthSystem (via AppState — `_evaluate_achievements()` is called from `record_answer()` and `complete_session()`; achievement evaluation crosses into the growth system domain)

## Tuning Knobs

| Knob | Current Value | Location |
|------|---------------|----------|
| Questions per session (non-level) | 10 | `practice_screen.gd` (hardcoded) |
| Questions per mini-game mode | 5 | `mini_game_screen.gd` (hardcoded) |
| Estimated study minutes per session | 5 | `AppState.complete_session()` |
| Answer history cap | 200 entries | `AppState.record_answer()` |
| Wrong retry limit | 10 | `AppState.get_wrong_question_ids_for_retry(10)` |

## Acceptance Criteria

- [ ] All 6 session modes start, present questions, and finish with a result
- [ ] Answer evaluation correctly handles choice, fill-blank, mental math, and complex types
- [ ] Accuracy calculation works for 0/10, 10/10, and edge cases
- [ ] Star rating correctly applies thresholds (1★ any completion, 2★ ≥80%, 3★ ≥95%)
- [ ] Wrong book entries are created on wrong answers and removed from retry when mastered
- [ ] Task progress increments correctly for each session mode