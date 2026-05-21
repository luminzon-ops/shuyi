# ADR-0008: QuestionRenderer Architecture

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: MINOR NOTES (incorporated) 2026-05-19
> **TD-ADR Review**: APPROVE 2026-05-19
> **Architecture Review**: Accepted by /architecture-review 2026-05-19 — closes TR-qtypes-002/003

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | UI (question rendering, input collection) |
| **Knowledge Risk** | MEDIUM — Godot 4.4–4.6 are near/beyond LLM training cutoff; Control node and Button APIs may have refinements |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Button.pressed` signal, `LineEdit.text`, `Control.visible`, `Node.queue_free()`, `Node.add_child()` — all stable across Godot 4.x; `Theme` system noted as potentially refined in 4.4+ (verify custom button styling) |
| **Verification Required** | Verify `Button.pressed` signal signature is unchanged in 4.6.1; verify that the `hide()`/`show()` wrapper around `queue_free()` + `add_child()` eliminates same-frame button overlap on Android; verify dynamically created Button nodes inherit PracticeScreen's Theme in Godot 4.6.1 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (GDScript-Only Stack — QuestionRenderer is a GDScript class), ADR-0005 (ScreenHolder Navigation — PracticeScreen is a pre-instantiated Control node that owns the UI containers passed to QuestionRenderer), ADR-0006 (Practice Session State Machine — render() is called during ACTIVE state; build_user_answer() is called during EVALUATING state) |
| **Enables** | None — this is a leaf ADR; no other ADR depends on QuestionRenderer |
| **Blocks** | Any story implementing question rendering or input collection for any question type |
| **Ordering Note** | Must be Accepted before question-type rendering stories can be marked Ready |

## Context

### Problem Statement
`QuestionRenderer` renders 10 question types and collects user input, but its architecture is undocumented at the ADR level. There is no defined interface contract for `render()` and `build_user_answer()`, no documented ownership of the three rendering modes (button-only, input-only, button+input), and no specification of how PracticeScreen and QuestionRenderer are coupled. This makes it impossible to write testable stories for individual question types without first establishing these boundaries.

### Constraints
- **GDScript-only**: No C# or GDExtension (ADR-0002)
- **Touch input only**: No keyboard/gamepad; all interaction is tap-based (technical-preferences.md)
- **10 question types**: 4 P0 (choice, true_false, fill_blank, mental_math) + 6 P1 (matching, drag_drop, sorting, shape_puzzle, application, multi_step)
- **PracticeScreen owns the UI containers**: `option_container` and `answer_input` are nodes in PracticeScreen's scene tree; QuestionRenderer receives them as parameters
- **No scene instantiation per question**: Rendering must be fast enough to be imperceptible on Android; creating new scenes per question is too slow

### Requirements
- Must render all 10 question types using one of three rendering modes
- Must clear previous question's UI before rendering the next question
- Must collect the user's answer as a String for all 10 types
- Must be testable: render() and build_user_answer() callable without a full PracticeScreen scene
- Must not own any scene nodes — it manipulates nodes passed to it by PracticeScreen

## Decision

### Standalone GDScript Class

`QuestionRenderer` is a standalone GDScript class (not a Node, not an autoload). PracticeScreen instantiates it once and holds a reference. All rendering is done by passing UI container references into `render()`.

```gdscript
# question_renderer.gd
class_name QuestionRenderer

func render(
    question: Dictionary,
    option_container: Control,
    answer_input: LineEdit,
    select_callback: Callable
) -> void

func build_user_answer(
    question_type: String,
    selected_option: String,
    answer_input: LineEdit
) -> String
```

**Why standalone class (not a Node)**:
- QuestionRenderer owns no scene nodes — it only manipulates nodes passed to it; there is nothing to add to the scene tree
- Instantiating as a plain class avoids the Node lifecycle overhead (`_ready()`, `_process()`, signal connections) for a stateless utility
- Directly callable in unit tests without scene instantiation: `var renderer = QuestionRenderer.new()`

### Three Rendering Modes

All 10 question types map to one of three rendering modes:

| Mode | Types | option_container | answer_input |
|------|-------|-----------------|--------------|
| **Button-only** | choice, true_false | Buttons created; each calls `select_callback` on press | Hidden |
| **Input-only** | fill_blank, mental_math, application, multi_step | Hidden (no options) | Shown; keyboard focus set |
| **Button+Input** | matching, drag_drop, sorting, shape_puzzle | Buttons created; each appends `value + ">"` to `answer_input.text` | Shown; starts empty |

### render() Behaviour

1. Hide `option_container` (`option_container.hide()`)
2. Clear `option_container`: call `queue_free()` on all existing children
3. Determine rendering mode from `question.type`
4. Set `answer_input.visible` per mode
5. For Button-only and Button+Input modes: create one `Button` node per option in `question.options`; connect `pressed` signal to `select_callback` (Button-only) or to PracticeScreen's append callback (Button+Input)
6. For Input-only and Button+Input modes: clear `answer_input.text`; set keyboard focus if applicable
7. Show `option_container` (`option_container.show()`) after all `add_child()` calls complete

**Node cleanup ownership**: `render()` is responsible for clearing `option_container` before each render. PracticeScreen does not need to manage cleanup — it calls `render()` and the renderer handles the full lifecycle of the option buttons.

**select_callback contract**: For Button-only types, each button's `pressed` signal calls `select_callback.call(option_value: String)`. PracticeScreen provides this callback to capture the selected option for `build_user_answer()`.

### build_user_answer() Behaviour

| Type group | Return value |
|-----------|-------------|
| choice, true_false | `selected_option` (set by `select_callback`) |
| fill_blank, mental_math, application, multi_step | `answer_input.text` |
| matching, drag_drop, sorting, shape_puzzle | `answer_input.text` (contains `>` separated selections) |

### Architecture Diagram

```
PracticeScreen (ACTIVE state)
        │
        │ _renderer.render(question, option_container, answer_input, select_callback)
        ▼
QuestionRenderer.render()
    ├── clear option_container (queue_free all children)
    ├── set visibility per mode
    ├── [Button-only / Button+Input] create Button nodes, connect signals
    └── [Input-only / Button+Input] clear answer_input.text

User taps option or types answer
        │
        │ [Button-only] select_callback(option_value) → PracticeScreen stores selected_option
        │ [Input-only / Button+Input] answer_input.text updated directly
        ▼

PracticeScreen (EVALUATING state)
        │
        │ _renderer.build_user_answer(question.type, _selected_option, answer_input)
        ▼
QuestionRenderer.build_user_answer()
    └── returns String → passed to ContentService.evaluate_answer()
```

### Key Interfaces

**QuestionRenderer**:
- `render(question: Dictionary, option_container: VBoxContainer, answer_input: LineEdit, select_callback: Callable) -> void` — clears and re-renders the question UI; called once per question during ACTIVE state
- `build_user_answer(question_type: String, selected_option: String, answer_input: LineEdit) -> String` — collects the user's answer as a String; called once per question during EVALUATING state

**PracticeScreen (caller)**:
- Instantiates `QuestionRenderer` once: `var _renderer := QuestionRenderer.new()`
- Provides `option_container: VBoxContainer` and `answer_input: LineEdit` as persistent scene nodes
- Provides `select_callback: Callable` that stores the selected option in `_selected_option: String`
- For **Button+Input types**, PracticeScreen's callback also appends `value + ">"` to `answer_input.text` — this append logic lives in PracticeScreen, not QuestionRenderer. Adding a new Button+Input type requires updating both `QuestionRenderer` (rendering mode mapping) and PracticeScreen (callback append logic).
- Calls `_renderer.render()` on ACTIVE state entry
- Calls `_renderer.build_user_answer()` on answer submission (ACTIVE → EVALUATING transition)

## Alternatives Considered

### Alternative 1: Scene-Based Per-Type Renderers
- **Description**: Each question type has its own `.tscn` scene file (e.g., `ChoiceQuestion.tscn`, `FillBlankQuestion.tscn`). PracticeScreen instantiates the appropriate scene per question and adds it to a container.
- **Pros**: Each type is fully self-contained with its own layout; visual designers can edit each type independently in the Godot editor; no shared container management.
- **Cons**: 10 scene files to maintain; scene instantiation per question causes perceptible hitches on Android (scene loading is not free); each scene must be preloaded or loaded on demand; the shared evaluation path (`ContentService.evaluate_answer()`) still requires a common interface, so the scenes would need a common base class or duck-typed API anyway; overkill for types that differ only in which nodes are visible.
- **Rejection Reason**: The 10 types differ only in rendering mode (which nodes are visible and how buttons are connected) — not in layout structure. A single class with a 3-mode switch is simpler, faster, and easier to maintain than 10 scene files. Scene instantiation overhead is a real concern on the Android target.

### Alternative 2: Resource-Based Type Definitions
- **Description**: Each question type is defined as a `Resource` subclass with `render()` and `collect_answer()` methods. QuestionRenderer is a dispatcher that loads the appropriate resource and delegates to it.
- **Pros**: Open/closed principle — adding a new type requires only a new Resource file, not modifying QuestionRenderer; each type is independently testable.
- **Cons**: Adds a Resource class per type (10 files) for a problem that has only 3 distinct rendering modes; the Resource pattern is designed for data, not for UI manipulation logic; the dispatcher still needs to know which resource to load for each type, recreating the switch statement inside the dispatcher.
- **Rejection Reason**: The 3-mode switch in `render()` is the correct level of abstraction for 10 types that map to 3 behaviors. The Resource pattern would add 10 files and a dispatcher for no reduction in complexity. If a 4th rendering mode is ever needed, adding a case to the switch is simpler than adding a new Resource class.

### Alternative 3: Autoload Singleton
- **Description**: QuestionRenderer is registered as a Godot autoload, accessible globally from any script.
- **Pros**: No instantiation needed; accessible from PracticeScreen and any future screen that needs question rendering.
- **Cons**: QuestionRenderer is stateless and has no reason to persist across scenes; making it an autoload adds it to the global namespace for no benefit; ADR-0003 limits autoloads to the 4 established services (ContentService, AppState, BackupService, DatabaseService); adding a 5th autoload for a utility class contradicts the established pattern.
- **Rejection Reason**: Autoloads are for services that must persist and be accessible globally (ADR-0003). QuestionRenderer is a stateless utility used only by PracticeScreen. A plain class instantiated by its sole consumer is the correct pattern.

## Consequences

### Positive
- `render()` and `build_user_answer()` are independently testable without a scene: `QuestionRenderer.new().render(...)` works in a unit test with mock containers
- The 3-mode rendering model is explicit and documented — any developer can read the mode table and understand the full rendering behavior
- PracticeScreen does not need to manage button cleanup — `render()` owns the full lifecycle of option buttons
- No scene instantiation per question — rendering is sub-frame on Android

### Negative
- `render()` calls `queue_free()` on all option_container children on every question, even when the next question has the same type. This is a minor inefficiency for consecutive same-type questions, but negligible at 10 questions per session.
- QuestionRenderer is a plain class, not a Node — it cannot use `@export` annotations or be configured in the Godot editor. All configuration is via method parameters.

### Risks
- **`queue_free()` + `add_child()` on same frame**: Calling `queue_free()` on children and then `add_child()` for new children in the same frame may cause a frame where both old and new buttons are visible. `queue_free()` defers deletion to end-of-frame; new children are added immediately. Mitigation: call `option_container.hide()` before the `queue_free()` loop, then `option_container.show()` after all `add_child()` calls complete. Do NOT use `free()` as a mitigation — calling `free()` on a node mid-frame can cause crashes on Android if the GL compatibility renderer is mid-draw or if the node has pending signals.
- **`">"` separator fragility**: The Button+Input mode uses `">"` as a delimiter in `answer_input.text` (e.g., `"A>B>C"`). If a question option value ever contains `">"`, the delimiter becomes ambiguous and `ContentService.evaluate_answer()` normalization will produce incorrect results. Mitigation: validate question data to prohibit `">"` in option values for matching/drag_drop/sorting/shape_puzzle types, or switch to a non-printable separator if the question bank ever requires `">"` in options.
- **`">"` lambda closure in button loop**: The lambda `func() -> void: select_callback.call(button.text)` captures `button` by reference in a loop. In GDScript 4, each loop iteration creates a new `Button` object, so each lambda captures a distinct object reference — this is safe. However, future maintainers may attempt to "fix" this by capturing the value explicitly; do not change this pattern without verifying the GDScript 4 closure semantics.
- **`Theme` system changes in 4.4+**: `deprecated-apis.md` notes Theme system refinements in 4.4+. If PracticeScreen applies a custom Theme to `option_container`, verify that dynamically created Button nodes inherit the theme correctly in Godot 4.6.1.
- **select_callback lifetime**: The `select_callback` Callable is created by PracticeScreen and passed to `render()`. If PracticeScreen is freed while a button's `pressed` signal is still connected, the callback will reference a freed object. Mitigated by the ScreenHolder pattern (ADR-0005) — PracticeScreen is never freed during the app lifetime.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| question-types.md | Per-type rendering: Buttons vs LineEdit (TR-qtypes-002) | Three rendering modes (Button-only, Input-only, Button+Input) map all 10 types to explicit UI configurations |
| question-types.md | Per-type input collection (TR-qtypes-003) | `build_user_answer()` returns the correct String for each type group; Button-only uses `selected_option`, others use `answer_input.text` |

## Performance Implications
- **CPU**: Negligible — `queue_free()` + `add_child()` for up to ~6 buttons per question; no per-frame processing
- **Memory**: Option buttons are freed between questions; peak memory is one question's worth of Button nodes (~6 nodes)
- **Load Time**: None — QuestionRenderer is instantiated once at PracticeScreen `_ready()`
- **Network**: None

## Migration Plan
1. Verify `QuestionRenderer` is already a standalone GDScript class (not a Node) — if it is a Node, convert it
2. Confirm `render()` and `build_user_answer()` signatures match the Key Interfaces above; update if needed
3. Add `queue_free()` cleanup loop at the start of `render()` if not already present
4. Write unit tests for each rendering mode (Button-only, Input-only, Button+Input) using mock containers
5. Write unit tests for `build_user_answer()` for each type group
6. Verify all 10 types render correctly in a manual PracticeScreen session

## Validation Criteria
- [ ] `QuestionRenderer.new()` succeeds without a scene tree (plain class instantiation)
- [ ] `render()` with a `choice` question creates Button nodes in `option_container` and hides `answer_input`
- [ ] `render()` with a `fill_blank` question hides `option_container` and shows `answer_input`
- [ ] `render()` with a `matching` question creates Button nodes AND shows `answer_input`
- [ ] `render()` clears all previous option buttons before rendering the next question
- [ ] Tapping a Button-only option calls `select_callback` with the option value
- [ ] Tapping a Button+Input option appends `value + ">"` to `answer_input.text`
- [ ] `build_user_answer("choice", selected_option, answer_input)` returns `selected_option`
- [ ] `build_user_answer("fill_blank", "", answer_input)` returns `answer_input.text`
- [ ] `build_user_answer("matching", "", answer_input)` returns `answer_input.text`

## Related Decisions
- ADR-0002 (GDScript-Only Stack) — QuestionRenderer is a GDScript class
- ADR-0005 (ScreenHolder Navigation Pattern) — PracticeScreen owns the UI containers passed to QuestionRenderer; PracticeScreen is never freed (mitigates select_callback lifetime risk)
- ADR-0006 (Practice Session State Machine) — render() is called during ACTIVE state; build_user_answer() is called during EVALUATING state
