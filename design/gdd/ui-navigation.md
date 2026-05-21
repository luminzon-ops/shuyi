---
status: reverse-documented
source: shuyi_playland/scripts/core/app.gd + scenes/App.tscn
date: 2026-05-18
verified-by: user
---

# UI and Navigation Design

## Overview

The app uses a ScreenHolder pattern where all screens are instantiated at startup as invisible children, and navigation switches visibility between them. The `app.gd` controller manages all screen lifecycle, signal routing, and title bar updates. This is a single-scene architecture — no scene tree transitions.

## Player Fantasy

Students move fluidly between screens — home, practice, growth, settings — without loading screens or context loss. Every screen remembers its state when revisited.

## Detailed Rules

### Screen Architecture

**Container**: `App.tscn` with a `ScreenHolder` (Control node) named `%ScreenHolder`
**Title bar**: `%TitleLabel` and `%SubtitleLabel` update on every navigation
**Bottom nav**: 5 buttons — Home, Practice, Growth, Mini-game, Settings

**Screens (all pre-loaded in `_ready()`)**:

| Screen | Scene | Title | Subtitle |
|--------|-------|-------|----------|
| Home | HomeScreen.tscn | 数一游园 | 任务、成长与学习入口 |
| Practice | PracticeScreen.tscn | 练习与闯关 | 专项练习、随机练习、测试与错题重练 |
| Growth | GrowthScreen.tscn | 成长中心 | 等级、任务、签到与成就 |
| Sign-in | SignInScreen.tscn | 签到中心 | 连续签到和每日奖励 |
| Achievements | AchievementScreen.tscn | 成就中心 | 勋章与成长奖励 |
| Wrong Book | WrongBookScreen.tscn | 错题本 | 按知识点整理薄弱题目 |
| Result | ResultScreen.tscn | 结算页 / 小游戏结算 | 星级、奖励与下一步建议 |
| Mini-game | MiniGameScreen.tscn | 数学小游戏 | 收集金币并快速答题 |
| Settings | SettingsScreen.tscn | 设置中心 | 音效、动画、护眼与备份 |

### Navigation Flow

All navigation goes through `app.gd`:

**From Home:**
- Practice button → opens practice with most recent level
- Growth button → Growth screen
- Mini-game button → Mini-game screen
- Settings button → Settings screen
- Home card signals → Growth, Sign-in, Wrong Book, Achievements

**From Practice:**
- Session finished → Result screen (with summary data)
- Back → Home screen

**From Result:**
- Back home → Home
- Retry → Practice screen with same session config

**From Growth:**
- Back → Home
- Sign-in link → Sign-in screen
- Achievements link → Achievements screen

**From Achievements:**
- Back → Growth (not Home)

**From Sign-in / Wrong Book / Mini-game:**
- Back → Home

### Screen Switching Mechanism

`_show_screen(screen, title, subtitle)`:
1. Hide all children of ScreenHolder (`child.visible = child == screen`)
2. Update title label and subtitle label
3. Call `screen.refresh_view()` if the screen has that method

This means only one screen is visible at a time, and screens can refresh their data when navigated to.

### Signal Routing

All inter-screen communication flows through `app.gd`:
- Home signals (open_growth_requested, open_sign_in_requested, etc.) → navigate to target screen
- Practice signals (back_requested, session_finished) → navigate or show result
- Result signals (back_home_requested, retry_requested) → navigate back or restart practice
- Growth signals (back_requested, open_sign_in_requested, open_achievements_requested) → navigate

No screen directly references another screen — all routing is mediated by `app.gd`.

### Click Sound

Navigation buttons play an optional click sound (`Accept6.wav`) if:
- Sound is enabled in settings
- The audio file exists (runtime check, not compile-time dependency)

## Formulas

- No calculation formulas — navigation is pure state switching
- Sound is gated by: `AppState.get_settings().get("sound_enabled", true) and ResourceLoader.exists(click_sound_path)`

## Edge Cases

- **No recent level**: If `AppState.get_recent_level_id()` is empty, defaults to `"level_grade1_addition_1"`
- **Missing click sound**: `click_player` is `null`, so navigation continues silently
- **Screen without refresh_view**: `screen.has_method("refresh_view")` check prevents crash
- **Retry with no session config**: Result screen stores `retry_config` from the last session; if missing, retry button does nothing

## Dependencies

- AppState (settings, recent level, wrong book data)
- ContentService (question fetching for session start)
- BackupService (export/import from settings screen)

## Tuning Knobs

| Knob | Current Value | Location |
|------|---------------|----------|
| Click sound file | `res://assets/Audio/Sounds/Menu/Accept6.wav` | `app.gd` (hardcoded) |
| Default level ID | `level_grade1_addition_1` | `app.gd` (hardcoded) |
| Viewport size | 720×1280 | `project.godot` |
| Stretch mode | canvas_items, expand | `project.godot` |
| Screen orientation | portrait (1) | `project.godot` |

## Acceptance Criteria

- [ ] All 9 screens load and display correctly
- [ ] Bottom navigation switches between Home, Practice, Growth, Mini-game, Settings
- [ ] Home screen shortcut buttons navigate to correct screens
- [ ] Practice session finishes and navigates to result screen with correct data
- [ ] Result screen retry navigates back to practice with correct session config
- [ ] Back buttons navigate to the correct parent screen (not always home)
- [ ] Click sound plays on navigation when enabled, is silent when disabled or file missing
- [ ] Screen switching hides all other screens and shows only the target
- [ ] `refresh_view()` is called on screen entry when available