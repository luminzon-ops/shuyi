# 数一游园 (Shuyi Playland) — Master Architecture

## Document Status

| Field | Value |
|-------|-------|
| **Version** | 1.0 |
| **Last Updated** | 2026-05-20 |
| **Engine** | Godot 4.6.1 / gl_compatibility / Android portrait 720×1280 |
| **Authored by** | /create-architecture skill |
| **Technical Director Sign-Off** | 2026-05-20 — APPROVED |
| **Lead Programmer Feasibility** | 2026-05-20 — FEASIBLE (CONCERNS ACCEPTED) |

### GDDs Covered (9)

game-concept.md · content-system.md · practice-system.md · question-types.md ·
growth-system.md · persistence-system.md · ui-navigation.md · audio-system.md ·
systems-index.md

### ADRs Referenced (11 — all Accepted)

ADR-0001 Offline-First · ADR-0002 GDScript-Only · ADR-0003 Autoload Pattern ·
ADR-0004 JSON Content Pipeline · ADR-0005 ScreenHolder Navigation ·
ADR-0006 Practice Session State Machine · ADR-0007 Wrong-Book/Achievement Pipeline ·
ADR-0008 QuestionRenderer Architecture · ADR-0009 Growth Progression Engine ·
ADR-0010 Performance Budget · ADR-0011 Audio Integration Architecture

---

## Engine Knowledge Gap Summary

| Domain | Risk | Status |
|--------|------|--------|
| FileAccess, JSON, ZIPPacker, DirAccess | LOW | Within training data — reliable |
| GDScript language features | LOW | Stable across 4.x |
| AudioStreamPlayer, ResourceLoader | LOW | Stable across 4.x |
| gl_compatibility renderer | LOW | Stable across 4.x |
| Autoload pattern | LOW | Stable since Godot 3.x |
| UI/Control nodes (Button, LineEdit, Theme) | MEDIUM | Theme system refined in 4.4+ — see ADR-0008 Verification Required |
| SceneTree processing order | MEDIUM | Potential changes in 4.5 — see ADR-0006 Verification Required |
| Signal connection order | MEDIUM | Deferred connection behaviour in 4.6 — see ADR-0006 Verification Required |

**No HIGH RISK domains exist for this project.** All MEDIUM risk items are documented
in their governing ADRs with explicit Verification Required fields that become
implementation-story test obligations.

---

## Architecture Principles

1. **Offline-first, always.** No network dependency at runtime. All data is local.
   Content is bundled; player state is JSON on device. (ADR-0001, ADR-0004)

2. **GDScript only.** No C#, no GDExtension. The entire codebase is one language,
   one build pipeline, one mental model. (ADR-0002)

3. **AppState owns all mutable state.** No screen or utility class mutates player
   data directly. All mutations go through AppState methods, which call save_to_disk()
   after every change. (ADR-0001, ADR-0003)

4. **ContentService is read-only.** It loads once at startup and never writes.
   It is the single source of truth for game rules, content, and evaluation logic.
   (ADR-0004)

5. **Signals, not direct references.** Screens do not reference each other.
   All inter-screen communication flows through app.gd as the single routing hub.
   (ADR-0005)

---

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                             │
│                                                                 │
│  ScreenHolder / app.gd    QuestionRenderer    AudioSystem       │
│  (9 screens, navigation,  (10 question types, (4 AudioStream-   │
│   signal routing)          render + collect)   Players in       │
│                                                app.gd)          │
├─────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                  │
│                                                                 │
│  Practice System          Growth System       Wrong-Book &      │
│  (6 session modes,        (EXP, gold,         Achievement       │
│   state machine,          sign-in, tasks,     Pipeline          │
│   session lifecycle)      achievements)       (in AppState)     │
├─────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                     │
│                                                                 │
│  Content System           Question Types                        │
│  (JSON pipeline,          (10 types, evaluation                 │
│   query methods,           logic, normalization)                │
│   rules delivery)                                               │
├─────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                               │
│                                                                 │
│  Persistence System       Autoload Singletons  Performance      │
│  (save/load, shadow       (ContentService,     Budget           │
│   backup, ZIP export)      AppState,           (cross-cutting   │
│                            BackupService)       constraint)     │
├─────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                 │
│  Godot 4.6.1 · gl_compatibility · Android portrait 720×1280    │
│  Touch input · FileAccess · JSON · ZIPPacker · AudioStreamPlayer│
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs | Risk |
|--------|------|---------|----------|-------------|------|
| **ContentService** (autoload) | 10 JSON content files (read-only in-memory Dictionary) | `get_grades()`, `get_questions_for_level()`, `get_random_questions()`, `evaluate_answer()`, `calculate_result()`, `get_task_rules()`, `get_growth_rules()`, `get_achievement_definitions()` | FileAccess, JSON | `FileAccess`, `JSON.parse_string()` | LOW |
| **AppState** (autoload) | `save_data: Dictionary` — all mutable player state (profile, settings, progress, tasks, wrong_book, answer_history, achievements, meta) | `get_profile()`, `get_settings()`, `record_answer()`, `complete_session()`, `mark_sign_in()`, `claim_task()`, `claim_achievement()`, `state_changed` signal | ContentService (rules on load), FileAccess, DirAccess | `FileAccess`, `DirAccess`, `JSON.stringify()` | LOW |
| **BackupService** (autoload) | ZIP export/import logic (stateless) | `export_backup()`, `import_backup()` | AppState (save_data), FileAccess, ZIPPacker | `ZIPPacker`, `ZIPReader`, `FileAccess` | LOW |
| **Persistence System** (within AppState) | Atomic write pattern, shadow backup, schema evolution | `save_to_disk()`, `load_or_create()`, `_merge_defaults()` | FileAccess, DirAccess | `FileAccess.open()`, `DirAccess.rename()` | LOW |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs | Risk |
|--------|------|---------|----------|-------------|------|
| **Content System** (within ContentService) | 4-level hierarchy (Grade→Module→KP→Level→Questions), 10 JSON files | All ContentService query methods | FileAccess, JSON | `FileAccess`, `JSON.parse_string()` | LOW |
| **Question Types** (within ContentService) | Evaluation logic for 10 types, normalization rules | `evaluate_answer()`, `calculate_result()` | None (pure functions) | None | LOW |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs | Risk |
|--------|------|---------|----------|-------------|------|
| **Practice System** (PracticeScreen) | Session state machine (`_state: SessionState`), session lifecycle | `start_session(config)`, `session_finished` signal, `session_error` signal, `state` getter | ContentService (questions), AppState (record_answer, complete_session), QuestionRenderer | `Control`, `Button`, `LineEdit` | MEDIUM |
| **Growth System** (within AppState) | EXP, gold, streak_days, weekly_progress, tasks, achievements | `_apply_reward()`, `_check_level_up()`, `_update_streak_and_weekly()`, `_evaluate_achievements()` | ContentService (growth_rules, task_rules) | `Time.get_date_string_from_system()`, `Time.get_unix_time_from_datetime_string()` | LOW |
| **Wrong-Book & Achievement Pipeline** (within AppState) | wrong_book Dictionary, achievement progress | `_record_wrong_question()`, `mark_wrong_question_mastered()`, `_evaluate_achievements()`, `get_wrong_book_entries()`, `get_wrong_question_ids_for_retry()` | ContentService (achievement definitions) | None (pure Dictionary operations) | LOW |

### Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs | Risk |
|--------|------|---------|----------|-------------|------|
| **ScreenHolder / app.gd** | Navigation state, signal routing, title bar | `_show_screen()`, `_start_session()` | All 9 screens (signals), AppState, ContentService | `Control.visible`, `Label.text` | MEDIUM |
| **QuestionRenderer** | Rendering mode logic (stateless class, not a Node) | `render()`, `build_user_answer()` | PracticeScreen (containers passed in) | `Button`, `LineEdit`, `Node.queue_free()`, `Node.add_child()` | MEDIUM |
| **Audio System** (within app.gd) | 4 AudioStreamPlayer nodes | `_init_audio_player()`, `_play_sound()` | AppState (sound_enabled setting), ResourceLoader | `AudioStreamPlayer`, `ResourceLoader.exists()` | LOW |

### ASCII Dependency Diagram

```
Platform (Godot 4.6.1 / Android)
    │
    ├── ContentService ──────────────────────────────────────────┐
    │       │ (rules on load)                                    │
    ├── AppState ◄──────────────────────────────────────────────┤
    │       │                                                    │
    ├── BackupService ◄── AppState                              │
    │                                                            │
    ├── PracticeScreen ◄── ContentService, AppState ────────────┤
    │       │                                                    │
    ├── QuestionRenderer ◄── PracticeScreen (containers) ───────┤
    │                                                            │
    ├── GrowthSystem (in AppState) ◄── ContentService ──────────┤
    │                                                            │
    ├── WrongBook/Achievement (in AppState) ◄── ContentService ─┤
    │                                                            │
    ├── app.gd ◄── AppState, ContentService, all screens ───────┤
    │                                                            │
    └── AudioSystem (in app.gd) ◄── AppState ───────────────────┘
```

---

## Data Flow

### Scenario 1: Core Practice Loop (primary path)

```
User taps "Start Practice"
    │ start_session_requested(config) signal
    ▼
app.gd._start_session(config)
    │ synchronous call
    ▼
PracticeScreen.start_session(config)
    │ IDLE → LOADING
    ▼
ContentService.get_questions_for_level(level_id)  [sync, returns Array]
    │ LOADING → ACTIVE
    ▼
QuestionRenderer.render(question, containers, callback)
    │ creates Button/LineEdit nodes
    ▼
User answers (tap option or type text)
    │ ACTIVE → EVALUATING
    ▼
QuestionRenderer.build_user_answer()  →  String
    │
ContentService.evaluate_answer(question, answer)  →  bool  [pure function]
    │
AppState.record_answer(id, is_correct, answer)
    │ writes to save_data, triggers _evaluate_achievements()
    │ if wrong: _record_wrong_question()
    │ EVALUATING → ACTIVE (more questions remain)
    │ EVALUATING → FINISHED (last question)
    ▼
ContentService.calculate_result(mode, level_id, correct, total)  →  Dict
    │
AppState.complete_session(mode, level_id, correct, total, result)
    │ updates tasks, achievements, levels_completed_count
    │ _apply_reward() → _check_level_up()
    │ save_to_disk() (atomic write + shadow backup)
    │ state_changed.emit()
    ▼
PracticeScreen.session_finished(summary) signal
    │
app.gd._on_session_finished(summary)
    │
ResultScreen.refresh_view(summary)
```

### Scenario 2: Save/Load Path

```
Any state mutation (record_answer / complete_session / mark_sign_in / claim_task)
    │
AppState.save_to_disk()
    ├── 1. Copy savegame.json → savegame.bak  (shadow backup)
    ├── 2. JSON.stringify(save_data) → savegame.tmp  (atomic write)
    └── 3. DirAccess.rename(savegame.tmp → savegame.json)

App startup
    │
AppState.load_or_create()
    ├── Try: read savegame.json → JSON.parse_string()
    ├── Fail → Try: read savegame.bak
    └── Fail → _get_default_save_data() + _merge_defaults()
```

### Scenario 3: Autoload Initialization Order (mandatory)

```
project.godot autoload order:
1. ContentService._ready()  → loads 10 JSON files into content: Dictionary
2. AppState._ready()        → load_or_create() + _reset_task_targets_from_rules()
                              (requires ContentService already ready)
3. BackupService._ready()   → stateless helper, no dependencies
4. DatabaseService          → deprecated, do not depend on
```

### Scenario 4: Signal/Event Path (inter-screen communication)

All inter-screen communication is synchronous signal routing through app.gd.
No screen holds a direct reference to another screen.

```
Screen emits signal
    │ (e.g. open_sign_in_requested, session_finished, back_requested)
    ▼
app.gd handler
    │ (e.g. _show_screen(sign_in_screen, ...), _on_session_finished(summary))
    ▼
Target screen becomes visible + refresh_view() called if available
```

### Scenario 5: Growth Reward Path

```
Any EXP source (session / task claim / achievement claim / sign-in)
    │
AppState._apply_reward(reward: Dictionary)
    ├── save_data.profile.exp   += reward.get("exp", 0)
    ├── save_data.profile.gold  += reward.get("gold", 0)
    ├── weekly_progress = min(weekly_progress + reward.exp, 100)
    └── _check_level_up()
            └── while exp >= level * curve_base:
                    exp   -= level * curve_base
                    level += 1

Student taps Sign-In
    │
AppState.mark_sign_in()
    ├── guard: last_sign_in == today → return error
    ├── _update_streak_and_weekly(today)
    │       ├── days_between(last, today) == 1 → streak_days += 1
    │       ├── days_between(last, today) > 1  → streak_days = 1
    │       └── ISO week changed → weekly_progress = 0
    ├── _apply_reward(sign_in_reward)
    └── save_to_disk()
```

---

## API Boundaries

### ContentService (read-only, no side effects)

```gdscript
func get_grades() -> Array[Dictionary]
func get_modules_for_grade(grade_id: String) -> Array[Dictionary]
func get_knowledge_points(module_id: String) -> Array[Dictionary]
func get_levels(knowledge_point_id: String) -> Array[Dictionary]
func get_questions_for_level(level_id: String) -> Array[Dictionary]
func get_random_questions(limit: int) -> Array[Dictionary]
func get_mock_test_questions(grade_id: String, limit: int) -> Array[Dictionary]
func get_questions_by_filters(filters: Dictionary, limit: int) -> Array[Dictionary]
func evaluate_answer(question: Dictionary, user_answer: String) -> bool
func calculate_result(mode: String, level_id: String, correct: int, total: int) -> Dictionary
func get_task_rules() -> Dictionary
func get_growth_rules() -> Dictionary
func get_achievement_definitions() -> Array[Dictionary]
```

**Invariants**: All methods return empty Array/Dictionary (never null) on missing data.
ContentService never writes. Call only after autoload initialization completes.

### AppState (mutable state, saves after every mutation)

```gdscript
signal state_changed

func get_profile() -> Dictionary
func get_settings() -> Dictionary
func get_task_summary() -> Dictionary
func get_recent_level_id() -> String

func record_answer(question_id: String, is_correct: bool, user_answer: String) -> void
func complete_session(mode: String, level_id: String, correct: int,
                      total: int, result: Dictionary) -> void
func mark_sign_in() -> Dictionary          # {ok: bool, message: String}
func claim_task(group_name: String, task_id: String) -> Dictionary
func claim_achievement(id: String) -> Dictionary

func get_wrong_book_entries() -> Array[Dictionary]
func get_wrong_question_ids_for_retry(limit: int) -> Array[String]
func mark_wrong_question_mastered(question_id: String) -> void

func save_to_disk() -> void
func load_or_create() -> void
```

**Invariants**:
- `save_data.profile.exp` must only be mutated via `_apply_reward()` — never directly
- Every public mutation method calls `save_to_disk()` before returning
- `state_changed` is emitted after every mutation

### PracticeScreen

```gdscript
signal session_finished(summary: Dictionary)
signal session_error(reason: String)

func start_session(config: Dictionary) -> void
var state: SessionState  # read-only getter; backing var is private _state
```

**Invariants**:
- `start_session()` is a no-op if `state != IDLE`
- `session_finished` is emitted exactly once per session, after state resets to IDLE

### QuestionRenderer (stateless utility class)

```gdscript
func render(question: Dictionary, option_container: Control,
            answer_input: LineEdit, select_callback: Callable) -> void
func build_user_answer(question_type: String, selected_option: String,
                       answer_input: LineEdit) -> String
```

**Invariants**:
- `option_container` and `answer_input` must be persistent scene nodes (not temporary)
- `render()` owns full cleanup of `option_container` children — callers must not manage this

### app.gd (navigation controller)

```gdscript
# Internal — triggered by screen signals or bottom nav buttons
func _show_screen(screen: Control, title: String, subtitle: String) -> void
func _start_session(config: Dictionary) -> void
func _play_sound(player: AudioStreamPlayer) -> void
```

**Invariants**:
- Only one screen is visible at any time
- All screen signals are connected in `_ready()` before any user interaction

---

## ADR Audit

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| 0001 Offline-First | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0002 GDScript-Only | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0003 Autoload Pattern | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0004 JSON Content Pipeline | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0005 ScreenHolder Navigation | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0006 Practice Session SM | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0007 Wrong-Book/Achievement | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0008 QuestionRenderer | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0009 Growth Progression | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0010 Performance Budget | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |
| 0011 Audio Integration | ✅ | ✅ 4.6.1 | ✅ | None | ✅ |

**No deprecated API references found across all 11 ADRs.**
**No circular ADR dependencies detected.**

---

## Required ADRs

None. All 50 technical requirements have architectural coverage as of 2026-05-20.
See `docs/architecture/traceability-index.md` for the full matrix.

---

## Open Questions

These are documentation refinements — not architectural gaps. Each can be resolved
by adding a paragraph to the governing ADR rather than writing a new ADR.

| ID | Summary | Priority | Resolution Path |
|----|---------|----------|-----------------|
| QQ-01 | TR-practice-006: Answer history 200-cap invariant not explicitly encoded in any ADR | Low | Add one paragraph to ADR-0001 or ADR-0006 |
| QQ-02 | TR-growth-003: Task lifecycle (rules/progress/claim/weekly reset) split across ADR-0004/0007/0009 — no single ADR fully owns it | Low | Add a "Task Lifecycle" section to ADR-0007 |
| QQ-03 | TR-ui-010: Default level fallback (`level_grade1_addition_1`) is code-level convention, not in any ADR | Low | Annex into ADR-0005 or accept as code convention |
| QQ-04 | TR-persist-006: Import validation required-section list and checksum algorithm described in GDD only, not in ADR-0001 | Low | Add explicit section list to ADR-0001 |

## LP-Flagged Pre-Production Actions

These are not architectural blockers but should become stories before the first production build:

| # | Action | Source |
|---|--------|--------|
| LP-01 | Add JSON schema validation to build pipeline — malformed content JSON causes startup crash | ADR-0004 Risks |
| LP-02 | Execute ADR-0009 migration plan: refactor `mark_sign_in()` to route EXP through `_apply_reward()` instead of direct `profile["exp"]` mutation | ADR-0009 As-Built Gap |
