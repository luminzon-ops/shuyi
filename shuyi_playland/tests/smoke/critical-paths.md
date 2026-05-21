# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Update**: Add entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. All 9 screens are accessible via bottom navigation without crash
3. Settings screen: sound toggle persists across app restart

## Practice System

4. Start a Level session — 10 questions render and accept answers
5. Session completes and routes to ResultScreen with correct accuracy/stars
6. Wrong answer is recorded in wrong-book; correct answer marks it mastered
7. Wrong-retry session starts with un-mastered questions only

## Growth System

8. Sign-in awards EXP and gold; streak_days increments
9. Signing in twice on the same day shows error (no double reward)
10. EXP gain triggers level-up when threshold is met; excess EXP carries over

## Persistence

11. Save completes without error after a session
12. App restart restores correct profile state (level, EXP, streak)
13. Corrupt primary save falls back to shadow backup without crash

## Audio

14. Click sound plays on navigation when sound_enabled = true
15. Click sound is silent when sound_enabled = false (no crash)

## Performance (device only — not headless)

16. No visible frame drops during a 10-question practice session
17. No crash or ANR during 5 minutes of continuous play

---

> **Note**: Items 16–17 require an Android device. All other items can be
> verified in the Godot editor on desktop.
