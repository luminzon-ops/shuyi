# ADR-0006: Practice Session State Machine

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: MINOR NOTES (accepted) 2026-05-19
> **TD-ADR Review**: CONCERNS (revised) 2026-05-19
> **Architecture Review**: Accepted by /architecture-review 2026-05-19 — closes TR-practice-001/002/005/008

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (gameplay flow, state management) |
| **Knowledge Risk** | MEDIUM — Godot 4.4–4.6 are near/beyond LLM training cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — GDScript `enum`, `Dictionary`, `Signal` are stable across all Godot 4.x versions |
| **Verification Required** | (1) Verify `session_finished` is emitted synchronously and that `app.gd`'s handler does not call `start_session()` inline — if it does, switch to `call_deferred("emit_signal", "session_finished", summary)`. (2) Verify `_process()` is not needed — all transitions are event-driven. (3) Verify deferred signal connections behave correctly in Godot 4.6.1 per `breaking-changes.md` note on signal connection order. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — AppState.record_answer() and complete_session() are called during EVALUATING and FINISHED transitions), ADR-0003 (Autoload Singleton Pattern — ContentService and AppState are accessed as autoloads during LOADING and EVALUATING), ADR-0005 (ScreenHolder Navigation Pattern — session_finished signal is routed through app.gd to ResultScreen) |
| **Enables** | ADR for QuestionRenderer Architecture (TR-qtypes-002/003), ADR for Wrong-Book and Achievement Evaluation Pipeline (TR-practice-009) |
| **Blocks** | Any story implementing PracticeScreen session flow |
| **Ordering Note** | Must be Accepted before practice-system stories can be marked Ready |

## Context

### Problem Statement
`PracticeScreen` manages a multi-step session lifecycle (resolve questions → render → evaluate → record → finish) using ad-hoc boolean flags and direct method calls with no explicit state model. This makes the session flow untestable (no way to assert "we are in state X"), fragile to extension (adding a new mode requires tracing implicit flag logic), and prone to double-execution bugs (e.g., `_finish_session()` called twice if a signal fires unexpectedly during the EVALUATING phase).

### Constraints
- **GDScript-only**: No C# or GDExtension (ADR-0002)
- **Single-scene architecture**: PracticeScreen is a pre-instantiated Control node; it is never freed and re-created (ADR-0005)
- **Offline-first**: All state transitions are local; no async network calls
- **Touch input**: State transitions are triggered by user taps, not timers or physics
- **Synchronous content resolution**: `ContentService` methods return data immediately; no async loading path exists

### Requirements
- Must model 6 session modes (level, special_practice, random_practice, mock_test, wrong_retry, mini_game)
- Must handle wrong-retry with fewer than 10 wrong answers (start with available count; block if 0)
- Must prevent double-execution of `_finish_session()` via state guard
- Must prevent re-entrant `start_session()` calls via state guard
- Must delegate sign-in idempotency to AppState (PracticeScreen calls `complete_session()` unconditionally)
- Must emit `session_finished(summary)` for routing by `app.gd` (ADR-0005)
- Must be testable: state can be asserted by reading `_state` via a getter property

## Decision

### Enum State Machine inside PracticeScreen

`PracticeScreen.gd` owns a private `_state: SessionState` variable. All session lifecycle transitions go through a single `_transition(new_state: SessionState)` method that guards against invalid transitions.

```gdscript
enum SessionState {
    IDLE,       # No session active; screen is hidden or at rest
    LOADING,    # Resolving questions — synchronous, transient guard state
    ACTIVE,     # Displaying a question; waiting for user input
    EVALUATING, # Answer submitted; evaluating and recording result
    FINISHED    # All questions answered; result calculated; session_finished emitted
}

var _state: SessionState = SessionState.IDLE

# Getter property — read-only access for tests and external observers
var state: SessionState:
    get: return _state
```

**Why enum inside PracticeScreen (not a separate node)**:
- PracticeScreen is the only consumer of this state machine — no reuse case exists
- Enum + single variable is the simplest GDScript pattern; no extra scene nodes or resources
- `_transition()` is directly callable in unit tests without scene instantiation
- Avoids the indirection cost of a separate StateMachine resource for a 5-state machine

**Modes vs. states**: Session mode (`level`, `special_practice`, etc.) is a config parameter passed to `start_session()` and carried through the session as `_current_mode`. The 5 states model lifecycle phase, not mode identity. All 6 modes share the same state machine; mode-specific logic is isolated to `_resolve_questions(config)`.

**LOADING as a transient guard state**: Because `ContentService` methods are synchronous, the LOADING state is entered and exited within a single call frame. Its purpose is not to wait for async data — it is to prevent re-entrant `start_session()` calls during resolution and to make the lifecycle explicit and auditable. If content resolution ever becomes async in the future, LOADING already has the correct semantics to become a real waiting state.

### State Transition Table

| From | Event | To | Guard |
|------|-------|----|-------|
| IDLE | `start_session(config)` called | LOADING | `if _state != IDLE: return` |
| LOADING | Questions resolved (count > 0) | ACTIVE | — |
| LOADING | Wrong-retry resolved (count == 0) | IDLE | Emit `session_error("no_wrong_questions")` |
| ACTIVE | Answer submitted | EVALUATING | — |
| EVALUATING | Answer recorded (more questions remain) | ACTIVE | — |
| EVALUATING | Answer recorded (last question) | FINISHED | — |
| FINISHED | State reset, then `session_finished` emitted | IDLE | `if _state != EVALUATING: return` in `_finish_session()` |

**Double-execution guard**: `_finish_session()` checks `if _state != SessionState.EVALUATING: return` before proceeding. This prevents any re-entrant call from executing the finish logic twice.

**Re-entry guard on `start_session()`**: `start_session()` checks `if _state != SessionState.IDLE: return` before transitioning. A double-tap or programmatic re-call while a session is active is silently ignored.

**Signal emission ordering**: In the FINISHED → IDLE transition, state is reset to IDLE *before* `session_finished` is emitted. This ensures that if `app.gd`'s handler calls `start_session()` synchronously in response to the signal, the state guard allows it (state is already IDLE). See Verification Required for the check to confirm this ordering is safe in Godot 4.6.1.

### Session Lifecycle (6 Modes)

All 6 modes share the same state machine. Mode-specific logic is isolated to `_resolve_questions(config)`:

| Mode | Resolution | Fallback |
|------|-----------|---------|
| `level` | `ContentService.get_questions_for_level(level_id)` | — |
| `special_practice` | `ContentService.get_questions_by_filters(filters)` | — |
| `random_practice` | `ContentService.get_random_questions(10)` | — |
| `mock_test` | `ContentService.get_mock_test_questions(grade_id, 10)` | — |
| `wrong_retry` | `AppState.get_wrong_question_ids_for_retry(10)` → `ContentService.get_wrong_retry_questions(ids)` | Block if 0 IDs returned |
| `mini_game` | Hardcoded in MiniGameScreen — not routed through PracticeScreen state machine | — |

**Wrong-retry with insufficient data**: If `AppState.get_wrong_question_ids_for_retry()` returns an empty array, `_transition(IDLE)` is called and `session_error("no_wrong_questions")` is emitted. `app.gd` handles this signal to show an appropriate message. If 1–9 IDs are returned, the session starts with that count.

### Sign-in Idempotency

`PracticeScreen` calls `AppState.complete_session(mode, level_id, correct_count, total_count, result)` unconditionally at FINISHED. `AppState.complete_session()` internally calls `mark_sign_in()`, which checks `last_sign_in == today` before awarding. PracticeScreen has no sign-in awareness — idempotency is fully owned by AppState (ADR-0001).

### Architecture Diagram

```
start_session(config)
        │
   ┌────▼────┐
   │  IDLE   │◄──────────────────────────────────────────────┐
   └────┬────┘  guard: if _state != IDLE: return             │
        │ _resolve_questions() [synchronous]                 │
   ┌────▼────┐                                               │
   │ LOADING │──[0 wrong answers]──► emit session_error      │
   └────┬────┘                       _transition(IDLE)       │
        │ questions resolved (count > 0)                     │
   ┌────▼────┐                                               │
   │  ACTIVE │◄──────────────────────────┐                  │
   └────┬────┘                           │                  │
        │ answer submitted               │                  │
   ┌────▼──────┐                         │                  │
   │ EVALUATING│──[more questions]───────┘                  │
   └────┬──────┘  guard: if _state != EVALUATING: return    │
        │ last question answered                            │
   ┌────▼────┐                                              │
   │ FINISHED│──► reset state to IDLE ─────────────────────┘
   └─────────┘    then emit session_finished(summary)
                  (app.gd routes to ResultScreen via ADR-0005)
```

### Key Interfaces

**PracticeScreen (new/modified)**:
- `start_session(config: Dictionary) -> void` — entry point; transitions IDLE → LOADING → ACTIVE
- `_transition(new_state: SessionState) -> void` — private; all state changes go through here
- `var state: SessionState` — getter property (read-only); `_state` is the backing private variable
- `session_finished(summary: Dictionary)` signal — emitted after state resets to IDLE on FINISHED transition
- `session_error(reason: String)` signal — emitted when LOADING fails (e.g., `"no_wrong_questions"`)

**AppState (unchanged interface, clarified ownership)**:
- `complete_session(mode, level_id, correct_count, total_count, result)` — owns sign-in idempotency, task updates, achievement evaluation trigger
- `record_answer(question_id, is_correct, user_answer)` — called once per EVALUATING transition

## Alternatives Considered

### Alternative 1: Separate StateMachine Node/Resource
- **Description**: A reusable `StateMachine.gd` resource that PracticeScreen holds a reference to. Each state is a separate object with `enter()`, `exit()`, and `update()` methods. Transitions are registered as a dictionary of `{from_state: {event: to_state}}`.
- **Pros**: Reusable across multiple screens if other screens need state machines; each state is isolated in its own class, making individual states independently testable; the pattern scales to hierarchical state machines if needed.
- **Cons**: Adds 5+ files (one per state class + the StateMachine resource) for a machine with no reuse case; the indirection between PracticeScreen and its states makes the flow harder to read at a glance; the `enter()`/`exit()` lifecycle adds boilerplate that provides no benefit when states don't have complex entry/exit logic; the pattern is designed for hierarchical or parallel states, neither of which this machine needs.
- **Rejection Reason**: No other screen in the app needs a state machine of this complexity. The enum approach is equally testable (state is a readable property), simpler to implement, and produces less code. If a second screen ever needs a state machine, the enum pattern can be extracted into a shared resource at that point — premature abstraction is not warranted now.

### Alternative 2: Document-Only (No Code Change)
- **Description**: Keep the current implicit flag-based approach in `PracticeScreen.gd`. Document the expected session flow in code comments and in this ADR. No structural code change.
- **Pros**: Zero implementation cost; no regression risk from refactoring.
- **Cons**: Does not fix the double-execution risk (the bug exists in the current code); does not make the state testable (no single variable to assert); does not address TR-practice-001/002/005/008 at the code level; the architecture review flagged these as code-level gaps, not documentation gaps.
- **Rejection Reason**: The problem is a code-level structural deficiency, not a documentation gap. Comments cannot prevent `_finish_session()` from being called twice; a state guard can.

### Alternative 3: Signal-Driven Implicit States (Status Quo)
- **Description**: Each lifecycle method emits a signal when done; the next method connects to that signal. The "state" is implicit in which signals are connected and which methods are pending.
- **Pros**: Decoupled; idiomatic Godot for simple event chains; no explicit state variable needed.
- **Cons**: Signal chains are hard to trace across a multi-step lifecycle; there is no single place to assert "what state are we in"; deferred signals can cause re-entrant execution (the exact bug this ADR is designed to fix); adding a new mode requires tracing which signals are connected and in what order.
- **Rejection Reason**: The current implementation already uses this pattern and it produced the double-execution risk that motivated this ADR. The pattern is appropriate for simple two-step event chains, not for a 5-phase lifecycle with 6 mode variants and edge-case fallbacks.

## Consequences

### Positive
- Session lifecycle is explicit and auditable — any developer can read the enum and transition table to understand the full flow
- `_finish_session()` double-execution is impossible once the state guard is in place
- `start_session()` re-entry is impossible once the IDLE guard is in place
- Unit tests can assert state by reading the `state` getter property
- Wrong-retry edge case (0 wrong answers) has a defined, testable code path
- Sign-in idempotency is correctly owned by AppState, not scattered across callers
- LOADING state has correct semantics for a future async content resolution path, if needed

### Negative
- Requires refactoring `PracticeScreen.gd` to replace ad-hoc flags with `_transition()` calls — regression risk during the refactor
- `_state` is private; external code must use the `state` getter property, not direct field access

### Risks
- **Regression during refactor**: Replacing implicit flags with explicit transitions could break existing session flow if transitions are mapped incorrectly. Mitigated by writing unit tests for each transition before refactoring, then verifying all tests pass after.
- **Deferred signal re-entry**: If `session_finished` is connected with `CONNECT_DEFERRED`, a second `start_session()` call could arrive before the FINISHED → IDLE transition completes. Mitigated by the state guard in `start_session()` — but the FINISHED → IDLE reset must complete before the deferred signal fires. Verify emission mode (see Verification Required).
- **SceneTree processing order (Godot 4.5 change)**: `breaking-changes.md` notes potential `_ready()` call order changes in 4.5. If `app.gd` connects to `session_finished` in its own `_ready()`, the connection order depends on which node's `_ready()` runs first. Low risk for this single-screen pattern, but worth verifying that `app.gd` connects before `PracticeScreen` can emit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| practice-system.md | 6 session modes orchestration (TR-practice-001) | LOADING state calls mode-specific `_resolve_questions()` for all 6 modes; mode is a config param, not a state |
| practice-system.md | Session lifecycle: start→render→evaluate→finish (TR-practice-002) | Explicit IDLE→LOADING→ACTIVE→EVALUATING→FINISHED transitions map 1:1 to the lifecycle steps |
| practice-system.md | Wrong-retry with insufficient data fallback (TR-practice-005) | LOADING → IDLE transition with `session_error("no_wrong_questions")` when 0 wrong IDs returned; 1–9 IDs start a shorter session |
| practice-system.md | Double sign-in prevention (TR-practice-008) | AppState.complete_session() owns idempotency via `mark_sign_in()` date check; PracticeScreen calls unconditionally at FINISHED |

## Performance Implications
- **CPU**: Negligible — enum comparison and method dispatch; no per-frame processing; no `_process()` override needed
- **Memory**: One integer (`_state`) added to PracticeScreen; no measurable impact
- **Load Time**: None
- **Network**: None

## Migration Plan
1. Add `enum SessionState` and `var _state: SessionState = SessionState.IDLE` to `PracticeScreen.gd`
2. Add `var state: SessionState` getter property
3. Add `_transition(new_state: SessionState) -> void` method with guard logic
4. Add `session_error(reason: String)` signal declaration
5. Write unit tests for each transition (IDLE→LOADING, LOADING→ACTIVE, LOADING→IDLE, ACTIVE→EVALUATING, EVALUATING→ACTIVE, EVALUATING→FINISHED, FINISHED→IDLE) before refactoring
6. Replace each implicit flag check with `_state` reads; replace each lifecycle method call with `_transition()` + method body
7. Verify all unit tests pass after refactor
8. Verify `session_finished` signal still routes correctly through `app.gd` (ADR-0005)

## Validation Criteria
- [ ] `PracticeScreen.state` returns `IDLE` on scene load
- [ ] `start_session(config)` transitions IDLE → LOADING → ACTIVE (synchronous, within one call frame for LOADING)
- [ ] Submitting an answer transitions ACTIVE → EVALUATING → ACTIVE (if more questions remain)
- [ ] Submitting the last answer transitions EVALUATING → FINISHED → IDLE and emits `session_finished`
- [ ] Calling `_finish_session()` twice does not double-emit `session_finished`
- [ ] Calling `start_session()` while `_state != IDLE` is silently ignored
- [ ] Wrong-retry with 0 wrong answers transitions LOADING → IDLE and emits `session_error("no_wrong_questions")`
- [ ] Wrong-retry with 1–9 wrong answers starts a session with that count (not padded to 10)
- [ ] `AppState.complete_session()` is called exactly once per session regardless of mode
- [ ] `AppState.mark_sign_in()` is not called directly by PracticeScreen

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — AppState.record_answer() and complete_session() are called during EVALUATING and FINISHED transitions
- ADR-0003 (Autoload Singleton Pattern) — ContentService and AppState are accessed as autoloads during LOADING and EVALUATING
- ADR-0005 (ScreenHolder Navigation Pattern) — session_finished signal is routed through app.gd to ResultScreen
