# ADR-0002: GDScript-Only Stack

## Status
Accepted

## Date
2026-05-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Scripting |
| **Knowledge Risk** | MEDIUM — Godot 4.4–4.6 are near/beyond LLM training cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — GDScript language features used are stable across 4.x |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — established that `OS.execute("sqlite3")` is non-functional on Android, motivating the decision to not add C# or GDExtension for native SQLite) |
| **Enables** | All gameplay and UI implementation — GDScript is the single language for the entire codebase |
| **Blocks** | Any story proposing C#, C++, or GDExtension components |
| **Ordering Note** | This is a cross-cutting foundational decision that must be Accepted before any code implementation stories |

## Context

### Problem Statement
Godot 4.6 supports three primary scripting approaches: GDScript (Python-like, Godot-native), C# (.NET 8+), and GDExtension (C/C++). For a small-team (effectively solo) educational app targeting Android, we need to decide which language(s) to use and commit to that choice for the entire project lifetime.

### Constraints
- **Solo/small team**: No dedicated C# or C++ specialists
- **AI-assisted development**: The developer collaborates with Claude Code agents, which have better coverage of GDScript than C# or C++ for Godot-specific patterns
- **Android target**: Must build and deploy cleanly without complex toolchain setup
- **Offline-first**: No server or network code that would benefit from C# or C++ performance
- **Data size**: Player state is ~10–50KB; content data is ~1MB JSON — no data-processing bottleneck that would justify a compiled language

### Requirements
- Must support the entire app without language switching overhead
- Must build cleanly on Android with `gl_compatibility` renderer
- Must be maintainable by a solo developer with AI assistance
- Must not require additional build tooling beyond Godot's built-in export pipeline

## Decision

### GDScript as the Sole Language

All game code — gameplay logic, UI screens, autoloads, data access, backup/export — is written in **GDScript**. No C#, no GDExtension, no C++.

**Rationale**:

1. **Godot-native integration**: GDScript is designed for Godot's node/signal/resource architecture. Signals, `@export`, `@onready`, and `preload()` all work without boilerplate. C# requires `partial` classes, `[Export]` attributes, and `GetNode()` calls — more verbose for the same outcome.

2. **Fast iteration**: GDScript has no compile step. Edit, save, run. C# requires a .NET build, which adds 2–10 seconds per iteration on modest hardware. For a UI-heavy app with frequent visual tweaks, this compounds.

3. **AI assistance quality**: Claude Code and similar tools have strong coverage of GDScript for Godot-specific patterns (signals, scene instantiation, resource loading). C# Godot coverage is weaker in training data, especially for Godot 4.x.

4. **No performance bottleneck**: The app's heaviest operations are JSON serialization (~10–50KB) and SQLite shell commands (which are already non-functional on Android per ADR-0001). Neither would benefit measurably from a compiled language. The content pipeline loads JSON once at startup — no runtime data processing bottleneck.

5. **Simple Android build**: GDScript exports directly to Android without any .NET SDK, Mono runtime, or native toolchain setup. The build pipeline is `Godot Editor → Export → APK`. C# requires .NET SDK, Mono runtime bundling, and larger APK size.

6. **Single-language consistency**: All 16 source files in `shuyi_playland/` are already GDScript. Introducing a second language would fragment the codebase, require cross-language boundary management, and complicate debugging.

### What This Means for the Codebase

- All `.gd` files follow GDScript conventions: `snake_case` for variables/functions, `PascalCase` for classes, `UPPER_SNAKE_CASE` for constants
- All scenes use GDScript attached scripts
- No `.cs` files, no `.gdextension` files, no C++ build configuration
- If a future feature genuinely needs C# or C++ performance (unlikely at this scale), the decision to add a second language requires superseding this ADR explicitly

### Architecture Diagram

```
┌─────────────────────────────────────┐
│           Godot 4.6.1               │
│  ┌───────────────────────────────┐  │
│  │      GDScript Only            │  │
│  │  ┌─────────┐ ┌─────────────┐ │  │
│  │  │ Autoload│ │ UI Screens  │ │  │
│  │  │ (.gd)   │ │ (.gd)       │ │  │
│  │  └─────────┘ └─────────────┘ │  │
│  │  ┌─────────┐ ┌─────────────┐ │  │
│  │  │ Core    │ │ Question    │ │  │
│  │  │ (.gd)   │ │ Renderer    │ │  │
│  │  └─────────┘ └─────────────┘ │  │
│  └───────────────────────────────┘  │
│         No C# / No C++              │
└─────────────────────────────────────┘
```

### Key Interfaces

All interfaces are defined in GDScript:

**AppState**: `extends Node` — autoload singleton, `save_data: Dictionary`, `save_to_disk()`, `state_changed` signal
**ContentService**: `extends Node` — autoload singleton, `content: Dictionary`, `get_questions_for_level()`, `evaluate_answer()`
**QuestionRenderer**: `class_name QuestionRenderer, extends RefCounted` — `render()`, `build_user_answer()`
**Screen scripts**: `extends Control` — screen-specific logic, signal-based communication with `app.gd`

## Alternatives Considered

### Alternative 1: GDScript + C#
- **Description**: GDScript for gameplay and UI, C# for performance-critical systems (e.g., replacing the non-functional SQLite shell with a proper C# SQLite library)
- **Pros**: C# has richer ecosystem (NuGet packages, better IDE tooling), slight performance advantage on heavy logic
- **Cons**: Requires .NET SDK setup; larger APK size with Mono runtime; cross-language boundary between GDScript and C# is awkward (signals work, but direct method calls require marshalling); adds complexity for a solo developer; no actual performance bottleneck exists in the app
- **Rejection Reason**: The only system that would benefit from C# (SQLite) is already documented as non-functional on Android in ADR-0001, with the resolution being a shadow JSON backup — not a native module. Adding C# for zero concrete benefit would fragment the codebase and complicate the build.

### Alternative 2: GDScript + GDExtension (C++)
- **Description**: GDScript for most code, C++ GDExtension for hot paths (e.g., question evaluation, JSON parsing)
- **Pros**: Maximum performance for critical paths; native binary compilation
- **Cons**: Steepest learning curve; requires C++ toolchain; complex build setup; overkill for a 10–50KB data-processing app; no hot path has been identified
- **Rejection Reason**: The app's performance is entirely I/O-bound (file reads) and UI-bound (screen rendering). No CPU-bound algorithm exists that would benefit from C++. GDExtension is appropriate for custom physics, rendering, or large-scale data processing — none of which apply here.

## Consequences

### Positive
- Consistent single-language codebase — no context switching, no cross-language debugging
- Fastest possible iteration loop — edit, save, test with no compile step
- Smallest APK size — no Mono runtime or native libraries bundled
- Simplest build pipeline — Godot's built-in export, no additional SDKs
- Best AI assistance coverage for Godot-specific patterns
- All existing code (16 GDScript files) is already aligned — no migration needed

### Negative
- GDScript performance ceiling is lower than C# or C++ — but no workload in this app approaches that ceiling
- GDScript static typing is weaker than C# — but the codebase uses typed variables and return types consistently
- No access to NuGet ecosystem — but the app has zero external library dependencies
- If future scope expands to multiplayer, real-time collaboration, or heavy data processing, this decision may need revisiting

### Risks
- **Future performance needs**: If the app grows to 1000+ questions with complex real-time evaluation, GDScript may become a bottleneck. Mitigation: profile first, then consider a targeted C# or GDExtension module only for the identified hot path. Supersede this ADR explicitly if that happens.
- **Team expansion**: If a C# specialist joins the team, they'd need to learn GDScript. Mitigation: GDScript is deliberately simple (Python-like syntax), and the codebase is small enough to learn quickly.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | Offline-first, no server dependency | GDScript exports directly to Android without runtime dependencies |
| content-system.md | JSON content pipeline at startup | GDScript's `JSON.parse_string()` and `FileAccess` are sufficient for ~1MB of content data |
| practice-system.md | Question evaluation and scoring | GDScript handles all evaluation logic with negligible performance cost |
| ui-navigation.md | ScreenHolder pattern with signal routing | GDScript signals are native and idiomatic for this pattern |
| persistence-system.md | Save/load, backup, import/export | GDScript's `FileAccess`, `ZIPPacker`, and `DirAccess` cover all I/O needs |

## Performance Implications
- **CPU**: Negligible — GDScript is more than fast enough for JSON parsing, UI logic, and simple arithmetic
- **Memory**: No overhead — GDScript objects are lightweight; no Mono runtime or native library memory footprint
- **Load Time**: Faster than C# — no .NET JIT compilation on startup
- **APK Size**: Smaller than C# — no Mono runtime bundled (~5-10MB saved)
- **Network**: None — fully offline

## Migration Plan
No migration needed — the entire codebase is already GDScript. This ADR documents and locks in the existing choice.

If a future feature genuinely requires C# or C++:
1. Profile the specific feature to confirm GDScript is the bottleneck
2. Propose a new ADR that supersedes this one for the specific subsystem
3. Maintain GDScript for all other systems — do not migrate the entire codebase

## Validation Criteria
- [ ] All source files in `shuyi_playland/` are `.gd` files (no `.cs`, no `.cpp`, no `.gdextension`)
- [ ] `project.godot` has no C# or Mono configuration
- [ ] Android export builds successfully without .NET SDK or Mono runtime
- [ ] APK size is within budget (GDScript-only builds are smaller than C# builds)
- [ ] All autoloads, UI screens, and core logic use GDScript signals and conventions consistently

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — established that sqlite3 shell is non-functional on Android, removing the only potential motivation for C#/GDExtension (a native SQLite module)
- ADR-0003 (Autoload Singleton Pattern) — all autoloads are GDScript classes
- ADR-0004 (JSON Content Pipeline) — content loading uses GDScript's FileAccess and JSON APIs