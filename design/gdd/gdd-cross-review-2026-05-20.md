# Cross-GDD Review Report

> **Date**: 2026-05-20
> **Verdict**: CONCERNS
> **GDDs Reviewed**: 9 (game-concept, systems-index, content-system, practice-system, question-types, growth-system, persistence-system, ui-navigation, audio-system)
> **Entity Registry**: Empty — consistency checks relied on full GDD reads
> **Phases run**: Full (Phase 2 Consistency + Phase 3 Design Theory + Phase 4 Scenario Walkthrough)

---

## Consistency Issues

### 🔴 Blocking

**C-01: weekly_progress cap (100) vs. earn_exp task target (120)**

- `growth-system.md` Formulas: `profile.weekly_progress` is capped at 100
- `growth-system.md` Weekly Tasks: `earn_exp` target = 120
- If `weekly_progress` is the counter for the `earn_exp` task, the task is permanently unreachable. Neither GDD clarifies whether they share a counter or use separate accumulators in `save_data.tasks`.
- **Required fix**: Clarify in `growth-system.md` whether `earn_exp` uses `profile.weekly_progress` or a separate `tasks.weekly.earn_exp.progress` counter. If shared: raise cap to ≥120 or lower target to ≤100. If separate: document both counters explicitly in both `growth-system.md` and `persistence-system.md`.

**C-02: practice-system.md missing GrowthSystem dependency**

- `practice-system.md` Dependencies: lists ContentService, AppState, QuestionRenderer — GrowthSystem absent
- `growth-system.md` correctly lists PracticeScreen as a dependency
- Achievement evaluation (`_evaluate_achievements()`) crosses a system boundary that is invisible in practice-system.md
- **Required fix**: Add GrowthSystem to `practice-system.md` Dependencies section

### ⚠️ Warnings

**C-03: Dependency asymmetries (4 missing reciprocals)**

- `audio-system.md` → `ui-navigation.md`: audio-system lists ui-navigation as a trigger site; ui-navigation does not list AudioSystem as a dependency
- `audio-system.md` → `growth-system.md`: audio-system lists growth-system as a trigger site; growth-system does not list AudioSystem
- `content-system.md`: does not acknowledge PracticeSystem, GrowthSystem, or UINavigation as consumers

**C-04: reward_rules.json and star_rules.json have no declared owner GDD**

- Both `practice-system.md` and `growth-system.md` reference these files; neither declares ownership
- Recommendation: assign ownership to `growth-system.md`; have `practice-system.md` declare them as consumed dependencies

**C-05: Profile field schema gap**

- `growth-system.md` references `profile.weekly_progress`, `profile.streak_days`, `profile.last_sign_in`
- `persistence-system.md` documents the 8-section schema but does not enumerate fields within sections
- A programmer implementing persistence from persistence-system.md alone would not know these fields exist

**C-06: Achievement evaluation two-step flow undefined**

- `practice-system.md`: "Achievement evaluation runs after every answer AND after every session completion" (implies automatic)
- `growth-system.md`: "EXP sources: claiming achievements" (implies player-initiated)
- Neither GDD defines the two-step flow (auto-evaluate eligibility → player taps to claim)

**C-07: wrong_retry_clear "cleared" condition undefined**

- `growth-system.md` weekly task: `wrong_retry_clear` (target 2)
- `practice-system.md` does not define what constitutes a "cleared" wrong retry session (accuracy threshold? any completion?)

**C-08: Audio feedback ACs absent from practice-system and growth-system**

- `audio-system.md` marks correct/wrong SFX and level-up jingle as planned
- Neither `practice-system.md` nor `growth-system.md` has acceptance criteria gating on audio feedback
- Audio system is orphaned from the acceptance criteria chain

---

## Game Design Issues

### 🔴 Blocking

**D-01: EXP from level completion is unspecified**

- `practice-system.md`: "reward from level or reward_rules.json" — no EXP amount given
- `growth-system.md`: "completing levels" listed as EXP source — no value given
- The `earn_exp` weekly task (target 120 EXP) cannot be validated as achievable through normal play
- The progression curve cannot be balanced or verified
- **Required fix**: Define the EXP reward for level completion in `growth-system.md` Tuning Knobs and cross-reference `reward_rules.json`. The value is likely in `reward_rules.json` already — the GDD just needs to document it.

### ⚠️ Warnings

**D-02: Gold has no sink**

- `growth-system.md` explicitly acknowledges "no spending mechanic yet"
- Gold accumulates indefinitely; Pillar 1 ("earns currency") becomes hollow without a spend path
- Recommendation: add a visible "coming soon" shop placeholder in the UI, or remove gold from the MVP reward display until a sink exists. Document the decision in `growth-system.md`.

**D-03: Stars have no mechanical weight**

- Stars (1★/2★/3★) are awarded but have no downstream effect on EXP, content unlock, tasks, or achievements
- Re-play incentive is purely intrinsic
- Recommendation: document this as an intentional design decision in `practice-system.md` Edge Cases or Tuning Knobs

**D-04: mock_test question pool is undefined**

- `practice-system.md` lists `mock_test` as a session mode but does not specify which questions it draws from
- If it draws from all grades, a grade 1 student could receive grade 6 questions
- **Fix**: Add a "mock_test draws from current grade only" rule to `practice-system.md` Detailed Rules

**D-05: Between-session attention budget at upper boundary for young students**

- 4 active between-session systems (sign-in, daily tasks, achievements, wrong book) is the upper limit for the stated audience (ages 6–12)
- No progressive disclosure schedule is defined
- Recommendation: add a "system reveal order" note to `game-concept.md` or `ui-navigation.md`

**D-06: Fragmented reward cascade across screens**

- Completing a level → Result screen → task/achievement claims require separate navigation to Growth/Achievements screens
- For ages 6–7, the connection between level completion and pending claims is not surfaced
- Recommendation: add a "pending rewards" indicator to the Result screen or Home screen

**D-07: "Level" naming collision**

- "Level" means both a content unit (content-system.md) and a player progression milestone (growth-system.md)
- For grades 1–2 students, this may cause confusion
- Recommendation: verify current UI labels use distinct Chinese terms (e.g., "关卡" for content level, "等级" for player level)

---

## Cross-System Scenario Issues

**Scenarios walked**: 4

**S-01: Level completion → reward cascade** — ⚠️ WARNING

The reward cascade (session EXP → level-up → task/achievement eligibility → player claims) is fragmented across multiple screens with no surfacing mechanism. Students may complete a level and never claim pending task/achievement EXP. No GDD specifies how pending claims are surfaced post-session. The intended "every question answered... it all counts" experience is only felt if the student navigates to claim.

**S-02: Sign-in flow** — ✅ CLEAN (with C-01 caveat)

The sign-in flow is internally consistent. The streak reset gap (designed but not implemented) is documented in the GDD. Subject to C-01 resolution.

**S-03: wrong_retry with 0 wrong answers** — ✅ CLEAN

Defined in both `practice-system.md` and ADR-0006: LOADING → IDLE transition with `session_error("no_wrong_questions")`. Consistent.

**S-04: Task claim → EXP → level-up → achievement in same call** — ⚠️ WARNING

`claim_task()` → `_apply_reward()` → `_check_level_up()` → `_evaluate_achievements()` is a valid chain. However, if claiming a task triggers a level-up that simultaneously unlocks an achievement, the achievement becomes claimable but the student receives no notification. Neither `growth-system.md` nor `practice-system.md` specifies whether `_evaluate_achievements()` is called after `_check_level_up()` within `_apply_reward()`. This is undefined behavior in the GDDs.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| growth-system.md | C-01: weekly_progress cap vs. earn_exp target | Consistency | **Blocking** |
| growth-system.md | D-01: EXP from level completion unspecified | Design | **Blocking** |
| practice-system.md | C-02: missing GrowthSystem dependency | Consistency | **Blocking** |
| practice-system.md | D-04: mock_test question pool undefined | Design | Warning |
| growth-system.md | C-04: reward_rules.json ownership | Consistency | Warning |
| persistence-system.md | C-05: profile field schema gap | Consistency | Warning |
| audio-system.md | C-03: missing reciprocal dependencies | Consistency | Warning |
| ui-navigation.md | C-03: missing AudioSystem dependency | Consistency | Warning |

---

## Verdict: CONCERNS

3 blocking issues exist (C-01, C-02, D-01), all in `growth-system.md` and `practice-system.md`. The architecture document is not invalidated — the ADRs do not depend on specific EXP values or the weekly_progress counter disambiguation. However, these gaps must be resolved before implementation stories can be written for the affected systems.

**Why CONCERNS and not FAIL**: The project is reverse-documented (code exists, docs are being written). The blocking issues are data/formula gaps, not structural contradictions that would require ADR changes. The architecture is sound.

### Required actions before implementation stories for growth-system and practice-system

1. **C-01**: Clarify `weekly_progress` vs. `earn_exp` counter in `growth-system.md`
2. **D-01**: Define EXP reward for level completion in `growth-system.md` Tuning Knobs (check `reward_rules.json` for the actual value)
3. **C-02**: Add GrowthSystem to `practice-system.md` Dependencies section

### Recommended follow-up (warnings)

- C-04: Assign `reward_rules.json` ownership to `growth-system.md`
- C-05: Add profile field list to `persistence-system.md`
- C-06: Document the two-step achievement flow (auto-evaluate → player claims) in both GDDs
- C-07: Define "cleared" condition for `wrong_retry_clear` task in `practice-system.md`
- D-04: Add mock_test grade filter rule to `practice-system.md`
- D-06: Add pending rewards surfacing to UX spec for Result/Home screens
