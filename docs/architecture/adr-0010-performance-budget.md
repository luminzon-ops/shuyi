# ADR-0010: Performance Budget

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: MINOR NOTES (incorporated) 2026-05-19
> **TD-ADR Review**: CONCERNS (structural gaps resolved) 2026-05-19
> **Promoted Proposed → Accepted**: 2026-05-20 via `/architecture-review`. Verification Required items (Android frame time, draw call, Profiler memory monitors) are inherited as Production-phase test obligations.

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Rendering / Core (performance constraints) |
| **Knowledge Risk** | MEDIUM — Godot 4.4–4.6 rendering pipeline changes may affect draw call counts and frame budget allocation |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None — `gl_compatibility` renderer and Godot Profiler are stable across 4.x |
| **Verification Required** | Verify draw call count on Android device using Godot Debugger > Profiler; verify frame time stays under 16.6ms during a full practice session with 10 questions; verify `Performance.MEMORY_STATIC` and `Performance.MEMORY_DYNAMIC` monitor constants are available in Godot 4.6.1 (Profiler panel layout and available monitors have changed across 4.4–4.6 — confirm against official 4.6.1 docs before using for budget enforcement) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — `gl_compatibility` renderer chosen for mobile; save I/O is synchronous and must fit within budget), ADR-0002 (GDScript-Only Stack — no native performance escape hatch; all optimisation must be achievable in GDScript), ADR-0005 (ScreenHolder Navigation Pattern — 9 pre-instantiated screens consume the 50MB UI memory allocation; ADR-0005's "<5MB per screen" estimate is the basis for this budget slice) |
| **Enables** | None — this is a cross-cutting constraint ADR; all implementation ADRs and stories are bounded by it |
| **Blocks** | Any story that introduces a new rendering technique, particle system, or heavy computation loop without a performance justification |
| **Ordering Note** | Should be Accepted before Production phase begins so story acceptance criteria can reference specific budget numbers |

## Context

### Problem Statement
The 60fps performance target for Android (TR-concept-004) is stated in `technical-preferences.md` but has no ADR-level contract. Without per-system frame time allocations, story acceptance criteria cannot reference specific budget numbers, and there is no architectural basis for rejecting a feature that would push the app over budget. The values in `technical-preferences.md` are configuration, not decisions — this ADR elevates them to architectural commitments with rationale.

### Constraints
- **Target hardware**: Android phones, portrait 720×1280; minimum spec is a mid-range Android device (2GB RAM, Snapdragon 600-class or equivalent)
- **Renderer**: `gl_compatibility` — chosen for broad Android compatibility (ADR-0001); Vulkan Mobile is not used
- **GDScript-only**: No C# or GDExtension performance escape hatch (ADR-0002); all optimisation must be achievable in GDScript
- **Single-scene architecture**: All 9 screens are pre-instantiated; no scene loading hitches during navigation (ADR-0005)
- **Offline-first**: No network I/O on the critical path; save I/O is the only disk operation during gameplay

### Requirements
- Must maintain 60fps (16.6ms frame budget) during normal gameplay on the minimum target device
- Must stay within 100 draw calls per frame
- Must stay within 256MB total memory
- Must not hitch during screen transitions (ScreenHolder pattern guarantees this — ADR-0005)
- Must not hitch during save I/O (save is triggered after every answer — must complete within the frame budget or be deferred)

## Decision

### Top-Level Budget

| Metric | Budget | Source |
|--------|--------|--------|
| Target framerate | 60fps | technical-preferences.md |
| Frame time | 16.6ms | derived from 60fps |
| Draw calls | 100 max | technical-preferences.md |
| Memory ceiling | 256MB | technical-preferences.md |

### Per-System Frame Time Allocation

| System | Budget | Owner | Notes |
|--------|--------|-------|-------|
| UI rendering (Control nodes, labels, buttons) | 4ms | PracticeScreen, all screens | Largest consumer; 9 pre-instantiated screens, only 1 visible |
| Game logic (AppState mutations, ContentService queries) | 2ms | AppState, ContentService | Includes `_apply_reward()`, `_check_level_up()`, `_evaluate_achievements_*()` |
| Question rendering (QuestionRenderer) | 1ms | QuestionRenderer | `queue_free()` + `add_child()` for up to ~6 buttons per question |
| Save I/O (atomic write to disk) | 1ms | AppState | ~10–50KB JSON write; synchronous on main thread |
| Headroom / GC / engine overhead | 8.6ms | Engine | GDScript GC, physics tick (unused but present), signal dispatch |
| **Total** | **16.6ms** | | |

**Rationale for headroom allocation**: GDScript's garbage collector runs on the main thread and can cause unpredictable spikes. 8.6ms headroom (52% of the frame) is intentionally large to absorb GC pauses, signal dispatch overhead, and any per-frame engine work. This is appropriate for a UI-heavy app with no physics simulation.

**Save I/O note**: `AppState.save_to_disk()` is synchronous and runs on the main thread. At ~10–50KB, a JSON write on Android flash storage typically completes in under 1ms. If profiling shows save I/O exceeding 1ms, the mitigation is to defer the write to the next idle frame using `call_deferred("save_to_disk")`. This is not implemented by default — the synchronous pattern is simpler and sufficient at current data size.

### Draw Call Budget Allocation

| System | Draw Call Budget | Notes |
|--------|----------------|-------|
| Active screen UI | 80 | All visible Control nodes, labels, buttons, panels |
| Background / decorative elements | 10 | Any background sprites or decorative nodes |
| Headroom | 10 | Engine UI, debug overlays (stripped in release) |
| **Total** | **100** | |

**Why 100 draw calls**: The `gl_compatibility` renderer on Android batches 2D draw calls aggressively. 100 is a conservative ceiling for a UI-only app with no 3D rendering. The actual draw call count for a typical screen is expected to be 20–40.

### Memory Budget Allocation

| Category | Budget | Notes |
|----------|--------|-------|
| Engine + GDScript runtime | ~80MB | Godot 4.x baseline on Android |
| Content data (10 JSON files, in-memory) | ~5MB | Questions, levels, rules — read-only |
| Player save data (in-memory Dictionary) | ~1MB | ~10–50KB serialized; Dictionary overhead |
| UI scene tree (9 pre-instantiated screens) | ~50MB | Control nodes, textures, fonts |
| Textures / sprites / audio | ~80MB | Art assets; audio clips |
| Headroom | ~40MB | OS overhead, GC, fragmentation |
| **Total** | **~256MB** | |

### Profiling Tool

**Godot built-in Debugger > Profiler tab** is the reference tool for all performance validation:
- **Frame time**: Monitor `frame_time` — must stay under 16.6ms
- **Draw calls**: Monitor `draw_calls_in_frame` — must stay under 100
- **Script time**: Monitor per-function script time — flag any function exceeding its system budget
- **Memory**: Use `Performance.get_monitor(Performance.MEMORY_STATIC)` and `Performance.get_monitor(Performance.MEMORY_DYNAMIC)` — flag if combined total approaches 256MB. Note: `static_memory_usage_by_type` is not a valid monitor name in Godot 4; use the `Performance.Monitor` enum constants.

Profiling must be done on an Android device (not the Godot editor on desktop), as the `gl_compatibility` renderer behaves differently on desktop vs. Android.

### Architecture Diagram

```
Frame budget: 16.6ms
├── UI rendering          4.0ms  (PracticeScreen, all screens)
├── Game logic            2.0ms  (AppState, ContentService)
├── Question rendering    1.0ms  (QuestionRenderer)
├── Save I/O              1.0ms  (AppState.save_to_disk)
└── Headroom / GC / engine 8.6ms (GDScript GC, signal dispatch, engine)

Draw call budget: 100
├── Active screen UI      80     (Control nodes)
├── Background elements   10     (decorative)
└── Headroom              10     (engine, debug)

Memory budget: 256MB
├── Engine runtime        80MB
├── UI scene tree         50MB
├── Textures / audio      80MB
├── Content data           5MB
├── Save data              1MB
└── Headroom              40MB
```

### Key Interfaces

This ADR defines constraints, not APIs. The following rules apply to all implementation stories:

- Any story that adds a new `_process()` or `_physics_process()` override must justify it against the 2ms game logic budget
- Any story that adds new textures or audio assets must estimate their memory contribution against the 80MB asset budget
- Any story that adds draw calls (new visible nodes, new sprites) must estimate against the 80-call UI budget
- `AppState.save_to_disk()` must complete within 1ms; if profiling shows it exceeding this, defer using the callable syntax: `save_to_disk.call_deferred()` (not the Godot 3 string form `call_deferred("save_to_disk")`). Note: `call_deferred` only delays execution to the end of the current frame — the write still runs on the main thread and will still block if Android flash storage is slow. If deferral is insufficient, the long-term mitigation is a worker thread with a mutex.

## Alternatives Considered

### Alternative 1: Annex into ADR-0002 (GDScript-Only Stack)
- **Description**: Add a "Performance Implications" section to ADR-0002 that documents the budget numbers. No new ADR file.
- **Pros**: Fewer files; performance is related to the language choice (GDScript has no native escape hatch).
- **Cons**: ADR-0002 is about language choice, not performance budgets — mixing concerns makes both harder to find; the performance budget is a cross-cutting constraint that applies to all systems, not just the scripting layer; annexing it into ADR-0002 would make it invisible to stories that don't reference ADR-0002.
- **Rejection Reason**: Performance budgets are a first-class architectural constraint that every implementation story should be able to reference independently. A standalone ADR is more discoverable and more clearly scoped.

### Alternative 2: Promote technical-preferences.md Values Without a New ADR
- **Description**: Treat `technical-preferences.md` as the authoritative performance contract. No ADR needed — stories reference the preferences file directly.
- **Pros**: No new file; values are already documented.
- **Cons**: `technical-preferences.md` is configuration, not a decision record — it has no rationale, no alternatives considered, no consequences section; it cannot explain *why* 100 draw calls or 256MB was chosen; stories that reference it have no architectural backing for rejecting over-budget implementations.
- **Rejection Reason**: An ADR provides rationale and consequences that a preferences file cannot. The per-system allocation (which system owns which budget slice) is a decision that belongs in an ADR, not a flat config file.

### Alternative 3: No Performance Budget ADR (Leave as Gap)
- **Description**: Accept TR-concept-004 as a documentation gap and close it by noting the values in technical-preferences.md.
- **Pros**: Zero effort.
- **Cons**: Stories have no architectural reference for "within budget"; the traceability index shows a gap; the architecture review will continue to flag it.
- **Rejection Reason**: The gap exists precisely because there is no architectural contract. Closing it requires a decision record, not just acknowledging the gap.

## Consequences

### Positive
- Every implementation story can reference specific budget numbers in its acceptance criteria (e.g., "must not increase draw calls by more than 5")
- The per-system allocation makes it clear which team owns which budget slice
- The headroom allocation is explicit — future developers understand why 52% of the frame is reserved
- Save I/O deferral path is documented before it is needed

### Negative
- The per-system allocations are estimates, not measurements — they must be validated by profiling on a real Android device before being treated as hard limits
- The 256MB memory budget is a ceiling, not a target — the actual memory usage of the current build is unknown and must be measured

### Risks
- **GDScript GC spikes**: GDScript's garbage collector can cause frame spikes that exceed the 8.6ms headroom. Mitigation: avoid allocating large temporary arrays or Dictionaries in `_process()` callbacks; prefer pre-allocated structures.
- **Save I/O on slow Android storage**: On devices with slow flash storage, `save_to_disk()` may exceed 1ms. `call_deferred` only moves the write to the next frame — it does not make it non-blocking. Mitigation: use `save_to_disk.call_deferred()` (callable syntax) as a first step; if profiling still shows hitches, implement a worker thread with a mutex for the file write. The synchronous pattern is acceptable at current data size (~10–50KB) but must be re-evaluated if save data grows significantly.
- **Pre-instantiated screens memory**: 9 pre-instantiated screens (ADR-0005) consume memory even when hidden. If the 50MB UI budget is exceeded, the mitigation is to lazy-instantiate low-priority screens (e.g., Settings, Achievements) rather than pre-instantiating all 9.
- **Budget drift**: As new features are added, draw calls and memory usage will grow. Mitigation: run the Godot Profiler at the end of each sprint to catch budget drift early.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | 60fps performance budget on Android (TR-concept-004) | Defines 16.6ms frame budget, 100 draw call ceiling, 256MB memory ceiling, per-system allocations, and profiling tool |

## Performance Implications
- **CPU**: This ADR defines the budget; it does not add CPU cost
- **Memory**: This ADR defines the budget; it does not add memory cost
- **Load Time**: Not applicable
- **Network**: Not applicable

## Migration Plan
No code changes required. This ADR documents existing constraints. The following validation steps are recommended:

1. Run Godot Debugger > Profiler on an Android device during a full practice session (10 questions, all 6 session modes)
2. Record baseline frame time, draw call count, and memory usage
3. Compare against the budgets defined in this ADR
4. If any system exceeds its allocation, file a performance story to investigate and optimise
5. Add performance budget checks to the sprint close-out checklist

## Validation Criteria
- [ ] Frame time stays under 16.6ms during a full practice session on the minimum target Android device
- [ ] Draw call count stays under 100 during normal gameplay
- [ ] Total memory usage stays under 256MB
- [ ] `AppState.save_to_disk()` completes within 1ms (measured via Godot Profiler script time)
- [ ] No `_process()` override in any screen exceeds 2ms script time

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — `gl_compatibility` renderer chosen for mobile; save I/O is synchronous
- ADR-0002 (GDScript-Only Stack) — no native performance escape hatch; all optimisation in GDScript
- ADR-0005 (ScreenHolder Navigation Pattern) — pre-instantiated screens consume memory budget; no scene loading hitches
