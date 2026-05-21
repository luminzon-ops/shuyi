---
status: reverse-documented
source: shuyi_playland/autoload/AppState.gd + data/content/growth_rules.json + task_rules.json + reward_rules.json
date: 2026-05-18
verified-by: user
---

# Growth System Design

## Overview

The growth system wraps math practice with progression mechanics: leveling (EXP), currency (gold), daily sign-in, daily/weekly tasks, and achievements. It transforms practice from isolated exercises into a continuous journey with visible progress.

## Player Fantasy

Every question answered, every level completed, every day signed in — it all counts. The student sees their level go up, their gold accumulate, and their streak grow. The growth system makes practice feel like an ongoing adventure, not a series of disconnected quizzes.

## Detailed Rules

### Leveling (EXP)

- Students earn EXP from: completing levels, signing in, claiming tasks, claiming achievements
- **Level completion EXP**: 25 EXP + 18 gold (default, from `reward_rules.json` `default_level_reward`; individual levels may override via `levels.json` reward field)
- **Level-up formula**: `while exp >= level * level_up_curve_base: exp -= level * curve_base; level += 1`
- `level_up_curve_base` = 100 (from `growth_rules.json`)
- Level-up check runs after every EXP gain (sign-in, session completion, task claim, achievement claim)
- EXP carries over after level-up — it does NOT reset to 0

### Currency (Gold)

- Students earn gold from the same sources as EXP
- Gold has no upper cap currently
- Gold has no spending mechanic yet (future: unlock cosmetics, hints, etc.)

### Sign-In (Daily Check-in)

- Students can sign in once per day (`last_sign_in != today` check)
- On sign-in:
  - `streak_days += 1`
  - `exp += sign_in_exp` (10)
  - `gold += sign_in_gold` (15)
  - Level-up check runs
  - Weekly progress increments by `sign_in_exp`
- **Design note**: If a day is missed, `streak_days` should reset to 0 (intended behavior, not yet implemented — current code only increments, never resets)

### Tasks (Daily and Weekly)

**Daily tasks** (from `task_rules.json` daily group):

| Task ID | Label | Target | EXP | Gold |
|---------|-------|--------|-----|------|
| complete_level | 完成1个关卡 | 1 | 10 | 8 |
| correct_questions | 答对10道题 | 10 | 12 | 10 |
| special_practice | 完成1次专项练习 | 1 | 10 | 6 |
| mini_game_clear | 完成1次小游戏 | 1 | 12 | 12 |

**Weekly tasks** (from `task_rules.json` weekly group):

| Task ID | Label | Target | EXP | Gold |
|---------|-------|--------|-----|------|
| complete_levels | 完成5个关卡 | 5 | 40 | 30 |
| earn_exp | 累计获得120经验 | 120 | 35 | 20 |
| wrong_retry_clear | 完成2次错题重练 | 2 | 25 | 18 |

- Task progress increments via `_update_task_progress()` after relevant actions
- Progress is capped at target (`min(progress + amount, target)`)
- Completed tasks can be claimed individually, which calls `_apply_reward()` and marks `claimed = true`
- Daily tasks reset logic is not yet implemented (tasks persist in save_data)
- Weekly progress is tracked in `profile.weekly_progress`, capped at 100

### Achievements (3 awards — MVP scope)

| ID | Title | Condition | EXP | Gold |
|----|-------|-----------|-----|------|
| ach_complete_3_levels | 初级闯关家 | Complete 3 levels | 30 | 20 |
| ach_sign_in_3_days | 坚持签到星 | Sign in 3 days consecutively | 20 | 18 |
| ach_correct_50_questions | 答题小能手 | Correctly answer 50 questions | 40 | 25 |

- Achievement progress is evaluated after every answer (in `record_answer()`) and every session completion (in `complete_session()`)
- When progress >= target, achievement unlocks
- Unlocked achievements can be claimed for EXP + gold rewards
- Claimed rewards come from `growth_rules.json` achievement_rewards array

### Weekly Progress

- `profile.weekly_progress` increments by EXP earned, capped at 100
- This is a **display-only percentage tracker** for the weekly goal progress bar in the UI
- **Important**: `profile.weekly_progress` is NOT the counter used by the `earn_exp` weekly task. The `earn_exp` task uses a separate counter in `save_data.tasks.weekly.earn_exp.progress`, which is uncapped and can reach the task target of 120. These are two independent values.

## Formulas

- **Level-up**: `level_up when exp >= current_level * 100`; excess EXP carries over
- **Sign-in reward**: `exp += 10, gold += 15`
- **Session reward**: varies by mode (see reward_rules.json and Tuning Knobs below)
- **Task progress cap**: `min(current_progress + amount, target)`
- **Weekly progress cap**: `min(current_progress + exp_earned, 100)`
- **Answer history cap**: `200 entries max`

## Edge Cases

- **Level-up at exactly threshold**: `exp == level * 100` → level-up triggers, exp becomes 0
- **Multiple level-ups in one session**: While loop handles this correctly
- **Claim already-claimed task**: Returns error message, no double reward
- **Claim locked achievement**: Returns error, cannot claim until unlocked
- **Sign-in twice on same day**: Returns error "今天已经签到过啦"
- **Task progress exceeding target**: Capped at target value

## Dependencies

- ContentService (growth rules, task rules, achievement definitions, reward rules)
- PracticeScreen (triggers session completion → reward application)
- App.gd (navigation to growth, sign-in, achievement screens)

## Tuning Knobs

| Knob | Current Value | File | Adjustable? |
|------|---------------|------|-------------|
| Level-up curve base | 100 | `growth_rules.json` | Yes — JSON |
| Sign-in EXP | 10 | `growth_rules.json` | Yes — JSON |
| Sign-in gold | 15 | `growth_rules.json` | Yes — JSON |
| Practice bonus EXP | 8 | `growth_rules.json` | Yes — JSON |
| Mini-game bonus EXP | 18 | `growth_rules.json` | Yes — JSON |
| Default level reward | 25 EXP / 18 gold | `reward_rules.json` | Yes — JSON |
| Mock test reward | 50 EXP / 36 gold | `reward_rules.json` | Yes — JSON |
| Random practice reward | 16 EXP / 10 gold | `reward_rules.json` | Yes — JSON |
| Mini-game reward | 18 EXP / 15 gold | `reward_rules.json` | Yes — JSON |
| 2-star threshold | 80% | `star_rules.json` | Yes — JSON |
| 3-star threshold | 95% | `star_rules.json` | Yes — JSON |
| Daily/weekly task targets | varies | `task_rules.json` | Yes — JSON |

## Acceptance Criteria

- [ ] Sign-in awards correct EXP and gold values
- [ ] Double sign-in prevention works (same day)
- [ ] **[TR-growth-006]** Streak days increment on sign-in when consecutive; reset to 1 on missed day (gap > 1 day); first-ever sign-in sets streak to 1
- [ ] Task progress increments correctly for each trigger action
- [ ] Task progress is capped at target
- [ ] **[TR-growth-007]** Level-up triggers when `exp >= level * 100` after every EXP gain from any source; excess EXP carries over; multiple level-ups in one reward are handled by while loop
- [ ] Achievement progress evaluates correctly after answers and sessions
- [ ] All three achievements unlock at the correct threshold
- [ ] Claimed tasks and achievements cannot be claimed again
- [ ] **[TR-growth-008]** `weekly_progress` increments by EXP earned and is capped at 100; resets to 0 on the first sign-in after an ISO week boundary (Monday)