# Control Manifest

> **Engine**: Godot 4.6.1 / GDScript-only / Android portrait 720×1280
> **Last Updated**: 2026-05-21
> **Manifest Version**: 2026-05-21
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009, ADR-0010, ADR-0011
> **Status**: Active — regenerate with `/create-control-manifest` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns

- **Atomic write for save**: `save_to_disk()` MUST write to `user://savegame.tmp`, then rename to `user://savegame.json` via `DirAccess.rename()`. Never write directly to `savegame.json` — `FileAccess.open(WRITE)` truncates before writing, creating a corruption window. — source: ADR-0001
- **Shadow backup**: Before every atomic write, copy existing `savegame.json` to `savegame.bak`. — source: ADR-0001
- **Load fallback chain**: `load_or_create()` MUST try: primary JSON → shadow backup → fresh defaults. — source: ADR-0001
- **Save after every mutation**: `save_to_disk()` MUST be called after every state mutation in AppState (`record_answer`, `mark_sign_in`, `complete_session`, `claim_achievement`, `claim_task`). — source: ADR-0001
- **Emit state_changed after every mutation**: `state_changed` signal MUST be emitted after every AppState mutation so UI screens can refresh. — source: ADR-0001, ADR-0003
- **Autoload initialization order**: `project.godot` MUST list autoloads as: `ContentService → AppState → BackupService`. AppState's `_ready()` calls ContentService at startup; wrong order causes task targets to default to zero. — source: ADR-0001, ADR-0003
- **Runtime assert on autoload order**: `AppState._ready()` MUST assert `ContentService.content` is non-empty to detect order regression. — source: ADR-0003
- **Schema evolution via deep merge**: `_merge_defaults()` MUST deep-merge loaded data with defaults on every load. New fields appear automatically; no explicit schema versioning needed. — source: ADR-0001
- **Backup ZIP contents**: Export ZIP MUST include: `save_data.json` + `version.txt` + `checksum.txt`. Checksum is a 32-bit integer hash from `String.hash()` applied to the serialized JSON — explicitly NOT a cryptographic digest; sufficient for corruption detection only. — source: ADR-0001
- **ScreenHolder pre-instantiation**: All 9 screens MUST be pre-instantiated as children of ScreenHolder at app startup (`app.gd._ready()`). — source: ADR-0005
- **Navigation via `_show_screen()`**: All screen switches MUST use `_show_screen(screen, title, subtitle)`: hide all ScreenHolder children, show target, update TitleLabel/SubtitleLabel, call `refresh_view()` if available. — source: ADR-0005
- **Signal routing through app.gd**: All inter-screen communication MUST route through `app.gd` signals. No screen may directly reference or call methods on another screen. — source: ADR-0005

### Forbidden Approaches

- **Never** write directly to `savegame.json` via `FileAccess.open(WRITE)` — truncates file before write, creating a corruption window. — source: ADR-0001
- **Never** use `DatabaseService` for any data recovery or persistence — non-functional on Android (sqlite3 binary not accessible to apps). — source: ADR-0001, ADR-0003
- **Never** call `OS.execute("sqlite3", ...)` — non-functional on Android. — source: ADR-0001
- **Never** use `get_tree().change_scene()` for screen navigation — destroys screen state, causes frame hitches. — source: ADR-0005
- **Never** use `TabContainer` for screen management — doesn't match custom bottom nav design. — source: ADR-0005
- **Never** let a screen directly reference or call methods on another screen — all routing through app.gd. — source: ADR-0005
- **Never** add a new autoload without superseding ADR-0003. Current active count is 3 (ContentService, AppState, BackupService); DatabaseService is deprecated and slated for removal. New autoloads require an ADR documenting why an existing service cannot absorb the responsibility. — source: ADR-0003 (limit established by precedent in ADR-0009 §Alt-1, ADR-0011 §Alt-1)
- **Never** reorder autoloads in `project.godot` without updating ADR-0001 — initialization order is mandatory. — source: ADR-0001

### Performance Guardrails

- **Save I/O**: `save_to_disk()` must complete within 1ms. If exceeded, defer with `save_to_disk.call_deferred()` (callable syntax — NOT the Godot 3 string form `call_deferred("save_to_disk")`). Note: `call_deferred` only delays to end-of-frame; if Android flash storage is slow, use a worker thread with mutex. — source: ADR-0010
- **Screen memory**: 9 pre-instantiated screens must stay within 50MB UI budget. If exceeded, lazy-instantiate low-priority screens (Settings, Achievements) rather than blocking. — source: ADR-0005, ADR-0010
- **Screen switching**: Must be sub-frame — ScreenHolder visibility toggle is O(1). — source: ADR-0005

---

## Core Layer Rules

*Applies to: core gameplay loop, session state machine, content pipeline, growth progression*

### Required Patterns

- **SessionState enum in PracticeScreen**: PracticeScreen MUST implement `enum SessionState { IDLE, LOADING, ACTIVE, EVALUATING, FINISHED }` with a private `_state: SessionState` variable. — source: ADR-0006
- **All transitions through `_transition()`**: Every state change MUST go through `_transition(new_state: SessionState)`. No direct assignment to `_state`. — source: ADR-0006
- **start_session() re-entry guard**: `start_session()` MUST check `if _state != IDLE: return` before proceeding. — source: ADR-0006
- **_finish_session() double-execution guard**: `_finish_session()` MUST check `if _state != EVALUATING: return` before proceeding. — source: ADR-0006
- **State reset before signal emission**: State MUST reset to IDLE *before* `session_finished` is emitted — ensures app.gd's handler can call `start_session()` synchronously if needed. — source: ADR-0006
- **Wrong-retry edge case**: Wrong-retry with 0 un-mastered IDs MUST transition LOADING → IDLE and emit `session_error("no_wrong_questions")`. 1–9 IDs starts a shorter session — NOT padded to 10. — source: ADR-0006
- **Sign-in idempotency owned by AppState**: PracticeScreen calls `complete_session()` unconditionally. `AppState.mark_sign_in()` owns the date-equality guard. PracticeScreen has no sign-in awareness. — source: ADR-0006
- **ContentService query methods only**: All content access MUST use ContentService query methods (`get_questions_for_level()`, `get_random_questions()`, etc.). Never access `ContentService.content` dictionary directly from outside ContentService. — source: ADR-0004
- **Pure functions for evaluation**: `evaluate_answer()` and `calculate_result()` are pure functions — call them without side effects; they do not mutate state. — source: ADR-0004
- **All EXP through `_apply_reward()`**: Every EXP gain MUST go through `AppState._apply_reward(reward: Dictionary)`. Never mutate `save_data.profile.exp` directly. — source: ADR-0009
- **`_apply_reward()` defaults**: `_apply_reward()` MUST default missing reward keys to 0: `reward.get("exp", 0)`, `reward.get("gold", 0)`. — source: ADR-0009
- **Level-up while loop**: `_check_level_up()` MUST use a `while` loop (not `if`) to handle multiple level-ups with EXP carry-over. — source: ADR-0009
- **Streak empty-string guard**: `_update_streak_and_weekly()` MUST guard for empty `last_sign_in` — set `streak_days = 1` and skip gap calculation. — source: ADR-0009
- **Date-to-Unix with time component**: `_date_to_unix()` MUST append `"T00:00:00"` to date-only strings before calling `Time.get_unix_time_from_datetime_string()` — date-only strings return -1 on Android. — source: ADR-0009
- **Use `roundi()` for day-gap**: Day-gap calculation MUST use `roundi()` (not `int()`) on the float division result — `int()` truncates `0.9999...` to 0, triggering a false same-day guard. — source: ADR-0009
- **ISO week utility with tests**: `_get_iso_week()` MUST be a tested utility function. Year-boundary edge cases (Dec 28 / Jan 3) MUST be covered by unit tests. — source: ADR-0009

### Forbidden Approaches

- **Never** use a separate StateMachine node/resource for PracticeScreen — enum inside PracticeScreen is the correct pattern at this scale. — source: ADR-0006
- **Never** use signal-driven implicit states for the session lifecycle — the current pattern produced double-execution bugs. — source: ADR-0006
- **Never** access `ContentService.content` dictionary directly from outside ContentService — use query methods. — source: ADR-0004
- **Never** mutate `save_data.profile.exp` directly outside `_apply_reward()`. — source: ADR-0009
- **Never** use `int()` for day-gap calculation — use `roundi()`. — source: ADR-0009

### Performance Guardrails

- **Game logic budget**: AppState mutations + ContentService queries must stay within 2ms per frame. — source: ADR-0010
- **Question rendering budget**: QuestionRenderer `render()` must stay within 1ms per frame. — source: ADR-0010

---

## Feature Layer Rules

*Applies to: wrong book, achievement evaluation, audio*

### Required Patterns

- **Wrong-book soft-delete**: Wrong-book entries MUST use `mastered = true` flag — never hard-delete. A re-incorrect answer resets `mastered = false` via `_record_wrong_question()`. — source: ADR-0007
- **`_evaluate_achievements()` at every counter mutation**: MUST be called from every site that mutates a profile counter watched by an achievement: `record_answer()`, `mark_sign_in()`, `complete_session()`. Any new profile-counter mutator MUST call `_evaluate_achievements()` at the end. — source: ADR-0007
- **`mark_wrong_question_mastered()` call site**: Called from PracticeScreen submit handler (`practice_screen.gd:113-114`) on every correct answer, regardless of mode — NOT from `AppState.record_answer()`. A new caller of `record_answer()` must call `mark_wrong_question_mastered()` separately on correct answers. — source: ADR-0007
- **Achievement `unlocked` is sticky**: Once `unlocked == true`, it is never reset to `false` — even if the underlying counter later decreases. — source: ADR-0007
- **Audio player factory**: All `AudioStreamPlayer` nodes MUST be initialized via `_init_audio_player(path: String) -> AudioStreamPlayer`. Never instantiate `AudioStreamPlayer` directly. — source: ADR-0011
- **Audio playback gate**: All audio playback MUST go through `_play_sound(player: AudioStreamPlayer)`. Never call `player.play()` directly. — source: ADR-0011
- **Audio warm-up**: After `_init_audio_player()`, call `player.play()` then immediately `player.stop()` to pre-initialize the Android audio thread and mitigate first-play latency (50–200ms). — source: ADR-0011

### Forbidden Approaches

- **Never** hard-delete wrong-book entries — use `mastered = true` flag. — source: ADR-0007
- **Never** split achievement evaluation into per-answer/per-session evaluators — use single idempotent `_evaluate_achievements()`. — source: ADR-0007
- **Never** instantiate `AudioStreamPlayer` without `_init_audio_player()` guard. — source: ADR-0011

### Advisory Notes

- Unknown achievement `type` in `growth_rules.json` falls through the `match` block silently and never unlocks. Content validation tooling SHOULD warn on unknown types. — source: ADR-0007

---

## Presentation Layer Rules

*Applies to: rendering, audio output, UI, question rendering*

### Required Patterns

- **Hide before queue_free**: Call `option_container.hide()` BEFORE the `queue_free()` loop on option buttons. — source: ADR-0008
- **Show after add_child**: Call `option_container.show()` AFTER all `add_child()` calls complete. — source: ADR-0008
- **QuestionRenderer as standalone class**: `QuestionRenderer` MUST be a standalone GDScript class (not a Node, not an autoload). Instantiate with `QuestionRenderer.new()`. — source: ADR-0008
- **Single QuestionRenderer instance**: PracticeScreen MUST instantiate `QuestionRenderer` once: `var _renderer := QuestionRenderer.new()`. — source: ADR-0008
- **All AudioStreamPlayers owned by app.gd**: All `AudioStreamPlayer` nodes MUST be owned by `app.gd`. — source: ADR-0011
- **Explicit signals for audio triggers**: `app.gd` MUST connect to explicit signals (`answer_result(is_correct: bool)`, `level_up(new_level: int)`) for audio triggers — NOT to `AppState.state_changed` with diffing. — source: ADR-0011
- **gl_compatibility renderer**: Use `gl_compatibility` renderer for all Android builds. — source: ADR-0010, technical-preferences.md

### Forbidden Approaches

- **Never** call `free()` on option buttons mid-frame — use `queue_free()`. Calling `free()` mid-frame can crash on Android if the GL compatibility renderer is mid-draw or if the node has pending signals. — source: ADR-0008
- **Never** use scene-based per-type renderers (one `.tscn` per question type) — scene instantiation per question causes perceptible hitches on Android. — source: ADR-0008
- **Never** put `AudioStreamPlayer` nodes in individual screens — gate logic would be duplicated. — source: ADR-0011
- **Never** call `_play_sound()` from `app.gd._ready()` before the autoload chain completes — `AppState.get_settings()` returns `{}` before `AppState._ready()` finishes. — source: ADR-0011

### Advisory Notes

- For matching / drag_drop / sorting / shape_puzzle question types, option values MUST NOT contain the `>` character — used as text-buffer delimiter in Button+Input mode. Content validation should enforce this. — source: ADR-0008
- Button+Input append-callback (`value + ">"`) lives in PracticeScreen, NOT in QuestionRenderer. Adding a new Button+Input type requires updating both. — source: ADR-0008

### Performance Guardrails

- **UI rendering budget**: All visible Control nodes, labels, buttons, panels must stay within 4ms per frame. — source: ADR-0010
- **Draw call budget**: Active screen UI: 80 draw calls max. Background/decorative: 10. Headroom: 10. Total ceiling: 100. — source: ADR-0010

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables / functions | snake_case | `move_speed`, `get_profile()` |
| Signals | snake_case past tense | `health_changed`, `session_finished` |
| Files | snake_case matching class | `player_controller.gd` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

Source: ADR-0002, technical-preferences.md

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60fps |
| Frame budget | 16.6ms |
| Draw calls | 100 max |
| Memory ceiling | 256MB |

Source: ADR-0010, technical-preferences.md

### Approved Libraries / Addons

- GdUnit4 v6.1.3 — approved for unit and integration testing

### Forbidden APIs (Godot 4.6.1)

- `TileMap` node — deprecated in 4.4+; use `TileMapLayer` instead. Source: deprecated-apis.md
- `JSON.parse()` — deprecated; use `JSON.parse_string()` instead. Source: deprecated-apis.md, current-best-practices.md

### Cross-Cutting Constraints

- **GDScript only**: All code MUST be GDScript. No C#, no GDExtension, no C++. If a future feature genuinely requires a compiled language, supersede ADR-0002 explicitly. — source: ADR-0002
- **UI screens must not call `save_to_disk()` directly**: UI screens MUST emit signals to `app.gd`; `app.gd` calls AppState methods. Direct `AppState.save_to_disk()` calls from screens bypass the signal layer. — source: ADR-0003
- **Profiling tool**: Use Godot Debugger > Profiler tab for all performance validation. Profiling MUST be done on an Android device — `gl_compatibility` behaves differently on desktop. — source: ADR-0010
- **`Performance.MEMORY_STATIC` / `Performance.MEMORY_DYNAMIC`**: Use `Performance.get_monitor(Performance.MEMORY_STATIC)` — NOT `static_memory_usage_by_type` (not a valid monitor name in Godot 4). — source: ADR-0010
