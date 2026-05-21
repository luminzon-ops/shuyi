# Architecture Review — 2026-05-20

> **Verdict**: CONCERNS (improved from CONCERNS at 2026-05-19, coverage 74% → 88%)
> **Engine**: Godot 4.6.1
> **Mode**: full
> **GDDs Reviewed**: 9 (game-concept, content-system, practice-system, question-types, growth-system, persistence-system, ui-navigation, audio-system, systems-index)
> **ADRs Reviewed**: 11 (0001–0011)

## Headline

Three new ADRs have been added since the 2026-05-19 review:

| ADR | Title | Status | Closes |
|-----|-------|--------|--------|
| ADR-0009 | Growth Progression Engine | Accepted | TR-growth-006/007/008; upgrades TR-growth-001/002/005 |
| ADR-0010 | Performance Budget | **Proposed** | TR-concept-004 (and elevates TR-concept-001) |
| ADR-0011 | Audio Integration Architecture | **Proposed** | TR-ui-009 |

The previously open Foundation/Feature/Cross-cutting gaps are now all closed. The only reason this review is not PASS is that **ADR-0010 and ADR-0011 remain Proposed** — they cannot govern story acceptance until Accepted. Pre-gate infrastructure (tests/, CI, UX, accessibility) is also still missing, but those are not architecture concerns.

---

## Traceability Summary

| Status | Count | % | Δ vs 2026-05-19 |
|--------|-------|----|-----------------|
| ✅ Covered | 44 | 88% | +7 |
| ⚠️ Partial | 6 | 12% | -1 |
| ❌ Gap | 0 | 0% | -6 |
| 🔴 Conflict | 0 | 0% | 0 |
| **Total** | **50** | 100% | |

## Updated Matrix Rows (Δ since last review)

| TR-ID | Was | Now | Reason |
|-------|-----|-----|--------|
| TR-growth-001 (level-up curve) | ⚠️ ADR-0004 | ✅ ADR-0009 | `_check_level_up()` while-loop with carry-over formally specified |
| TR-growth-002 (daily sign-in idempotent) | ⚠️ ADR-0004 | ✅ ADR-0009 | Same-day guard + `_update_streak_and_weekly()` documented |
| TR-growth-005 (gold currency) | ⚠️ ADR-0001 | ✅ ADR-0001, ADR-0009 | Gold mutation path through `_apply_reward()` |
| TR-growth-006 (streak reset on missed day) | ❌ | ✅ ADR-0009 | Algorithm + edge cases (empty `last_sign_in`, `roundi()`, ISO 8601) |
| TR-growth-007 (level-up after every EXP gain) | ❌ | ✅ ADR-0009 | Trigger contract + call-site map; forbidden direct `profile.exp` mutation |
| TR-growth-008 (weekly_progress capped at 100) | ❌ | ✅ ADR-0009 | `min(...,100)` cap + ISO-week reset on sign-in |
| TR-ui-009 (click sound gates) | ❌ | ✅ ADR-0011 | `_init_audio_player()` + `_play_sound()` canonical pattern |
| TR-concept-001 (Android portrait + touch) | ⚠️ tech-prefs | ✅ ADR-0010 | Platform constraint elevated into ADR-0010 target hardware section |
| TR-concept-004 (60fps performance budget) | ❌ | ✅ ADR-0010 | Frame-time, draw-call, memory allocations specified per-system |

## Remaining Partials (4)

| TR-ID | GDD | Reason still ⚠️ |
|-------|-----|------------------|
| TR-practice-006 | practice-system | Answer-history 200-cap is in shipping code + GDD; no ADR explicitly encodes the cap as an invariant — minor doc gap |
| TR-growth-003 | growth-system | Daily/weekly task tracking + claim flow split across ADR-0004 (rules), ADR-0007 (claim gate), ADR-0009 (weekly_progress) — no single ADR fully owns the task lifecycle |
| TR-ui-010 | ui-navigation | Default level fallback (`level_grade1_addition_1`) lives only in code/GDD; no ADR coverage |
| TR-persist-006 | persistence-system | Import-validation flow described in ADR-0001 at high level; the precise required-section list is GDD-only |

These are documentation refinements, not architectural risks. None block the verdict.

## Cross-ADR Conflicts

**None detected.** All 11 ADRs are internally consistent. Notable cross-references that were verified clean:

- ADR-0011 → ADR-0009 — `_check_level_up()` is the level-up signal trigger site. ADR-0011 Migration Plan step 6 documents the new `level_up(new_level: int)` signal that must be added to AppState. This is a coordination obligation, not a conflict.
- ADR-0011 → ADR-0010 — 4 WAV files (~2–5MB) within the 80MB asset budget. Consistent.
- ADR-0009 → ADR-0007 — `_apply_reward()` is jointly owned: ADR-0007 defines its existence as the shared reward-application method; ADR-0009 documents its level-up + weekly_progress side-effects. The split is explicit in both ADRs and is not a conflict.
- ADR-0010 → ADR-0001 — Save I/O budgeted at 1ms; ADR-0001's atomic-write pattern is acknowledged. ADR-0010 also documents `save_to_disk.call_deferred()` (callable syntax) as a mitigation for slow Android storage. Consistent.
- ADR-0010 → ADR-0005 — 50MB UI memory budget assumes ADR-0005's 9 pre-instantiated screens at <5MB each. Consistent.

## ADR Dependency Order (topological)

```
Foundation (no deps):
  1. ADR-0001  Offline-First Data Architecture   [Accepted]
  2. ADR-0002  GDScript-Only Stack                [Accepted]

Tier 2 (depends on Foundation):
  3. ADR-0003  Autoload Singleton Pattern         [Accepted]
  4. ADR-0004  JSON Content Pipeline              [Accepted]

Tier 3:
  5. ADR-0005  ScreenHolder Navigation Pattern    [Accepted]
  6. ADR-0008  QuestionRenderer Architecture      [Accepted]
  7. ADR-0010  Performance Budget                 [Proposed]  ⚠

Tier 4:
  8. ADR-0006  Practice Session State Machine     [Accepted]

Tier 5:
  9. ADR-0007  Wrong-Book / Achievement Pipeline  [Accepted]

Tier 6:
 10. ADR-0009  Growth Progression Engine          [Accepted]

Tier 7 (leaf):
 11. ADR-0011  Audio Integration                  [Proposed]  ⚠
```

No cycles. No unresolved Proposed dependencies (ADR-0011 depends on ADR-0009, which is Accepted).

## Engine Compatibility Audit

| Item | Result |
|------|--------|
| Engine version consistency | ✅ All 11 ADRs target Godot 4.6.1 |
| Deprecated API references in ADRs | ✅ None |
| Post-cutoff API conflicts | ✅ None |
| Verification-required items still open | ⚠ 3 (carried over from the three new ADRs) |

### Open verification items (advisory; do not block this verdict)

- **ADR-0009** — `Time.get_unix_time_from_datetime_string(date + "T00:00:00")` behavior on Android with date-only strings; `roundi()` correctness; `_get_iso_week()` boundary dates (Dec 28 / Jan 3).
- **ADR-0010** — `Performance.MEMORY_STATIC` / `MEMORY_DYNAMIC` enum availability and Profiler panel layout in Godot 4.6.1.
- **ADR-0011** — `AudioStreamPlayer.bus = "Master"` and `ResourceLoader.exists()` for `.wav` resources on Android APK.

These are properly recorded inside each ADR's `Verification Required` field and become test obligations during story implementation. They are not architecture-review blockers.

### Engine Specialist Consultation

Skipped — all three new ADRs already carry `Godot Specialist Review (Engine Compatibility)` stamps from 2026-05-19. Re-spawning would duplicate accepted work.

### Stale engine-reference cleanup (low priority)

`docs/engine-reference/godot/deprecated-apis.md` line 27 still lists 4 autoloads including `DatabaseService` and SQLite addon notes. ADR-0001 deprecates both. Recommend a single-line touch-up to align the reference doc with reality.

## Phase 5b — GDD Revision Flags

**None.** All GDD assumptions are consistent with verified engine behavior. The previous flag (persistence-system.md ↔ ADR-0001 shadow-backup) was resolved 2026-05-19. No new revision flags are introduced by ADRs 0009–0011.

## Architecture Document Coverage

`docs/architecture/architecture.md` does not exist. The traceability index + 11 ADRs serve as the de-facto architecture spec, which is appropriate for a project of this scale and team size. Not flagged.

---

## Pre-Gate Checklist (status: still blocking)

| Item | Status |
|------|--------|
| `tests/unit/` directory | ❌ |
| `tests/integration/` directory | ❌ |
| `.github/workflows/tests.yml` | ❌ |
| `design/accessibility-requirements.md` | ❌ |
| `design/ux/` directory | ❌ |

These five items remain the blockers between architecture review and `/gate-check pre-production`. They are not architectural concerns — the verdict on architecture is independent of the pre-gate state.

---

## Verdict: **CONCERNS**

Architecture coverage is now **88%** with **zero gaps and zero conflicts**. The verdict is not PASS for two narrow reasons:

1. **ADR-0010 and ADR-0011 are still `Proposed`.** They cannot be cited as governing decisions in story acceptance criteria until promoted to Accepted.
2. **Pre-gate infrastructure remains incomplete.** Test scaffolding, CI workflow, accessibility requirements, and UX docs are all missing. These are not architecture issues but block phase advancement.

### Required to reach PASS

- Promote ADR-0010 (Performance Budget) to **Accepted**
- Promote ADR-0011 (Audio Integration Architecture) to **Accepted**

No new ADRs are required. All 50 technical requirements have at least partial architectural coverage.

### Required to advance to Pre-Production gate

- Run `/test-setup` to scaffold `tests/unit/`, `tests/integration/`, and `.github/workflows/tests.yml`
- Run `/ux-design` to author `design/ux/interaction-patterns.md` and `design/accessibility-requirements.md` (note: project standard places accessibility in `design/`; the `ux-review` skill expects it in `design/ux/` — confirm location with the UX skill before authoring)

---

## Recommended Next Actions

1. Promote ADR-0010 and ADR-0011 from Proposed → Accepted (review the verification-required items first; either confirm acceptable as documented risks or assign quick verification tasks).
2. Run `/test-setup` to unblock the pre-gate test infrastructure.
3. Run `/ux-design` to author the interaction-patterns and accessibility specs.
4. (Low priority) Clean up `docs/engine-reference/godot/deprecated-apis.md` to remove stale DatabaseService / SQLite addon notes.

After steps 1–3 are complete, `/gate-check pre-production` should produce a clean PASS.
