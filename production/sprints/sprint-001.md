# Sprint 1 — 2026-05-21 to 2026-06-03

## Sprint Goal

Close the ADR migration plan gaps in AppState and PracticeScreen, complete HUD
polish items flagged by the gate check, and expand the question bank toward 300.

## Capacity

| | Value |
|---|---|
| Working days | 10 |
| Daily hours (solo, half-day) | ~3.5 hrs |
| Total hours | ~35 hrs |
| Buffer (20%) | 7 hrs |
| Available | ~28 hrs (~8 effective days) |

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S1-01 | ADR-0001: Implement atomic write + shadow backup in `AppState.save_to_disk()` | godot-gdscript-specialist | 0.5d | — | `save_to_disk()` writes to `.tmp` then renames; `savegame.bak` created before every save; `load_or_create()` tries primary → backup → defaults |
| S1-02 | ADR-0001: Fix autoload order in `project.godot` (ContentService before AppState) | godot-specialist | 0.25d | — | Autoload order: ContentService → AppState → BackupService; `AppState._ready()` assert on `ContentService.content` non-empty passes |
| S1-03 | ADR-0001: Upgrade backup checksum to `String.hash()` | godot-gdscript-specialist | 0.25d | S1-01 | `BackupService.export_backup()` uses `String.hash()` not character count; import validates correctly |
| S1-04 | ADR-0009: Implement `_update_streak_and_weekly()` + streak reset | godot-gdscript-specialist | 1d | S1-02 | Consecutive sign-in increments streak; 2+ day gap resets to 1; `weekly_progress` resets on ISO week boundary; unit tests pass including Dec 28/Jan 3 edge cases |
| S1-05 | ADR-0009: Refactor `mark_sign_in()` to route EXP through `_apply_reward()` | godot-gdscript-specialist | 0.5d | S1-04 | `mark_sign_in()` calls `_apply_reward()` not direct exp mutation; `_check_level_up()` while-loop handles carry-over; unit tests pass |
| S1-06 | ADR-0006: Add `SessionState` enum + `_transition()` to `PracticeScreen.gd` | godot-gdscript-specialist | 1.5d | — | `PracticeScreen.state` returns IDLE on load; all 7 transitions pass unit tests; `_finish_session()` double-execution impossible; `start_session()` re-entry guard works; existing session flow unbroken |
| S1-07 | HUD: Implement `_set_nav_enabled(bool)` in `app.gd` — disable bottom nav during active sessions | godot-gdscript-specialist | 0.5d | S1-06 | Bottom nav tabs disabled on `start_session()`; re-enabled on `session_finished` and `back_requested`; manual test confirms no accidental session abandonment |
| S1-08 | Contrast verification pass (medium blue + orange button) | manual | 0.25d | — | `Color(0.31, 0.36, 0.62)` contrast ratio verified ≥4.5:1 or corrected; orange button label contrast verified; results documented in `production/qa/contrast-check-2026-05-21.md` |
| S1-12 | ADR-0003: Remove `DatabaseService` from autoloads + delete file | godot-specialist | 0.25d | S1-02 | `DatabaseService` removed from `project.godot`; `DatabaseService.gd` deleted; no remaining references in active code paths |
| S1-13 | Define feedback color palette (correct-green, wrong-red, EXP-gold, HUD float-up gold) | art-director / docs | 0.25d | — | Four `Color()` constants defined with documented hex values and WCAG contrast ratios on white card background; documented in `design/ux/hud.md` (Feedback Moment section) and ready for S1-08 contrast verification + S1-06 FeedbackLabel implementation |

**Must Have total**: ~5.25 days / ~18.5 hrs

### Should Have (Stretch — complete opportunistically after Must Have)

| ID | Task | Owner | Est. | Dependencies | Acceptance Criteria |
|----|------|-------|------|-------------|-------------------|
| S1-09 | Expand question bank: +50 questions (target 208 total) | content | 1d | — | `questions.json` has ≥208 entries; all new questions load without errors |
| S1-10 | ADR-0011: Refactor `app.gd` audio to `_init_audio_player()` + `_play_sound()` | godot-gdscript-specialist | 0.5d | — | `click_player` initialized via `_init_audio_player()`; `_play_sound()` gates on `sound_enabled` + null check; rapid taps don't stack; warm-up call added |
| S1-11 | Register P-11 Answer Feedback Display in `interaction-patterns.md` | docs | 0.25d | — | P-11 entry added with full spec, When to Use, When NOT to Use |

**Should Have total**: ~1.75 days / ~6 hrs

### Deferred to Sprint 2

The following items were scoped for this sprint but deferred by producer feasibility review to avoid overcommitment:

- S1-13: Expand question bank +50 more (target 258) — carry to Sprint 2
- S1-14: ADR-0011 answer SFX + level-up signal — carry to Sprint 2
- S1-15: Reverse-documented art bible — carry to Sprint 2

## Sequencing Notes (from producer review)

1. **S1-02 first** — autoload order fix de-risks all subsequent ADR-0001 testing
2. **S1-13 before S1-06** — feedback color palette must be defined before FeedbackLabel implementation; also feeds S1-08 contrast verification (per AD-PHASE-GATE 2026-05-21 evening)
3. **Pair S1-04 + S1-05** as a single thread — both touch the reward/streak path; doing them together reduces context-switch and re-test cost
4. **Schedule S1-06 mid-sprint** — highest-risk refactor; do it when energy is highest and there's still room to recover from a slip, not at sprint end

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| S1-06 SessionState refactor breaks existing session flow | Medium | High | Write unit tests for all 7 transitions BEFORE refactoring; verify manually after; budget 1.5d not 1d |
| ADR-0009 streak reset introduces date-arithmetic bugs on Android | Medium | Medium | Unit tests must cover Dec 28/Jan 3 edge cases; verify on device |
| Contrast fix requires scene-wide color changes | Low | Medium | Verify first; if medium blue fails, update color in all scenes in one pass |
| First-sprint velocity calibration (no prior data) | Medium | Medium | Must Have is 54% of available budget — healthy slack for first-sprint slip |

## Dependencies on External Factors

- Android device needed for contrast verification (S1-08) and ADR-0009 date arithmetic verification
- Question content authoring (S1-09) may require admin backend access

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed and acceptance criteria verified
- [ ] ADR-0001 atomic write + shadow backup implemented and tested
- [ ] ADR-0006 SessionState enum in place with passing unit tests
- [ ] ADR-0009 streak reset implemented with passing unit tests
- [ ] Bottom nav disabled during sessions (HUD spec requirement)
- [ ] Contrast verification documented in `production/qa/`
- [ ] DatabaseService removed from autoloads
- [ ] No S1 or S2 bugs introduced in delivered features
- [ ] Smoke check passed

> ⚠️ **No QA Plan yet**: Run `/qa-plan sprint` before starting implementation. The Production → Polish gate requires a QA sign-off report, which requires a QA plan.

---

## QA Test Cases (back-filled from /qa-plan 2026-05-21)

**Full QA plan**: `production/qa/qa-plan-sprint-1-2026-05-21.md`

### S1-01 — Integration | `tests/integration/persistence/save_load_test.gd`
- `save_to_disk()` writes to `.tmp` then renames (atomic pattern)
- `savegame.bak` created before every save
- `load_or_create()` fallback chain: primary → bak → defaults
- Corrupt primary JSON → bak used (no crash)
- Both files corrupt → defaults returned (no crash)

### S1-02 + S1-12 — Integration | `tests/integration/autoload/init_order_test.gd`
- `ContentService.content` non-empty when `AppState._ready()` runs
- Task targets non-zero after startup
- App launches without DatabaseService after S1-12

### S1-03 — Logic | `tests/unit/persistence/checksum_test.gd`
- Checksum = `JSON.stringify(save_data).hash()` (32-bit int, not character count)
- Import rejects tampered backup (checksum mismatch)

### S1-04 — Logic | `tests/unit/growth/streak_test.gd`
- Consecutive day: `streak_days += 1`
- 2+ day gap: `streak_days = 1`
- Same day: error returned, streak unchanged
- First sign-in (empty `last_sign_in`): `streak_days = 1`, no gap calc
- `weekly_progress` resets on ISO week boundary
- **Dec 28 → Jan 3 edge case REQUIRED** (ADR-0009 explicit)
- `roundi()` used, not `int()` (0.9999... → 1)

### S1-05 — Integration | `tests/integration/growth/sign_in_reward_test.gd`
- `mark_sign_in()` calls `_apply_reward()`, not direct exp mutation
- `_check_level_up()` while-loop: 2+ level-ups in one sign-in handled
- EXP carry-over preserved after level-up
- `weekly_progress` capped at 100

### S1-06 — Logic | `tests/unit/practice/session_state_test.gd`
- ⚠️ Write tests BEFORE refactoring PracticeScreen.gd
- All 7 transitions: IDLE→LOADING, LOADING→ACTIVE, LOADING→IDLE (0 wrong), ACTIVE→EVALUATING, EVALUATING→ACTIVE, EVALUATING→FINISHED, FINISHED→IDLE
- `start_session()` re-entry guard (non-IDLE → silently ignored)
- `_finish_session()` double-execution guard

### S1-07 — Integration | `tests/integration/navigation/nav_disable_test.gd`
- Nav tabs disabled after `start_session()`; re-enabled after `session_finished` and `back_requested`
- Manual: tap nav during session → no navigation

### S1-08 — Visual/Feel | Manual only
- Measure `Color(0.31, 0.36, 0.62)` contrast ratio; document in `production/qa/contrast-check-2026-05-21.md`
- Measure orange button label contrast
- Fix any values below 4.5:1

### S1-10 — Integration | `tests/integration/audio/audio_gate_test.gd`
- `_init_audio_player(invalid_path)` returns null (no crash)
- `_play_sound(null)` is no-op
- `sound_enabled == false` → no playback
- Rapid calls → no stacking (stop before play)
