# Architecture Traceability Index

> **Last Updated**: 2026-05-20 (refresh after ADR-0009 Accepted; ADR-0010/0011 Proposed)
> **Engine**: Godot 4.6.1
> **Source**: refreshed by `/architecture-review` 2026-05-20

## Coverage Summary

| Status | Count | % |
|--------|-------|----|
| ✅ Covered | 44 | 88% |
| ⚠️ Partial | 4 | 8% |
| ❌ Gap | 0 | 0% |
| 🔴 Conflict | 0 | 0% |
| Carry-over (annotated) | 2 | 4% |
| **Total** | **50** | **100%** |

> Carry-over rows are previously-partial requirements whose architectural backing did not change in this review — kept as ⚠️ pending narrow doc refinement, not architecture work.

## Full Matrix

| TR-ID | GDD | Domain | Requirement | ADR Coverage | Status |
|-------|-----|--------|-------------|--------------|--------|
| TR-content-001 | content-system.md | Data Schema | 4-level hierarchy (Grade→Module→KP→Level→Questions) | ADR-0004 | ✅ |
| TR-content-002 | content-system.md | Data Pipeline | 10 JSON config files loaded at startup | ADR-0004 | ✅ |
| TR-content-003 | content-system.md | Data Pipeline | Filter questions by grade/module/kp/type | ADR-0004 | ✅ |
| TR-content-004 | content-system.md | Data Pipeline | Random + mock_test selection | ADR-0004 | ✅ |
| TR-content-005 | content-system.md | State | Level unlock_next propagation | ADR-0004 | ✅ |
| TR-content-006 | content-system.md | Resilience | Empty/missing files return [] gracefully | ADR-0001, ADR-0004 | ✅ |
| TR-content-007 | content-system.md | Data Schema | Exactly 10 questions per level | ADR-0004 | ✅ |
| TR-practice-001 | practice-system.md | Gameplay | 6 session modes orchestration | ADR-0006 | ✅ |
| TR-practice-002 | practice-system.md | Gameplay | Session lifecycle (start→render→evaluate→finish) | ADR-0006 | ✅ |
| TR-practice-003 | practice-system.md | Logic | Type-aware answer evaluation | ADR-0004 | ✅ |
| TR-practice-004 | practice-system.md | Logic | Result calculation (accuracy/stars/reward) | ADR-0004 | ✅ |
| TR-practice-005 | practice-system.md | Gameplay | Wrong-retry with insufficient data fallback | ADR-0006, ADR-0007 | ✅ |
| TR-practice-006 | practice-system.md | State | Answer history capped at 200 | ADR-0001 (implicit) | ⚠️ |
| TR-practice-007 | practice-system.md | Communication | session_finished → ResultScreen routing | ADR-0005 | ✅ |
| TR-practice-008 | practice-system.md | State | Double sign-in prevention | ADR-0006, ADR-0007, ADR-0009 | ✅ |
| TR-practice-009 | practice-system.md | Logic | Achievement evaluation post-answer + post-session | ADR-0007 | ✅ |
| TR-qtypes-001 | question-types.md | UI/Logic | 10 question types supported | ADR-0004, ADR-0008 | ✅ |
| TR-qtypes-002 | question-types.md | UI | Per-type rendering (Buttons vs LineEdit) | ADR-0008 | ✅ |
| TR-qtypes-003 | question-types.md | UI | Per-type input collection | ADR-0008 | ✅ |
| TR-qtypes-004 | question-types.md | Logic | Numeric comparison (is_equal_approx) | ADR-0004 | ✅ |
| TR-qtypes-005 | question-types.md | Logic | Complex normalization (CN punctuation, separators) | ADR-0004 | ✅ |
| TR-growth-001 | growth-system.md | Logic | Level-up curve (exp >= level*100, carry-over) | ADR-0009 | ✅ |
| TR-growth-002 | growth-system.md | Logic | Daily sign-in (idempotent on date) | ADR-0009 | ✅ |
| TR-growth-003 | growth-system.md | Logic | Daily/weekly tasks (progress + claim) | ADR-0004, ADR-0007, ADR-0009 (split) | ⚠️ |
| TR-growth-004 | growth-system.md | Logic | Achievement progress tracking | ADR-0004, ADR-0007 | ✅ |
| TR-growth-005 | growth-system.md | State | Gold currency (no cap, no spend yet) | ADR-0001, ADR-0009 | ✅ |
| TR-growth-006 | growth-system.md | Logic | Streak reset on missed day | ADR-0009 | ✅ |
| TR-growth-007 | growth-system.md | Logic | Level-up check after every EXP gain | ADR-0009 | ✅ |
| TR-growth-008 | growth-system.md | State | Weekly progress capped at 100 | ADR-0009 | ✅ |
| TR-persist-001 | persistence-system.md | Data Schema | save_data 8-section schema | ADR-0001 | ✅ |
| TR-persist-002 | persistence-system.md | Persistence | Save trigger after every state mutation | ADR-0001 | ✅ |
| TR-persist-003 | persistence-system.md | Persistence | _merge_defaults() schema evolution | ADR-0001 | ✅ |
| TR-persist-004 | persistence-system.md | Persistence | Shadow-backup recovery | ADR-0001 | ✅ |
| TR-persist-005 | persistence-system.md | Persistence | Backup ZIP (json + version + checksum) | ADR-0001 | ✅ |
| TR-persist-006 | persistence-system.md | Persistence | Import validation (sections + checksum) | ADR-0001 | ⚠️ |
| TR-persist-007 | persistence-system.md | Persistence | Default values for fresh install | ADR-0001 | ✅ |
| TR-persist-008 | persistence-system.md | Persistence | Atomic write (corruption prevention) | ADR-0001 | ✅ |
| TR-persist-009 | persistence-system.md | Resilience | Corrupt save fallback chain | ADR-0001 | ✅ |
| TR-ui-001 | ui-navigation.md | UI | 9 screens pre-instantiated under ScreenHolder | ADR-0005 | ✅ |
| TR-ui-002 | ui-navigation.md | UI | Title/subtitle update per navigation | ADR-0005 | ✅ |
| TR-ui-003 | ui-navigation.md | UI | Bottom 5-button nav | ADR-0005 | ✅ |
| TR-ui-004 | ui-navigation.md | Architecture | Single-scene (no change_scene) | ADR-0005 | ✅ |
| TR-ui-005 | ui-navigation.md | Communication | Signal routing through app.gd | ADR-0003, ADR-0005 | ✅ |
| TR-ui-006 | ui-navigation.md | State | Hidden screen state preservation | ADR-0005 | ✅ |
| TR-ui-007 | ui-navigation.md | UI | refresh_view() hook on entry | ADR-0005 | ✅ |
| TR-ui-008 | ui-navigation.md | UI | Context-appropriate back routing | ADR-0005 | ✅ |
| TR-ui-009 | ui-navigation.md / audio-system.md | Audio | Click sound (gated by sound_enabled + file existence) | ADR-0011 | ✅ |
| TR-ui-010 | ui-navigation.md | State | Default level fallback (level_grade1_addition_1) | — | ⚠️ |
| TR-concept-001 | game-concept.md | Platform | Android portrait 720×1280, touch only | ADR-0010, technical-prefs | ✅ |
| TR-concept-002 | game-concept.md | Architecture | Offline-first, no network | ADR-0001, ADR-0002 | ✅ |
| TR-concept-003 | game-concept.md | Architecture | Data-driven content (JSON configs) | ADR-0002, ADR-0004 | ✅ |
| TR-concept-004 | game-concept.md | Performance | 60fps performance budget | ADR-0010 | ✅ |

## ADR Status Summary

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | Offline-First Data Architecture | Accepted |
| 0002 | GDScript-Only Stack | Accepted |
| 0003 | Autoload Singleton Pattern | Accepted |
| 0004 | JSON Content Pipeline | Accepted |
| 0005 | ScreenHolder Navigation Pattern | Accepted |
| 0006 | Practice Session State Machine | Accepted |
| 0007 | Wrong-Book / Achievement Pipeline | Accepted |
| 0008 | QuestionRenderer Architecture | Accepted |
| 0009 | Growth Progression Engine | Accepted |
| 0010 | Performance Budget | Accepted |
| 0011 | Audio Integration Architecture | Accepted |

## Known Gaps (suggested ADRs)

(none — all 50 TRs have architectural backing as of 2026-05-20)

### Required Promotions

(none — ADR-0010 and ADR-0011 promoted to Accepted on 2026-05-20)

## Remaining Partials (doc refinements, not architecture work)

| TR-ID | Refinement needed |
|-------|-------------------|
| TR-practice-006 | Encode the 200-cap on `answer_history` as an explicit invariant in ADR-0001 or ADR-0006 |
| TR-growth-003 | Consolidate task-lifecycle (rules / progress / claim / weekly reset) into a single ADR or annex into ADR-0007 |
| TR-ui-010 | Either annex the default-level fallback rule into ADR-0005 or accept it as a code-level convention |
| TR-persist-006 | Document the precise required-section list and checksum algorithm in ADR-0001 (currently described in persistence-system.md only) |

## Conflicts

(none)

## Superseded Requirements

(none yet)

## History

| Date | Coverage | Verdict | Notes |
|------|----------|---------|-------|
| 2026-05-19 | 74% | CONCERNS | ADR-0006/0007/0008 accepted; persistence GDD revised |
| 2026-05-20 | 88% | CONCERNS | ADR-0009 accepted; ADR-0010/0011 proposed; all gaps closed |
| 2026-05-20 | 88% | (architecture PASS-equivalent) | ADR-0010/0011 promoted to Accepted; only pre-gate infra remains |
