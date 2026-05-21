# QA Sign-Off Report: Sprint 1

**Date**: 2026-05-21
**QA Lead**: qa-lead (via /team-qa)
**Sprint Goal**: Close ADR migration plan gaps in AppState and PracticeScreen, complete HUD polish items, expand question bank toward 300
**Smoke Check**: `production/qa/smoke-2026-05-21.md` — PASS WITH WARNINGS (62/62 tests passing, exit code 0)
**Manual QA**: User chose to defer all manual test cases (TC-01 through TC-08)

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|---|---|---|---|---|
| S1-01 Atomic write + shadow backup | Integration | `save_load_test.gd` (8 cases) — PASS | Not executed (TC-06/07/08 deferred) | PASS (auto) |
| S1-02 Fix autoload order | Integration | `init_order_test.gd` (4 cases) — PASS | Not executed | PASS (auto) |
| S1-03 Backup checksum upgrade | Logic | `checksum_test.gd` (5 cases) — PASS | Not executed | PASS (auto) |
| S1-04 Streak reset + ISO week | Logic | `streak_test.gd` (19 cases) — PASS | Not executed | PASS (auto) |
| S1-05 mark_sign_in() → _apply_reward() | Integration | `sign_in_reward_test.gd` (8 cases) — PASS | Not executed | PASS (auto) |
| S1-06 SessionState enum + _transition() | Logic | `session_state_test.gd` (14 cases) — PASS | Not executed | PASS (auto) |
| S1-07 _set_nav_enabled() | Integration | `nav_disable_test.gd` (3 cases) — PASS | TC-01/02/03 deferred | PARTIAL — logic verified, UI behavior unconfirmed |
| S1-08 Contrast verification | Visual/Feel | Not automatable | TC-04/05 deferred | PARTIAL — `contrast-check-2026-05-21.md` exists; visual sign-off not confirmed |
| S1-12 Remove DatabaseService | Integration | `init_order_test.gd` (shared) — PASS | Not executed | PASS (auto) |
| S1-13 Feedback color palette | Config/Data | Docs only — `design/ux/hud.md` | Not executed | PASS (expected — advisory gate) |

**Note**: S1-09 (question bank +50), S1-10 (audio refactor), S1-11 (register P-11) are Should Have stories remaining in backlog. Out of scope for this sign-off.

---

## Bugs Found During Smoke Check

All 5 bugs were found during the smoke check run on 2026-05-21 and fixed in-session. **No S1 or S2 bugs remain open at the time of this report.**

| ID | Story | Description | Severity | Status |
|---|---|---|---|---|
| BUG-001 | S1-04 | `Time.get_datetime_dict_from_datetime_string()` called with 1 arg; Godot 4.6 requires 2 — AppState failed to load, app could not start | S1 — Critical | Fixed |
| BUG-002 | S1-01/03/04/05/06/07 | All 7 sprint test files used `extends GutTest` (GUT framework); project uses GdUnit4 — tests never compiled | S1 — Critical | Fixed |
| BUG-003 | S1-06/01/03 | GdUnit4 hook naming: `before_each`/`after_each` used instead of `before_test`/`after_test` — 14 tests failed with Nil assignment errors | S2 — Major | Fixed |
| BUG-004 | S1-04 | `streak_test.gd` asserted Dec 28, 2026 is ISO week 1 of 2027; correct value is week 53 of 2026 — test was wrong, implementation was correct | S3 — Minor | Fixed |
| BUG-005 | S1-03 | `BackupService` ZIP roundtrip checksum mismatch: `temp_file` not closed before read; hash computed over pre-roundtrip string, not post-roundtrip form | S2 — Major | Fixed |

---

## Verdict: **APPROVED WITH CONDITIONS**

### Basis for approval
- All 10 Must Have stories marked `done` in `production/sprint-status.yaml`
- 62/62 automated tests pass with exit code 0
- Headless boot check passes — app reaches main scene with zero runtime errors
- All 5 bugs found during smoke check were fixed in-session; no S1 or S2 bugs open
- All Logic and Integration stories have passing automated test evidence (hard gate satisfied)
- Advisory gates (Visual/Feel, Config/Data) have supporting documentation

### Condition — manual QA deferred

The following 8 manual test cases were written by qa-tester but not executed. The user chose to defer them. This sprint **cannot be considered fully validated** until they are run and pass:

| Test Case | Story | What It Verifies |
|---|---|---|
| TC-01 | S1-07 | Tap bottom nav during active session — no navigation occurs |
| TC-02 | S1-07 | Complete session — nav tabs become tappable again |
| TC-03 | S1-07 | Tap back during session — nav re-enables, HomeScreen shown |
| TC-04 | S1-08 | Orange button label visually legible (dark navy on orange) |
| TC-05 | S1-08 | Contrast doc exists and records correct pre/post-fix ratios |
| TC-06 | General | App launches to HomeScreen without crash on device/editor |
| TC-07 | General | Full practice session: start → 10 questions → ResultScreen with correct accuracy/stars |
| TC-08 | General | Sign-in flow: streak increments, EXP awarded, level-up fires if threshold met |

TC-01 through TC-03 are advisory (Integration story S1-07 has passing automated coverage for the logic path). TC-04 and TC-05 are advisory (Visual/Feel gate). TC-06 through TC-08 are general smoke — the headless boot check provides partial confidence, but UI rendering and full session flow on a real device or editor run are not yet confirmed.

---

## Lessons Learned (for Sprint 2 process)

Two S1 bugs (BUG-001, BUG-002) and one S2 bug (BUG-005) would have been caught at story-done time if the test suite had been run as part of the Definition of Done. **File existence is not test evidence — a passing run is.** The Sprint 2 Definition of Done must include "run the test suite and confirm exit code 0" as a blocking step before any story is marked Complete.

---

## Next Steps

1. **Run TC-01 through TC-08** on device or in the Godot editor. Record results in `production/qa/evidence/`.
2. **If all 8 pass**: update this report's verdict to APPROVED (no conditions) and close the sprint.
3. **If any fail**: file a bug report via `/bug-report` and triage severity before proceeding.
4. **Sprint 2 prep**: schedule the first playtest session (flagged in the QA plan — no playtest evidence exists for the v0.9.1 build).
5. **Process improvement**: Sprint 2 story-done checklist must include a mandatory test run step to prevent BUG-001/002/005 class recurrence.
