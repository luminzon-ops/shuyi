# ADR-0003: Autoload Singleton Pattern

## Status
Accepted

## Date
2026-05-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (application structure, state management) |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | `ProjectSettings.globalize_path()` — stable; autoload node API stable since Godot 3.x |
| **Verification Required** | Verify autoload initialization order after any engine update; verify DatabaseService removal does not break `project.godot` parsing |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — established storage patterns autoloads use), ADR-0002 (GDScript-Only Stack — autoloads are GDScript classes) |
| **Enables** | All screen and gameplay code — everything depends on the autoload services |
| **Blocks** | Any story that adds a new system requiring global state or data access |
| **Ordering Note** | Initialization order is hardcoded in `project.godot` and validated by ADR-0001 |

## Context

### Problem Statement
Shuyi Playland is a single-scene app with 9 UI screens. Multiple screens need shared access to player state, content data, and backup/export services. Without a centralized state layer, each screen would need to load data independently, creating duplication and inconsistency.

### Constraints
- **Single-scene architecture**: `App.tscn` is the only top-level scene; all screens are child Controls toggled via visibility
- **GDScript-only**: No C# or GDExtension singletons (ADR-0002)
- **Offline-first**: No server or network layer to manage state (ADR-0001)
- **Small scope**: Four global services are sufficient; no need for a full IoC container or service locator pattern

### Requirements
- Must provide global access to player state, content data, and backup/export
- Must initialize in a deterministic order (ContentService before AppState)
- Must support signal-based communication (no direct coupling between screens)
- Must be testable and debuggable

## Decision

### Four Autoload Singletons

All global services are implemented as Godot autoloads (`project.godot` `[autoload]` section). Each is a GDScript `Node` that loads at startup and persists for the app lifetime.

| Autoload | Script | Phase | Responsibility | GDD Reference |
|----------|--------|-------|----------------|---------------|
| **ContentService** | ContentService.gd | Load phase | Loads all 10 JSON content files at `_ready()`; provides query methods for questions, levels, rules | content-system.md |
| **AppState** | AppState.gd | Post-load | Manages mutable player state (profile, progress, tasks, achievements, wrong book); loads from save file; handles save triggers | persistence-system.md, growth-system.md |
| **BackupService** | BackupService.gd | Runtime | ZIP export/import of save data; triggered from Settings screen or programmatically | persistence-system.md |
| **DatabaseService** | DatabaseService.gd | N/A | **DEPRECATED** — non-functional on Android (sqlite3 binary not accessible). Retained only until removal; do not use. | ADR-0001 |

### Initialization Order (MANDATORY)

```
[autoload] (project.godot)
ContentService="*res://autoload/ContentService.gd"
AppState="*res://autoload/AppState.gd"
BackupService="*res://autoload/BackupService.gd"
# DatabaseService removed
```

**Rule**: ContentService MUST be listed before AppState. AppState's `_ready()` calls `ContentService.get_task_rules()` and `ContentService.get_growth_rules()` to sync task targets on load. If the order is reversed, `content` dictionary is still `{}` and task targets default to zero.

### Architecture Diagram

```
┌────────────────────────────────────────┐
│           Scene Tree (App.tscn)        │
│  ┌──────────────────────────────────┐  │
│  │     ScreenHolder (Control)       │  │
│  │  ┌──────┐ ┌──────┐ ┌──────┐     │  │
│  │  │ Home │ │Prac- │ │Result│ ... │  │
│  │  │      │ │tice  │ │      │     │  │
│  │  └──────┘ └──────┘ └──────┘     │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Signals:                              │
│  start_session_requested ──→ app.gd    │
│  session_finished ─────────→ app.gd    │
│  back_requested ───────────→ app.gd    │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │         Autoloads (global)       │  │
│  │  ContentService                  │  │
│  │  AppState ←── state_changed      │  │
│  │  BackupService                   │  │
│  │  (DatabaseService — deprecated)  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Access: /root/ContentService          │
│  Access: /root/AppState                │
│  Access: /root/BackupService           │  │
└────────────────────────────────────────┘
```

### Key Interfaces

**ContentService** (read-only):
- `get_grades() → Array`
- `get_questions_for_level(level_id: String) → Array`
- `get_random_questions(limit: int) → Array`
- `evaluate_answer(question: Dictionary, user_answer: String) → bool`
- `calculate_result(...) → Dictionary`
- `get_task_rules() → Dictionary`
- `get_growth_rules() → Dictionary`
- Never writes; content loaded once at `_ready()` via `reload_content()`

**AppState** (mutable state):
- `save_data: Dictionary` — in-memory state (all screens read from this via getters)
- `save_to_disk()` — atomic write + shadow backup
- `load_or_create()` — JSON load → shadow fallback → defaults
- `state_changed` signal — emitted after every mutation; UI screens can connect to refresh
- `get_profile() → Dictionary`, `get_settings() → Dictionary`, `get_task_summary() → Dictionary`
- `record_answer(...)`, `mark_sign_in()`, `complete_session(...)`, `claim_task(...)`, `claim_achievement(...)`

**BackupService** (export/import):
- `export_backup() → Dictionary {ok: bool, path: String, message: String}`
- `import_backup() → Dictionary {ok: bool, message: String}`
- No persistent state — stateless helper

**DatabaseService** (deprecated):
- All methods are non-functional on Android
- Scheduled for removal; do not call from new code

### Signal-Based Communication Pattern

Screens do NOT directly call `AppState` methods from UI event handlers. Instead, screens emit signals that `app.gd` (the screen controller) catches and routes. This decouples UI from state mutation logic:

```
PracticeScreen.session_finished(summary) ──→ app.gd ──→ _on_session_finished() ──→ ResultScreen
HomeScreen.start_session_requested(config) ──→ app.gd ──→ _start_session(config) ──→ PracticeScreen
```

However, autoloads are accessed directly by `app.gd` for state reads/writes (not signal-based), since `app.gd` is the single controller and direct calls are simpler than signals in this case.

## Alternatives Considered

### Alternative 1: Service Locator Pattern (Manual Singletons)
- **Description**: Each service is instantiated once under a root node and passed via `get_node()` or dependency injection
- **Pros**: No autoload magic; explicit wiring visible in scene tree
- **Cons**: Requires boilerplate in every screen to locate services; breaks if scene tree structure changes; harder to unit-test
- **Rejection Reason**: Autoloads are Godot's idiomatic singleton mechanism. They provide clean global access (`/root/AppState`) with zero boilerplate in scenes. For a small-scope app, the explicit wiring adds no value.

### Alternative 2: Resource-Based State (`.tres` files)
- **Description**: Player state is stored in Godot Resource (`.tres`) files instead of JSON Dictionaries
- **Pros**: Godot-native; type-safe properties; editor inspectable
- **Cons**: Requires defining custom Resource classes for every state section; harder to deep-merge on load; Godot 4 resource format changes could break saves between versions; not human-editable outside Godot editor
- **Rejection Reason**: JSON is simpler, human-readable, and the `_merge_defaults()` pattern works naturally with Dictionaries. Resource-based state adds type safety that doesn't justify the complexity for a small data set.

### Alternative 3: Component-Based State (Nodes in Scene Tree)
- **Description**: State lives in regular nodes attached to the App scene, not autoloads
- **Pros**: Visible in editor; can use Godot's built-in serialization
- **Cons**: Fragile — scene tree changes can destroy state; harder to ensure singleton behavior; autoloads are strictly cleaner for global state
- **Rejection Reason**: Autoloads are explicitly designed for this use case. Moving state into the scene tree creates coupling between UI structure and data lifecycle.

## Consequences

### Positive
- Godot's autoload system provides singleton behavior with zero code overhead
- Deterministic initialization order guarantees ContentService is ready before AppState reads it
- `state_changed` signal allows all UI screens to react to data changes without polling
- All global services are discoverable in `project.godot` — single place to check
- Screens are decoupled from state management — they emit signals, app.gd routes, autoloads mutate

### Negative
- Autoloads create implicit global dependencies — any script can access `AppState` directly, bypassing the signal layer. This is a risk for codebase discipline.
- Godot's autoload order is source-order in `project.godot` — easy to accidentally break by reordering entries
- `DatabaseService` still exists in autoloads (deprecated) until removal; dead code adds confusion

### Risks
- **Accidental direct autoload access from UI screens**: UI screens should emit signals to `app.gd`, not call `AppState.save_to_disk()` directly. Mitigation: code review enforces signal layer; forbidden pattern registered in architecture.yaml.
- **Autoload order regression**: Reordering in `project.godot` breaks initialization. Mitigation: ADR-0001 documents mandatory order; add runtime assert in `AppState._ready()` confirming `ContentService.content` is non-empty.
- **Autoload bloat**: Adding too many autoloads increases startup time and global namespace pollution. Mitigation: current count (4, soon 3 after DatabaseService removal) is well within Godot's recommended limit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| persistence-system.md | Centralized save/load state | AppState autoload owns all mutable state |
| persistence-system.md | Deterministic initialization | ContentService → AppState order guarantees content is loaded before save data needs it |
| content-system.md | Read-only content at runtime | ContentService loads JSON once at _ready(), never writes |
| practice-system.md | Question evaluation and fetch | ContentService provides `evaluate_answer()` and question queries |
| growth-system.md | Task target sync on load | AppState._ready() calls ContentService.get_task_rules() after autoload order ensures it's ready |
| ui-navigation.md | Signal-based screen communication | app.gd routes all screen signals; autoloads provide data access |

## Performance Implications
- **Startup**: Four autoload nodes with ~4-5 `_ready()` calls; ContentService loads ~1MB JSON in ~50ms on Android
- **Runtime**: Autoloads are lightweight Nodes; no per-frame overhead
- **Memory**: Autoload Nodes have negligible footprint compared to save_data Dictionary (~50KB)
- **Network**: None — fully offline

## Migration Plan

Current autoloads are already in place. Required changes:

1. **Fix initialization order**: `project.godot` must list `ContentService` before `AppState`.

2. **Add runtime assert in AppState**: In `_ready()`, assert `ContentService.content != {}` (or use `has_node("/root/ContentService")` + check `content.keys().size() > 0`) to detect order regression.

3. **Remove DatabaseService from autoloads**: When `DatabaseService.gd` is deleted, remove its entry from `project.godot` autoload section.

4. **Deprecate direct autoload access from UI screens**: Gradually refactor any screen that calls `AppState.whatever` directly to emit signals instead. app.gd handles the autoload calls.

## Validation Criteria
- [ ] `project.godot` autoload order is ContentService → AppState → BackupService (DatabaseService removed or last)
- [ ] `AppState._ready()` can call `ContentService.get_task_rules()` and receive valid data
- [ ] `ContentService._ready()` loads all 10 JSON files successfully
- [ ] No UI screen directly calls `AppState.save_to_disk()` (should go through app.gd signal routing)
- [ ] `state_changed` signal is connected and emitted after every mutation
- [ ] `DatabaseService` is not depended on by any active code path

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — defines storage patterns autoloads use; mandates initialization order
- ADR-0002 (GDScript-Only Stack) — autoloads are GDScript Nodes
- ADR-0004 (JSON Content Pipeline) — ContentService's content loading strategy