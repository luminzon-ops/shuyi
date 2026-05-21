# ADR-0009: Growth Progression Engine

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: MINOR NOTES (incorporated) 2026-05-19
> **TD-ADR Review**: APPROVE (2 required fixes applied) 2026-05-19
>
> **As-built vs. intended**: `_update_streak_and_weekly()` and streak-reset logic are **not yet implemented** in shipping code (`AppState.gd` only increments `streak_days`, never resets it). `mark_sign_in()` currently mutates `profile["exp"]` directly rather than routing through `_apply_reward()`. The Migration Plan below is the implementation contract. This ADR documents the intended architecture, not the current state.

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (progression logic, state management) |
| **Knowledge Risk** | LOW — pure GDScript arithmetic and Dictionary mutation; no post-cutoff APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Time.get_date_string_from_system()` — stable across all Godot 4.x versions |
| **Verification Required** | (1) Verify `Time.get_unix_time_from_datetime_string(date + "T00:00:00")` returns a valid Unix timestamp on Android for date-only strings with appended time component. (2) Verify `roundi()` on the 86400-division result correctly identifies a 1-day gap as `1` (not `0`) on Android. (3) Verify `_get_iso_week()` returns the correct week number for Dec 28 and Jan 3 boundary dates. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — AppState owns save_data; all progression state lives in save_data.profile), ADR-0003 (Autoload Singleton Pattern — AppState is the autoload that owns this engine), ADR-0007 (Wrong-Book and Achievement Evaluation Pipeline — _apply_reward() is the shared reward application method that triggers level-up; this ADR documents its level-up behaviour) |
| **Enables** | None — this is a leaf ADR for the growth system |
| **Blocks** | Any story implementing streak reset, level-up logic, or weekly progress reset |
| **Ordering Note** | Must be Accepted before growth-system stories covering TR-growth-006/007/008 can be marked Ready |

## Context

### Problem Statement
Three growth mechanics are partially or not yet implemented in `AppState.gd` with no architectural contract:

1. **Streak reset on missed day** (TR-growth-006): The GDD specifies that `streak_days` resets to 0 if a day is missed, but the current code only increments `streak_days` and never resets it. There is no defined trigger site, date-comparison strategy, or edge-case handling.

2. **Level-up check after every EXP gain** (TR-growth-007): `_apply_reward()` calls `_check_level_up()` after every EXP gain, but the trigger contract — which methods must call `_apply_reward()`, and what the while-loop formula guarantees — is undocumented at the ADR level.

3. **Weekly progress reset** (TR-growth-008): `profile.weekly_progress` is capped at 100 but never resets. The GDD implies a weekly cadence but does not specify when the reset occurs or how the week boundary is detected.

Without an architectural contract, these mechanics cannot be tested in isolation, and the streak/weekly reset logic cannot be safely implemented without risking regressions in the sign-in flow.

### Constraints
- **GDScript-only**: No C# or GDExtension (ADR-0002)
- **AppState owns all mutable player state**: Progression state lives in `save_data.profile` (ADR-0001)
- **Offline-first**: No server-side date validation; all date logic uses the device clock
- **Android target**: `Time.get_date_string_from_system()` must be verified to return consistent ISO 8601 strings on Android
- **ContentService provides growth rules**: `level_up_curve_base`, sign-in rewards, and task targets come from JSON config files (ADR-0004)

### Requirements
- Must reset `streak_days` to 1 when a sign-in occurs after a gap of more than 1 day (TR-growth-006)
- Must continue `streak_days` (increment by 1) when a sign-in occurs exactly 1 day after the last sign-in (TR-growth-006)
- Must run a level-up check after every EXP gain from any source (TR-growth-007)
- Must carry over excess EXP after level-up (TR-growth-007)
- Must reset `weekly_progress` to 0 at the start of each ISO week (Monday boundary) (TR-growth-008)
- Must cap `weekly_progress` at 100 within a week (TR-growth-008)
- All three mechanics must be testable as private methods callable in isolation

## Decision

### All Three Mechanics as Private Methods in AppState

Consistent with the pattern established in ADR-0007, all three mechanics are implemented as private methods in `AppState.gd`. No new autoload or node is introduced.

```gdscript
# Called from mark_sign_in() — handles streak continuation, reset, and weekly reset
func _update_streak_and_weekly(today: String) -> void

# Called from _apply_reward() after every exp gain — handles level-up with carry-over
func _check_level_up() -> void

# Called from _update_streak_and_weekly() — detects ISO week boundary
func _get_iso_week(date_string: String) -> int
```

**Why private methods in AppState (not a separate autoload)**:
- Progression state lives entirely in `save_data.profile` (ADR-0001); a separate autoload would need to read and write AppState's data, creating cross-autoload coupling
- The pattern is identical to ADR-0007's `_evaluate_achievements_per_answer()` and `_record_wrong_question()` — private methods called from the relevant trigger sites
- All three methods are pure functions over Dictionary data; they are directly callable in unit tests without scene instantiation

---

### Mechanic 1: Streak Reset (TR-growth-006)

**Trigger site**: `AppState.mark_sign_in()` — called once per day when the student taps the sign-in button.

**Algorithm**:
```
today = Time.get_date_string_from_system()   # "YYYY-MM-DD"
last  = save_data.profile.last_sign_in       # "YYYY-MM-DD" or ""

if last == "":
    # First ever sign-in — no gap calculation; avoid passing empty string to Time API
    streak_days = 1
elif days_between(last, today) == 1:
    # Consecutive day — continue streak
    streak_days += 1
elif days_between(last, today) == 0:
    # Same day — idempotent, already handled by the date equality guard in mark_sign_in()
    return error "今天已经签到过啦"
else:
    # Gap of 2+ days — reset streak
    streak_days = 1

save_data.profile.last_sign_in = today
_update_streak_and_weekly(today)
```

**Date arithmetic**: `days_between(a, b)` appends `"T00:00:00"` to each date string before passing to `Time.get_unix_time_from_datetime_string()` — date-only strings may return `-1` on some builds. The difference is divided by `86400.0` and rounded with `roundi()` (not `int()`) to avoid float truncation errors where exactly one day evaluates to `0.9999...`:

```gdscript
func _date_to_unix(date: String) -> float:
    return Time.get_unix_time_from_datetime_string(date + "T00:00:00")

func _days_between(a: String, b: String) -> int:
    return roundi((_date_to_unix(b) - _date_to_unix(a)) / 86400.0)
```

**Weekly reset check** (inside `_update_streak_and_weekly()`):
```
current_week = _get_iso_week(today)
last_week    = _get_iso_week(save_data.profile.last_sign_in)  # before updating

if current_week != last_week:
    save_data.profile.weekly_progress = 0
```

This piggybacks the weekly reset onto the sign-in event. Weekly progress only resets when the student signs in after a week boundary — it does not reset automatically at midnight Monday if the student never opens the app.

**Design rationale for sign-in-triggered weekly reset**: The app is offline-first with no background process. A background reset would require a startup check on every app launch, which adds complexity and a potential regression surface. Tying the reset to sign-in is simpler, consistent with the existing sign-in-as-daily-anchor pattern, and acceptable for an educational app where the weekly goal is motivational rather than competitive.

---

### Mechanic 2: Level-Up After Every EXP Gain (TR-growth-007)

**Trigger site**: `AppState._apply_reward(reward: Dictionary)` — the single method that applies EXP and gold from any source (session completion, task claim, achievement claim, sign-in).

**Algorithm** (`_check_level_up()`):
```
curve_base = ContentService.get_growth_rules().level_up_curve_base  # 100

while save_data.profile.exp >= save_data.profile.level * curve_base:
    save_data.profile.exp   -= save_data.profile.level * curve_base
    save_data.profile.level += 1
```

**Carry-over guarantee**: The while loop (not an if) ensures multiple level-ups in a single reward are handled correctly. EXP is never reset to 0 — only the threshold amount is subtracted.

**Trigger contract**: Every EXP gain MUST go through `_apply_reward()`. Direct mutation of `save_data.profile.exp` outside `_apply_reward()` is forbidden (see Forbidden Patterns below). This ensures `_check_level_up()` is always called after every EXP change.

**Call site map**:

| EXP source | Calls |
|-----------|-------|
| Session completion | `complete_session()` → `_apply_reward()` → `_check_level_up()` |
| Task claim | `claim_task()` → `_apply_reward()` → `_check_level_up()` |
| Achievement claim | `claim_achievement()` → `_apply_reward()` → `_check_level_up()` |
| Sign-in | `mark_sign_in()` → `_apply_reward()` → `_check_level_up()` |

---

### Mechanic 3: Weekly Progress Cap (TR-growth-008)

**State**: `save_data.profile.weekly_progress` — integer 0–100, display-only percentage tracker.

**Increment**: Called from `_apply_reward()` after every EXP gain:
```
save_data.profile.weekly_progress = min(
    save_data.profile.weekly_progress + reward.exp,
    100
)
```

**Reset**: Triggered by `_update_streak_and_weekly()` on sign-in when ISO week changes (see Mechanic 1 above).

**ISO week calculation** (`_get_iso_week(date_string: String) -> int`):
```
# Returns ISO week number (1–53) for a given "YYYY-MM-DD" string.
# NOTE: Time.get_datetime_dict_from_datetime_string() does NOT return a "week" key.
# The dict has: year, month, day, hour, minute, second, weekday, dst.
# ISO week number must be computed manually from year/month/day using the
# standard ISO 8601 algorithm (week 1 = week containing the first Thursday
# of the year; Monday = start of week).
# A tested utility function is required — do not inline ad-hoc arithmetic.
# Year-boundary edge cases (Dec 28–31 may belong to week 1 of the next year)
# must be covered by unit tests.
```

The exact ISO week algorithm is implementation-level detail; the ADR mandates that the method returns the correct ISO 8601 week number and is covered by unit tests for Dec 28 and Jan 3 boundary dates.

---

### Architecture Diagram

```
Any EXP source (session / task / achievement / sign-in)
        │
        │ _apply_reward(reward: Dictionary)
        ▼
AppState._apply_reward()
    ├── save_data.profile.exp   += reward.exp
    ├── save_data.profile.gold  += reward.gold
    ├── weekly_progress = min(weekly_progress + reward.exp, 100)
    └── _check_level_up()
            └── while exp >= level * curve_base:
                    exp   -= level * curve_base
                    level += 1

Student taps Sign-In button
        │
        │ mark_sign_in()
        ▼
AppState.mark_sign_in()
    ├── guard: last_sign_in == today → return error
    ├── _update_streak_and_weekly(today)
    │       ├── days_between(last, today) == 1 → streak_days += 1
    │       ├── days_between(last, today) > 1  → streak_days = 1
    │       └── _get_iso_week(today) != _get_iso_week(last) → weekly_progress = 0
    ├── _apply_reward(sign_in_reward)   [exp + gold + level-up check]
    └── save_to_disk()
```

### Key Interfaces

**AppState (new/modified)**:
- `mark_sign_in() -> Dictionary` — existing; now calls `_update_streak_and_weekly()` before `_apply_reward()`; returns `{ok: bool, message: String}`
- `_apply_reward(reward: Dictionary) -> void` — existing; now explicitly documented as the sole EXP mutation path; calls `_check_level_up()` and increments `weekly_progress`
- `_check_level_up() -> void` — existing (may be implicit); now explicitly defined as a while-loop with carry-over; called only from `_apply_reward()`
- `_update_streak_and_weekly(today: String) -> void` — new or extracted; handles streak continuation/reset and weekly_progress reset on ISO week boundary
- `_get_iso_week(date_string: String) -> int` — new; returns ISO 8601 week number for a date string

**Forbidden pattern added**: Direct mutation of `save_data.profile.exp` outside `_apply_reward()` — see registry update below.

## Alternatives Considered

### Alternative 1: Separate ProgressionEngine Autoload
- **Description**: Extract all progression logic (level-up, streak, weekly progress) into a fifth autoload `ProgressionEngine.gd`. AppState delegates to it for all EXP/streak mutations.
- **Pros**: Single-responsibility principle — progression logic is isolated from persistence logic; independently testable without loading AppState's full save_data schema.
- **Cons**: Adds a fifth autoload to a project that ADR-0003 deliberately limited to four; ProgressionEngine would need read/write access to `save_data.profile`, creating cross-autoload coupling that ADR-0001 and ADR-0003 were designed to avoid; the progression logic is 3 small methods — the abstraction cost exceeds the benefit at this scale.
- **Rejection Reason**: The existing pattern (private methods in AppState, consistent with ADR-0007) achieves the same testability without adding a new autoload or cross-autoload coupling. The scale does not justify a new architectural layer.

### Alternative 2: ContentService-Driven Rules Evaluation
- **Description**: ContentService exposes a `evaluate_progression(profile, event)` pure function that takes the current profile state and an event (sign-in, exp_gain, etc.) and returns the updated profile. AppState applies the result.
- **Pros**: Progression rules are co-located with other game rules in ContentService; pure function is trivially testable; rules can be updated by changing JSON config without touching AppState.
- **Cons**: Progression logic depends on mutable state (current level, current streak) that ContentService is not designed to own — it is a read-only content provider (ADR-0004); passing the full profile Dictionary to ContentService creates a dependency inversion; the while-loop level-up formula is not expressible as a pure JSON config rule without a scripting layer.
- **Rejection Reason**: ContentService is explicitly read-only (ADR-0004). Passing mutable profile state to it violates the established ownership boundary. The level-up formula requires imperative logic (while loop with carry-over) that cannot be driven by JSON config alone.

### Alternative 3: Lazy Startup Check for Streak Reset
- **Description**: On every app launch, `AppState._ready()` compares today's date against `last_sign_in` and resets `streak_days` if the gap is > 1 day, before any user action.
- **Pros**: Streak is always accurate when the app opens, regardless of whether the student signs in; no dependency on the sign-in flow.
- **Cons**: Adds a date comparison to the startup critical path; if the student opens the app but does not sign in, the streak resets silently — the student may not notice until they try to sign in; the sign-in screen is the natural place to surface streak information, so resetting there is more visible and actionable.
- **Rejection Reason**: Tying streak reset to sign-in is simpler (one trigger site), more visible to the student (they see the streak update when they sign in), and consistent with the offline-first pattern of not running background logic. The startup check adds complexity for a marginal UX benefit.

## Consequences

### Positive
- All three mechanics have a single, documented trigger site — no implicit side effects
- `_check_level_up()` is independently testable: call it with a mock `save_data.profile` and assert the resulting level and exp
- `_update_streak_and_weekly()` is independently testable: call it with two date strings and assert streak_days and weekly_progress
- The while-loop carry-over guarantee is explicit — multiple level-ups in one session are handled correctly by design
- Weekly reset is tied to sign-in, consistent with the offline-first constraint — no background process needed

### Negative
- Weekly progress only resets when the student signs in after a week boundary. If the student never signs in during a new week, `weekly_progress` retains its previous value until the next sign-in. This is a known limitation of the sign-in-triggered reset approach.
- ISO week calculation requires a non-trivial date algorithm (`_get_iso_week()`). Year-boundary edge cases (e.g., Dec 28 in week 1 of the next year) must be verified on Android.
- Direct EXP mutation outside `_apply_reward()` is now a forbidden pattern — any existing code that mutates `save_data.profile.exp` directly (including the current `mark_sign_in()`) must be audited and refactored.
- **Behavior change**: Consolidating `weekly_progress` increment into `_apply_reward()` means weekly progress will now increment on task and achievement claims, not only on sign-in. The current implementation only increments `weekly_progress` during sign-in. This is intentional — the GDD states weekly progress tracks EXP earned from all sources — but it is a behavioral change from the shipping code.

### Risks
- **`Time.get_unix_time_from_datetime_string()` with date-only strings**: Passing a `"YYYY-MM-DD"` string without a time component may return `-1` on some Godot builds. Mitigation: always append `"T00:00:00"` before calling this API (see `_date_to_unix()` in the Decision section).
- **Float division truncation in `_days_between()`**: `Time.get_unix_time_from_datetime_string()` returns a `float`. Dividing by `86400.0` and truncating with `int()` could evaluate exactly one day as `0.9999...` → `0`, triggering a false same-day guard. Mitigation: use `roundi()` instead of `int()`.
- **`Time.get_datetime_dict_from_datetime_string()` has no `week` key**: The returned dict contains `year`, `month`, `day`, `weekday`, etc. — no `week` field. `_get_iso_week()` must compute the ISO 8601 week number manually. Mitigation: implement a tested utility function; cover Dec 28 / Jan 3 year-boundary cases in unit tests.
- **Empty `last_sign_in` on first sign-in**: Passing `""` to `_date_to_unix()` would call `Time.get_unix_time_from_datetime_string("T00:00:00")` which returns `-1`. Mitigation: guard at the top of `_update_streak_and_weekly()` — if `last_sign_in == ""`, set `streak_days = 1` and skip gap calculation.
- **Device clock manipulation**: A student who changes their device clock backward could re-trigger sign-in rewards or prevent streak reset. Mitigated by the offline-first constraint — no server-side validation is possible; this is an accepted risk for an educational app.
- **ISO week year-boundary edge case**: `_get_iso_week()` must handle the case where Dec 28–31 belong to week 1 of the following year (ISO 8601 rule). Incorrect handling would cause a spurious weekly reset. Mitigated by the Verification Required field and dedicated unit tests.
- **`Time.get_date_string_from_system()` timezone**: The returned date string reflects the device's local timezone. This is acceptable for an educational app — the streak is based on the student's local day.
- **Regression in `_apply_reward()`**: Adding `_check_level_up()` and `weekly_progress` increment to `_apply_reward()` could break existing callers if `_apply_reward()` was previously called with partial reward Dictionaries (missing `exp` key). Mitigation: ensure `_apply_reward()` defaults missing keys to 0: `reward.get("exp", 0)`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| growth-system.md | Streak reset on missed day (TR-growth-006) | `_update_streak_and_weekly()` computes day gap via Unix timestamp arithmetic; resets `streak_days = 1` if gap > 1 day |
| growth-system.md | Level-up check after every EXP gain (TR-growth-007) | `_apply_reward()` is the sole EXP mutation path; it always calls `_check_level_up()` with while-loop carry-over |
| growth-system.md | Weekly progress capped at 100 (TR-growth-008) | `weekly_progress = min(weekly_progress + reward.exp, 100)` in `_apply_reward()`; resets to 0 on ISO week boundary in `_update_streak_and_weekly()` |

## Performance Implications
- **CPU**: Negligible — date arithmetic (2 Unix timestamp conversions + integer division) and a while loop over a small level range; all sub-millisecond
- **Memory**: No additional state beyond existing `save_data.profile` fields
- **Load Time**: None — all logic is triggered at runtime by user actions
- **Network**: None

## Migration Plan
1. Audit `AppState.gd` for any direct mutations of `save_data.profile.exp` outside `_apply_reward()` — refactor to use `_apply_reward()`. **Specifically**: `mark_sign_in()` currently mutates `profile["exp"]` directly and calls `_apply_level_up()` separately; refactor it to call `_apply_reward(sign_in_reward)` instead.
2. Implement `_date_to_unix(date: String) -> float` that appends `"T00:00:00"` before calling `Time.get_unix_time_from_datetime_string()`
3. Implement `_days_between(a: String, b: String) -> int` using `roundi()` (not `int()`) on the float division result
4. Implement `_get_iso_week(date_string: String) -> int` with a tested ISO 8601 algorithm; cover Dec 28 and Jan 3 boundary dates in unit tests
5. Implement `_update_streak_and_weekly(today: String) -> void` with: empty `last_sign_in` guard (streak = 1, skip gap calc), streak continuation/reset logic, and ISO week boundary check for `weekly_progress` reset
6. Update `mark_sign_in()` to call `_update_streak_and_weekly(today)` before `_apply_reward()`
7. Verify `_apply_reward()` defaults missing reward keys to 0 (`reward.get("exp", 0)`, `reward.get("gold", 0)`)
8. Write unit tests: streak continuation, streak reset, same-day guard, first-ever sign-in, ISO week boundary, level-up carry-over, multiple level-ups, weekly progress cap, weekly progress reset
9. Verify all tests pass on a device (Android) to confirm `Time.get_date_string_from_system()` and `Time.get_unix_time_from_datetime_string()` behaviour

## Validation Criteria
- [ ] Sign-in on consecutive days increments `streak_days` by 1
- [ ] Sign-in after a 2+ day gap resets `streak_days` to 1
- [ ] Sign-in twice on the same day returns an error and does not change `streak_days`
- [ ] `_check_level_up()` triggers when `exp >= level * 100`
- [ ] `_check_level_up()` carries over excess EXP (does not reset to 0)
- [ ] Multiple level-ups in one `_apply_reward()` call are handled correctly (while loop)
- [ ] `weekly_progress` increments by `reward.exp` on every `_apply_reward()` call
- [ ] `weekly_progress` is capped at 100 and does not exceed it
- [ ] `weekly_progress` resets to 0 on the first sign-in after an ISO week boundary
- [ ] `weekly_progress` does NOT reset if sign-in occurs within the same ISO week
- [ ] `_get_iso_week()` returns the correct week number for Dec 28 and Jan 3 boundary dates

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — `save_data.profile` is the state container; `save_to_disk()` is called after every mutation
- ADR-0003 (Autoload Singleton Pattern) — AppState is the autoload that owns this engine; ContentService provides `level_up_curve_base` via `get_growth_rules()`
- ADR-0007 (Wrong-Book and Achievement Evaluation Pipeline) — `_apply_reward()` is the shared reward application method; this ADR documents its level-up and weekly-progress behaviour
