# ADR-0007: Wrong-Book and Achievement Evaluation Pipeline

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: APPROVED 2026-05-19
> **TD-ADR Review**: APPROVE 2026-05-19
> **Revision 2026-05-19b**: Aligned with shipping `AppState.gd`. Corrected
> wrong-book key (`wrong_book`, not `wrong_questions`), removal mechanism
> (`mastered` soft-flag, not delete), mastered trigger (any correct answer,
> not mode-gated), and achievement evaluation method (single idempotent
> `_evaluate_achievements()`, not split per-answer/per-session). The earlier
> draft proposed forward-looking refactors that conflicted with shipping
> behavior — this revision documents the as-built pipeline.

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (state management, gameplay logic) |
| **Knowledge Risk** | LOW — no post-cutoff APIs used; all logic is pure GDScript Dictionary manipulation |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — Dictionary, Array, and `Time.get_datetime_string_from_system()` are stable across all Godot 4.x versions |
| **Verification Required** | None — all logic is pure GDScript with no engine API dependencies |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — wrong-book and achievement state live in `save_data`), ADR-0003 (Autoload Singleton Pattern — AppState owns this pipeline; ContentService provides achievement definitions), ADR-0004 (JSON Content Pipeline — achievement definitions come from `growth_rules.json`), ADR-0006 (Practice Session State Machine — `record_answer()` is called during EVALUATING; `mark_wrong_question_mastered()` is called by PracticeScreen on correct answers) |
| **Enables** | Growth Progression Engine ADR (TR-growth-006/007/008 — level-up and streak logic share the same idempotent-recomputation pattern established here) |
| **Blocks** | Any story implementing wrong-book recording, achievement evaluation, or wrong-retry session flow |
| **Ordering Note** | Must be Accepted before wrong-book and achievement stories can be marked Ready |

## Context

### Problem Statement
The wrong-book lifecycle and achievement evaluation pipeline are implemented
in `AppState.gd` but undocumented at the architecture level. There is no
defined contract for *when* entries are added or marked mastered, *when*
achievement progress is recomputed, or *which* trigger sites invoke
evaluation. This makes it hard to write testable stories, easy to add a
third trigger site by mistake, and unclear which events affect which state.

### Constraints
- **GDScript-only**: No C# or GDExtension (ADR-0002)
- **AppState owns all mutable player state**: Wrong-book and achievement
  state live in `save_data` (ADR-0001)
- **Offline-first**: All evaluation is local; no server-side validation
- **Single-process**: No concurrency concerns; evaluation is synchronous
- **Achievement definitions are data-driven**: Targets, types, rewards
  come from `growth_rules.json` via ContentService (ADR-0004)
- **PLACEHOLDER-NEXT-SECTION**

### Requirements
- Must add a wrong-book entry on every incorrect answer (with deduplication
  on `question_id` — increment `wrong_count` instead of inserting a new row)
- Must mark a wrong-book entry `mastered = true` when its question is later
  answered correctly in any session mode (not just `wrong_retry`)
- Must recompute achievement progress idempotently after every state change
  that affects an achievement's source counter (answer recorded, sign-in,
  session completed)
- Must derive achievement progress from authoritative `profile` counters,
  not from the trigger event's payload, so re-running evaluation produces
  the same result every time
- Must prevent double-claiming of tasks and achievements at the AppState
  layer (not the UI)
- Must be testable: evaluation callable in isolation with a constructed
  `save_data` and a stubbed `ContentService.get_achievement_definitions()`

## Decision

### Single Idempotent Recompute Method

`AppState.gd` exposes one private method, `_evaluate_achievements()`, that
recomputes progress for every achievement definition by reading from the
`profile` Dictionary. It is invoked from every site that mutates a profile
counter that any achievement watches.

```gdscript
func _evaluate_achievements() -> void
func _record_wrong_question(question_id: String, user_answer: String) -> void
func mark_wrong_question_mastered(question_id: String) -> void
```

**Why one idempotent recompute (not split per-answer/per-session)**:
- Achievement progress sources (`levels_completed_count`, `streak_days`,
  `total_correct_answers`) are stored on the profile and updated by their
  respective mutators *before* `_evaluate_achievements()` runs. The
  evaluator only needs to read current values and decide unlock state.
- A single recompute is impossible to drift — every call produces the
  correct progress regardless of how many other mutations happened
  between calls.
- Adding a new achievement type requires one new `match` arm in
  `_evaluate_achievements()` and one new profile counter — no need to
  audit every trigger site to see if it should also call a new evaluator.
- The pattern is already in shipping code; this ADR documents and locks
  it in rather than refactoring.

### Achievement Definition Schema (from `growth_rules.json`)

Each achievement has:

```
{
  "id": "ach_correct_50_questions",
  "title": "答题小能手",
  "description": "...",
  "type": "correct_answers" | "levels_completed" | "streak_days",
  "target": 50,
  "reward": { "exp": 40, "gold": 25 }
}
```

`type` is the discriminator that selects which profile counter to read.
Adding a new achievement that watches an existing counter requires only a
new entry in `growth_rules.json`. Adding a new achievement that watches a
*new* counter requires one extra `match` arm in `_evaluate_achievements()`.

### Wrong-Book Lifecycle (as-built)

| Event | Action | Code |
|-------|--------|------|
| Answer recorded as incorrect | Add or update entry in `save_data["wrong_book"][question_id]`; increment `wrong_count`; update `last_wrong_time` and `last_answer`; reset `mastered = false` | `AppState._record_wrong_question()` called from `record_answer()` |
| Answer recorded as correct (any mode) | Mark existing entry `mastered = true` (no-op if no entry exists) | `AppState.mark_wrong_question_mastered()` called from `PracticeScreen` after submit when `is_correct == true` |
| Wrong-retry session starts | `get_wrong_question_ids_for_retry(limit)` returns up to `limit` IDs from `wrong_book` filtered by `mastered == false` | Read-only query |
| Wrong-book screen displays an entry | Reads `wrong_book[question_id]` directly via `AppState.save_data` | `wrong_book_screen.gd` |

**Wrong-book entry schema** (in `save_data["wrong_book"]`):

```
{
  "question_id": String,
  "first_wrong_time": String (ISO-like timestamp from Time.get_datetime_string_from_system()),
  "last_wrong_time": String,
  "wrong_count": int,
  "last_answer": String,
  "mastered": bool
}
```

**Why soft-delete (`mastered` flag) instead of hard-delete**: The wrong-book
screen displays "已掌握 / 待重练" status per entry, so historical entries
remain visible after mastery. A correct answer that re-becomes incorrect
later resets `mastered` to `false` via `_record_wrong_question()`. This
gives the student a visible track record of struggles and recoveries.

**Why the mastered trigger lives in PracticeScreen, not AppState**: It's a
single line at the answer-submission site (`practice_screen.gd:114`) and
applies uniformly to every mode. Embedding the mode-check inside AppState
would require passing the current mode through `record_answer()`, which is
otherwise mode-agnostic. Keeping the call at the trigger site preserves
`record_answer()`'s narrow contract.

### Achievement Evaluation Pipeline

`_evaluate_achievements()` runs at every site that modifies a profile
counter watched by an achievement. Current call sites:

| Call Site | Reason |
|-----------|--------|
| `record_answer(question_id, is_correct, user_answer)` | Updates `total_correct_answers` (when `is_correct`) — affects `correct_answers` achievements |
| `mark_sign_in()` | Updates `streak_days` — affects `streak_days` achievements |
| `complete_session(mode, level_id, correct_count, total_count, result)` | Updates `levels_completed_count` — affects `levels_completed` achievements |

**Evaluation algorithm** (single pass over all definitions):

```
for each definition in ContentService.get_achievement_definitions():
    progress_value = match definition.type:
        "levels_completed":  profile.levels_completed_count
        "streak_days":       profile.streak_days
        "correct_answers":   profile.total_correct_answers
    achievements[id].progress = progress_value
    if progress_value >= definition.target:
        achievements[id].unlocked = true
    achievements[id].title = definition.title
    achievements[id].description = definition.description
```

`unlocked` is set to `true` once the threshold is reached and never reset
to `false` — a met achievement stays met even if the underlying counter
later decreases (e.g., wrong-book mastery reverting to incorrect).

### Claim Gates

Unlocked achievements are not auto-claimed. The player taps "领取" in the
Achievements screen, which invokes `claim_achievement(id)`. Same pattern
for tasks via `claim_task(group_name, task_id)`. Both gates check:

- Existence (`achievements.has(id)` / `tasks[group_name].has(task_id)`)
- Already claimed (`claimed == true` → return error)
- Threshold met (`unlocked == true` for achievements; `progress >= target`
  for tasks)

On success: apply reward via `_apply_reward()`, set `claimed = true`,
`save_to_disk()`, emit `state_changed`. Double-claim is structurally
impossible.

### Architecture Diagram

```
PracticeScreen (EVALUATING)
        │
        │ submit answer
        ▼
   ┌──────────────────────────────────────────────────────┐
   │ if is_correct:                                       │
   │   AppState.add_correct_answers(1)                    │
   │   AppState.mark_wrong_question_mastered(question_id) │  ← practice_screen.gd:113-114
   │ AppState.record_answer(question_id, is_correct, ans) │
   └──────────────────────────────────────────────────────┘
        │
        ▼
AppState.record_answer()
    ├── append to answer_history (cap 200)
    ├── if !is_correct: _record_wrong_question()
    │       └── upsert save_data["wrong_book"][question_id]
    └── _evaluate_achievements()
            └── recompute every achievement's progress
                    from profile counters
                    (idempotent — same input → same output)

Player taps "领取" in AchievementsScreen
        │
        │ claim_achievement(id)
        ▼
AppState.claim_achievement()
    ├── guard: unlocked && !claimed
    ├── _apply_reward() → exp + gold + level-up check
    └── claimed = true; save_to_disk(); state_changed.emit()
```

### Key Interfaces

**AppState (already shipping; this ADR documents the contract)**:
- `record_answer(question_id: String, is_correct: bool, user_answer: String) -> void`
- `add_correct_answers(count: int) -> void` — bumps `total_correct_answers` and a daily task
- `mark_wrong_question_mastered(question_id: String) -> void` — soft-marks an entry
- `mark_sign_in() -> Dictionary` — `{ok, message}`
- `complete_session(mode, level_id, correct_count, total_count, result) -> void`
- `claim_achievement(id: String) -> Dictionary` — `{ok, message}`
- `claim_task(group_name: String, task_id: String) -> Dictionary` — `{ok, message}`
- `get_wrong_book_entries() -> Array` — sorted by `last_wrong_time` desc
- `get_wrong_question_ids_for_retry(limit: int = 10) -> Array` — filters `mastered == false`
- `_record_wrong_question(question_id: String, user_answer: String) -> void` — private
- `_evaluate_achievements() -> void` — private; idempotent recompute
- `_apply_reward(reward: Dictionary) -> void` — private; shared by claim and session paths

## Alternatives Considered

### Alternative 1: Split Per-Answer / Per-Session Evaluators
- **Description**: Two private methods (`_evaluate_achievements_per_answer`,
  `_evaluate_achievements_per_session`) each handling a subset of
  achievement types, called only from the relevant trigger site.
- **Pros**: Each method does less work; each trigger site only runs the
  evaluations relevant to it.
- **Cons**: Adding a new achievement type requires deciding which
  evaluator owns it and updating the right call sites; drift risk if a
  new trigger site forgets to call both; the per-call cost saved (3
  achievements × O(1) lookups) is negligible; the pattern this would
  replace is already shipping and works.
- **Rejection Reason**: A single idempotent recompute is simpler, cheaper
  to maintain, and impossible to drift. The micro-optimization of running
  fewer evaluations per call is unmeasurable for the current achievement
  count and would make the pipeline more fragile.

### Alternative 2: Hard-Delete on Mastery
- **Description**: When a question is answered correctly,
  `_remove_from_wrong_book()` deletes the entry entirely instead of
  marking it `mastered = true`.
- **Pros**: Smaller `save_data["wrong_book"]` over time; the wrong-book
  screen would only show currently-struggling questions.
- **Cons**: Loses historical context — students can't see which questions
  they've recovered from; if a question re-becomes incorrect later, its
  prior `wrong_count` and timestamps are lost; the GDD's wrong-book
  screen mockup explicitly shows "已掌握 / 待重练" status, which requires
  the soft flag.
- **Rejection Reason**: Out of scope for current GDD. Soft-delete preserves
  the pedagogical signal of struggle-then-mastery and keeps the wrong-book
  screen UI honest.

### Alternative 3: Signal-Driven Evaluation
- **Description**: AppState emits an `answer_recorded` / `session_completed`
  signal. A separate `AchievementEvaluator` autoload connects and runs
  evaluation independently.
- **Pros**: Decoupled — adding analytics or a second evaluator requires
  no AppState changes.
- **Cons**: Achievement evaluation is a single-consumer pipeline; the
  decoupling benefit is unrealized. Signal connection lifecycle, deferred
  ordering, and a new autoload all add complexity for no payoff.
- **Rejection Reason**: ADR-0003 limits autoloads to data-owning services.
  Achievement evaluation is data manipulation on AppState's own state — it
  belongs inside AppState, not in a separate listener.

## Consequences

### Positive
- `_evaluate_achievements()` can be unit-tested by constructing a fake
  `save_data`, stubbing `ContentService.get_achievement_definitions()`,
  calling the method, and asserting on the resulting `achievements` dict
- The wrong-book lifecycle is fully described in one place
- The idempotent recompute pattern is impossible to drift
- Double-claim prevention is enforced at the AppState layer
- Adding a new data-driven achievement (same `type`) requires zero code
  changes — only a `growth_rules.json` edit

### Negative
- `_evaluate_achievements()` runs over every achievement definition on
  every relevant mutation. For 3 achievements (current scope) this is
  trivial; if the achievement count grows past ~50, indexing by `type`
  could be added.
- The mastered trigger lives in PracticeScreen, not AppState. A new
  caller of `record_answer()` (e.g., a future automated test harness)
  must remember to invoke `mark_wrong_question_mastered()` separately
  on correct answers.

### Risks
- **Forgetting to call `_evaluate_achievements()` from a new mutation
  site**: If a future feature adds a new way to update a watched profile
  counter without going through `record_answer`, `mark_sign_in`, or
  `complete_session`, achievement progress will lag. Mitigation: any new
  profile-counter mutator must call `_evaluate_achievements()` at the
  end. Document this rule in `coding-standards.md` if it isn't already.
- **`unlocked` is sticky**: Once set to `true`, it is never reset to
  `false`. If a future feature decreases a counter (rollback, refund,
  data correction), an achievement remains unlocked. This is intentional
  — students should not lose recognition for a met threshold — but it
  means counters cannot be safely "rolled back" without manual
  achievement state cleanup.
- **`growth_rules.json` typo in achievement type**: An unknown `type`
  value falls through the `match` and leaves `progress_value = 0`. The
  achievement is never unlocked. Mitigation: a future content-validation
  tool should warn on unknown achievement types.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| practice-system.md | Achievement evaluation post-answer + post-session (TR-practice-009) | `_evaluate_achievements()` is called from `record_answer()`, `mark_sign_in()`, and `complete_session()` — every relevant mutation site |
| growth-system.md | Achievement progress tracking (TR-growth-004) | Idempotent recompute over `growth_rules.json` definitions; progress derived from authoritative profile counters |
| practice-system.md | Wrong-retry source data (TR-practice-005) | `get_wrong_question_ids_for_retry()` returns un-mastered IDs from `wrong_book`; `_record_wrong_question()` and `mark_wrong_question_mastered()` maintain that state |

## Performance Implications
- **CPU**: Negligible — `_evaluate_achievements()` is O(N) over the
  achievement count (3 today); wrong-book operations are Dictionary key
  lookups
- **Memory**: Wrong-book bounded by total question count (~158 questions
  × small dict); no practical concern
- **Load Time**: None — evaluation runs at runtime, not startup
- **Network**: None

## Migration Plan
No code changes required — this ADR documents shipping behavior in
`AppState.gd` (autoload) and `practice_screen.gd:113-114`. Future stories
that touch this pipeline should:
1. Read this ADR before adding a new mutation site for any watched profile
   counter — call `_evaluate_achievements()` at the end of the mutator
2. Add new achievement `type` values to the `match` block in
   `_evaluate_achievements()` and document the source counter
3. Never hard-delete wrong-book entries — use the `mastered` flag

## Validation Criteria
- [ ] `_record_wrong_question()` upserts `save_data["wrong_book"][question_id]` with the documented schema
- [ ] Repeated wrong answers to the same question increment `wrong_count` and update `last_wrong_time` without creating duplicate entries
- [ ] `mark_wrong_question_mastered()` sets `mastered = true` on the existing entry; is a no-op if the entry doesn't exist
- [ ] A subsequent wrong answer on a mastered question resets `mastered` to `false` (via `_record_wrong_question()`)
- [ ] `get_wrong_question_ids_for_retry(10)` returns up to 10 IDs filtered by `mastered == false`
- [ ] `_evaluate_achievements()` reads progress from the corresponding profile counter for each `type` value
- [ ] An achievement with `progress >= target` has `unlocked == true` after the next mutator-triggered evaluation
- [ ] `unlocked == true` persists across saves and is not reset by subsequent evaluations
- [ ] `claim_achievement()` returns `{ok: false}` when `claimed == true` (double-claim prevention)
- [ ] `claim_task()` returns `{ok: false}` when `claimed == true` (double-claim prevention)
- [ ] `_evaluate_achievements()` is invoked from `record_answer()`, `mark_sign_in()`, and `complete_session()`

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — wrong-book and achievement state live in `save_data`; `save_to_disk()` runs after every mutation
- ADR-0003 (Autoload Singleton Pattern) — AppState owns this pipeline; ContentService provides definitions
- ADR-0004 (JSON Content Pipeline) — achievement definitions are in `growth_rules.json`
- ADR-0006 (Practice Session State Machine) — PracticeScreen calls `record_answer()` during EVALUATING and `mark_wrong_question_mastered()` from the same submit handler

