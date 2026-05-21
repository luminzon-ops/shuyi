# Architecture Review Report

> **Date**: 2026-05-19
> **Engine**: Godot 4.6.1
> **Mode**: `/architecture-review` (full)
> **GDDs reviewed**: 7
> **ADRs reviewed**: 5
> **Verdict**: **CONCERNS**

## Context

All seven GDDs and all five ADRs are flagged `status: reverse-documented`
— they describe an already-shipping v0.9.2 implementation. "Coverage gaps"
in this report mean *documentation debt*, not *missing implementation*.

## Inputs

| Type | Files |
|------|-------|
| GDDs | game-concept, content-system, practice-system, question-types, growth-system, persistence-system, ui-navigation |
| ADRs | 0001 offline-first, 0002 gdscript-only, 0003 autoload, 0004 json-content, 0005 screenholder |
| Engine reference | VERSION.md, breaking-changes.md, deprecated-apis.md (no per-module docs) |
| Standards | `.claude/docs/technical-preferences.md` |

`docs/architecture/architecture.md` and `tr-registry.yaml` did not exist;
this review seeds them.

## Traceability Summary

| Status | Count |
|--------|-------|
| ✅ Covered | 27 |
| ⚠️ Partial | 9 |
| ❌ Gap | 13 |
| 🔴 Conflict (GDD vs ADR) | 1 |
| **Total requirements** | **50** |

Full matrix lives in `docs/architecture/traceability-index.md`. Stable
requirement IDs are seeded in `docs/architecture/tr-registry.yaml`.

## Coverage Gaps (priority list)

### Foundation / Core (highest priority)
- ❌ **TR-practice-002** — Session lifecycle (start → render → record → finish).
  Six modes share one flow with no ADR.
  *Suggested ADR*: `Practice Session State Machine`.
- ❌ **TR-practice-005**, **TR-practice-009** — Wrong-book + achievement
  evaluation pipeline. Logic is in `AppState.record_answer()` and
  `AppState.complete_session()` with no architectural anchor.
  *Suggested ADR*: `Wrong-Book and Achievement Evaluation Pipeline`.
- ❌ **TR-qtypes-002**, **TR-qtypes-003** — `QuestionRenderer` rendering and
  input contract (option buttons vs LineEdit, select_callback delegate).
  *Suggested ADR*: `QuestionRenderer Architecture`.

### Feature layer
- ❌ **TR-growth-006/007/008** — Growth engine (level-up loop, streak reset,
  weekly cap). Streak reset is GDD-flagged as not yet implemented.
  *Suggested ADR*: `Growth Progression Engine`.
- ❌ **TR-ui-009** — Audio playback (click sound, optional file existence).
  Should follow a dedicated `audio-system.md` GDD first; that GDD does not
  yet exist.

### Cross-cutting
- ❌ **TR-concept-004** — 60fps performance budget exists only in
  `technical-preferences.md`. Either make it an ADR or annex to ADR-0002.

## Cross-ADR Conflicts

**No ADR ↔ ADR conflicts.** All five ADRs cite each other coherently and the
dependency graph is acyclic.

### ADR Dependency Order (topo-sorted)

```
Foundation (no deps):
  1. ADR-0001 — Offline-First Data Architecture
Depends on Foundation:
  2. ADR-0002 — GDScript-Only Stack                  (← 0001)
  3. ADR-0003 — Autoload Singleton Pattern           (← 0001, 0002)
Feature layer:
  4. ADR-0004 — JSON Content Pipeline                (← 0002, 0003)
  5. ADR-0005 — ScreenHolder Navigation              (← 0003)
```

No unresolved dependencies. No cycles.

## GDD ↔ ADR Conflict (single)

🔴 **TR-persist-004 — `persistence-system.md` "SQLite Snapshot" section**

| GDD assumption | Verified reality (ADR-0001) |
|----------------|------------------------------|
| SQLite serves as a redundant recovery snapshot | DatabaseService is non-functional on Android — `sqlite3` binary is not accessible to apps. Replaced by shadow-JSON backup. Scheduled for removal. |
| Default save data uses `app_version: 0.5.0-expanded` | Should read from `ProjectSettings.get_setting("application/config/version")` |
| Dependencies list "SQLite via OS shell execution" | Removed |

**Action**: revise `persistence-system.md`. systems-index Status updated to
`Needs Revision` (see Phase 5b application below).

## GDD Revision Flags Applied

| File | Change |
|------|--------|
| `design/gdd/systems-index.md` | Persistence System Status: `Approved` → `Needs Revision` |

## Engine Compatibility Audit

| Check | Result |
|-------|--------|
| ADRs with Engine Compatibility section | 5 / 5 |
| Engine version consistency | All 5 say Godot 4.6.1 |
| Deprecated API references in ADRs | None — `OS.execute("sqlite3")` already flagged for removal in ADR-0001 |
| Post-cutoff API conflicts | None — all ADRs use stable pre-4.4 APIs |
| Stale notes | `deprecated-apis.md` mentions "SQLite addon" — project actually used `OS.execute`. Minor doc drift, non-blocking. |

Engine specialist consultation skipped — every ADR explicitly states
`Post-Cutoff APIs Used: None`, so there is nothing for the specialist to
second-guess.

## Architecture Document Coverage

`docs/architecture/architecture.md` does not exist. Not blocking for a
project of this scale — `systems-index.md` plus the five ADRs cover the
architectural surface — but a one-page architecture overview would help
onboarding when more contributors arrive.

## Hardcoded-Value Debt (advisory)

Coding standards say "Gameplay values must be data-driven, never hardcoded."
The following violations exist and should migrate to JSON rule files in
upcoming stories — not architectural blockers, just tech debt:

- `practice_screen.gd` — "10 questions per session" (non-level modes)
- `AppState.complete_session()` — `study_minutes += 5`
- `app.gd` — default level id `level_grade1_addition_1`, click-sound path
- `mini_game_screen.gd` — 5 questions per mode, hardcoded question banks

## Verdict: CONCERNS

- Foundation layer (persistence, scripting, autoloads, content pipeline,
  navigation) is fully covered with clean dependency ordering and no
  engine compatibility issues.
- One GDD ↔ ADR conflict (persistence SQLite section) needs the GDD
  revised — non-blocking because ADR-0001 already mandates the corrected
  behavior.
- Several feature-layer behaviors lack dedicated ADRs. Acceptable for a
  reverse-documented v0.9.2 codebase shipping today, but each new story
  touching these systems risks drifting without an architectural anchor.

**Blocking issues**: None for the current shipping build. Before adding
new gameplay features, write the missing ADRs in priority order above.

## Required ADRs (in suggested write order)

1. `Practice Session State Machine` — covers TR-practice-002, -005, -008
2. `QuestionRenderer Architecture` — covers TR-qtypes-002, -003 (and the implicit TR-qtypes-001 renderer side)
3. `Wrong-Book and Achievement Evaluation Pipeline` — covers TR-practice-009, TR-growth-004
4. `Growth Progression Engine` — covers TR-growth-001, -006, -007, -008, TR-practice-006
5. `Audio Integration` — covers TR-ui-009 (after writing an `audio-system.md` GDD first)
6. `Performance Budget` — covers TR-concept-004 (or annex into ADR-0002)

## Pre-Gate Checklist

| Item | Status |
|------|--------|
| `tests/unit/` and `tests/integration/` | ❌ Missing — run `/test-setup` |
| `.github/workflows/tests.yml` | ❌ Missing — run `/test-setup` |
| `design/accessibility-requirements.md` | ❌ Missing — run `/ux-design` |
| `design/ux/interaction-patterns.md` | ❌ Missing — run `/ux-design` |

`/gate-check pre-production` cannot be offered until all four are present.

## Re-run Trigger

Re-run `/architecture-review` after each new ADR is written; coverage
will tick up gap-by-gap and verdict will move toward PASS once the
Foundation/Core gaps are filled and `persistence-system.md` is revised.

