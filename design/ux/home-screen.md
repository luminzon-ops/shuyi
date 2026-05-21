# UX Spec: HomeScreen

> **Status**: In Review
> **Author**: ux-designer
> **Last Updated**: 2026-05-21
> **Journey Phase(s)**: Hub / Return Loop — primary navigation and progress overview screen
> **Template**: UX Spec

---

## Purpose & Player Need

HomeScreen is the app's hub and the screen students see most often. It serves two simultaneous needs: **start practicing** (the primary action — get into a session quickly) and **see progress** (level, EXP, gold, streak — the reward for yesterday's work). The screen must make the primary action immediately obvious while giving progress information enough prominence to feel motivating. A student who opens the app and sees their level went up should feel rewarded before they even start today's session.

Secondary purpose: provide shortcuts to all major destinations (sign-in, growth, achievements, wrong book, practice modes) so the student never needs to hunt through the bottom nav for common actions.

---

## Player Context on Arrival

Students arrive at HomeScreen in three contexts: **app launch** (fresh, motivated — ready to start), **post-session return** (satisfied or determined — just finished practice), and **navigation return** (browsing — came back from Growth/Sign-in/etc.). The design should feel welcoming in all three states.

On app launch, the student's first glance should answer: "Where am I? What's my progress? What should I do?" — in that order. The HeroCard (banner image + progress summary + mascot + primary action buttons) serves all three questions at once.

Students arrive voluntarily in all cases. The app never forces navigation to HomeScreen.

---

## Navigation Position

HomeScreen is the root of the app's navigation hierarchy — the default screen on launch and the destination for most back-button presses. It is always reachable via the bottom nav Home tab.

Navigation hierarchy: `App root → Home tab` (primary) | App launch default

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Context |
|---|---|---|
| App launch | App opens | First screen seen; no prior state |
| Bottom nav Home tab | Tap Home tab | From any main screen |
| ResultScreen | Tap "返回主页" | After session completion |
| GrowthScreen | Tap back | After viewing growth |
| SignInScreen | Tap back | After signing in |
| WrongBookScreen | Tap back | After viewing wrong book |
| MiniGameScreen | Tap back | After mini-game |

Note: AchievementScreen back-navigates to GrowthScreen, not HomeScreen (per ui-navigation.md).

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| PracticeScreen | Tap "开始学习" (primary button) | Starts level mode with most recent level (`start_session_requested` signal) |
| PracticeScreen | Tap "专项练习" | Starts special_practice mode |
| PracticeScreen | Tap "随机练习" | Starts random_practice mode |
| PracticeScreen | Tap "模拟测试" | Starts mock_test mode |
| SignInScreen | Tap "签到" quick link | `open_sign_in_requested` signal |
| GrowthScreen | Tap "成长" quick link | `open_growth_requested` signal |
| AchievementScreen | Tap "成就中心" | `open_achievements_requested` signal |
| WrongBookScreen | Tap "错题本" | `open_wrong_book_requested` signal |

---

## Layout Specification

### Information Hierarchy

Priority order (most → least important):

1. **Primary action** ("开始学习" button in HeroCard) — the most important tap; must be immediately visible on arrival
2. **Progress summary** (level, EXP, gold, streak in HeroCard) — motivating context; seen alongside the action
3. **Quick links** (签到, 成长 in HeroCard) — high-frequency secondary actions
4. **Study content selector** (StudyCard: grade/module/knowledge dropdowns + level list + mode buttons) — deliberate mode selection
5. **Secondary shortcuts** (SecondaryCard: 成就中心, 错题本) — lowest priority; for occasional access

### Layout Zones

Three-card vertical scroll layout (matches current implementation):

```
[HeroCard]
  - Banner image (TextureRect)
  - HeroInfoRow:
      - TextColumn (greeting, growth stats, weekly stats, helper text)
      - MascotCard (96×96 mascot image)
  - ActionRow:
      - SignInButton (full-width primary "开始学习")
      - QuickLinkRow: [签到] [成长]

[StudyCard]
  - StudyTitle ("选择学习内容")
  - GradeOption / ModuleOption / KnowledgeOption (cascading dropdowns)
  - LevelList (filtered ItemList)
  - ModeButtons: [专项练习] [随机练习] [模拟测试]

[SecondaryCard]
  - SecondaryTitle ("更多入口")
  - AchievementsButton ("成就中心")
  - WrongBookButton ("错题本")
```

The three cards stack vertically inside a ScrollContainer; content below the fold is reachable by scrolling.

### Component Inventory

| Zone | Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|---|
| HeroCard | HeroBanner | TextureRect | Hero banner image (176px tall) | No | — |
| HeroCard | SummaryLabel | Label | "开始今天的数学冒险" (greeting) | No | — |
| HeroCard | GrowthLabel | Label | "等级 Lv.N · EXP N · 金币 N" | No | — |
| HeroCard | WeeklyLabel | Label | "连续签到 N 天 · 学习时长 N 分钟" | No | — |
| HeroCard | HelperLabel | Label | Helper / hint text | No | — |
| HeroCard | MascotCard | PanelContainer + TextureRect | Mascot avatar (96×96) | No | — |
| HeroCard | SignInButton | Button | "开始学习" (full-width primary, orange) | Yes | P-09 (52dp height) |
| HeroCard | StartLevelButton | Button | "签到" (quick link) | Yes | P-09 (48dp) |
| HeroCard | GrowthButton | Button | "成长" (quick link) | Yes | P-09 (48dp) |
| StudyCard | StudyTitle | Label | "选择学习内容" | No | — |
| StudyCard | GradeOption | OptionButton | Grade dropdown (年级 1–6) | Yes | — |
| StudyCard | ModuleOption | OptionButton | Module dropdown (filtered by grade) | Yes | — |
| StudyCard | KnowledgeOption | OptionButton | Knowledge point dropdown | Yes | — |
| StudyCard | LevelList | ItemList | Filtered level list (168px min height) | Yes | — |
| StudyCard | SpecialPracticeButton | Button | "专项练习" | Yes | P-09 (48dp) |
| StudyCard | RandomPracticeButton | Button | "随机练习" | Yes | P-09 (48dp) |
| StudyCard | MockTestButton | Button | "模拟测试" | Yes | P-09 (48dp) |
| SecondaryCard | SecondaryTitle | Label | "更多入口" | No | — |
| SecondaryCard | AchievementsButton | Button | "成就中心" | Yes | P-09 (48dp) |
| SecondaryCard | WrongBookButton | Button | "错题本" | Yes | P-09 (48dp) |

**Naming note**: `SignInButton` carries the "开始学习" primary action label, and `StartLevelButton` carries the "签到" label. The node names do not match their labels — see Open Questions for the rename plan.

### ASCII Wireframe

```
┌─────────────────────────────────┐
│ ┌─ HeroCard ──────────────────┐ │
│ │ [Hero banner image]         │ │
│ │                             │ │
│ │ 开始今天的数学冒险            │ │
│ │ 等级 Lv.3 · EXP 250 · 金币   │ │  [Mascot]
│ │ 连续签到 5 天 · 学习时长 45  │ │  [ 96×96  ]
│ │ 只保留最重要的入口...        │ │
│ │                             │ │
│ │ [        开始学习          ]│ │
│ │ [   签到   ] [   成长     ] │ │
│ └─────────────────────────────┘ │
│ ┌─ StudyCard ─────────────────┐ │
│ │ 选择学习内容                 │ │
│ │ [年级 ▼]                    │ │
│ │ [模块 ▼]                    │ │
│ │ [知识点 ▼]                  │ │
│ │ ┌──────────────────────────┐│ │
│ │ │第1关 加法入门             ││ │
│ │ │第2关 加法进阶             ││ │
│ │ │第3关 减法入门             ││ │
│ │ └──────────────────────────┘│ │
│ │ [    专项练习            ]  │ │
│ │ [    随机练习            ]  │ │
│ │ [    模拟测试            ]  │ │
│ └─────────────────────────────┘ │
│ ┌─ SecondaryCard ─────────────┐ │
│ │ 更多入口                     │ │
│ │ [    成就中心            ]  │ │
│ │ [    错题本              ]  │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What Changes |
|---|---|---|
| **Default** | Normal load / `refresh_view()` called | All data populated from AppState |
| **First launch** | No save data (new student) | Level = 1, EXP = 0, gold = 0, streak = 0; greeting text may be adjusted to welcome new student |
| **Today already signed in** | `AppState.last_sign_in == today` | StartLevelButton (签到) label changes to "已签到" and is disabled (grayed out) |
| **No wrong questions** | `AppState.wrong_question_ids` is empty | WrongBookButton remains visible and tappable; WrongBookScreen handles the empty state (P-10) |
| **Level list empty** | No levels match current grade/module/knowledge filter combination | LevelList shows empty state message: "该筛选条件下暂无关卡" |

**Loading state**: Not required. ContentService loads synchronously at app startup (per ui-navigation.md), so dropdowns and level data are available immediately when HomeScreen is shown. AppState is also synchronously available via the autoload pattern.

---

## Interaction Map

Input method: **Touch-only** (Android). No gamepad, no keyboard.

| Component | Touch Action | Immediate Feedback | Outcome |
|---|---|---|---|
| SignInButton ("开始学习" primary) | Tap | Visual press state | Emits `start_session_requested({mode: "level", level_id: recent_level_id})` |
| StartLevelButton ("签到" quick link) | Tap | Visual press state | Emits `open_sign_in_requested` |
| GrowthButton | Tap | Visual press state | Emits `open_growth_requested` |
| AchievementsButton | Tap | Visual press state | Emits `open_achievements_requested` |
| WrongBookButton | Tap | Visual press state | Emits `open_wrong_book_requested` |
| GradeOption | Tap | Dropdown opens | Filters ModuleOption and LevelList |
| ModuleOption | Tap | Dropdown opens | Filters KnowledgeOption and LevelList |
| KnowledgeOption | Tap | Dropdown opens | Filters LevelList |
| LevelList item | Tap | Item highlights | Emits `start_session_requested({mode: "level", level_id: selected_level_id})` |
| SpecialPracticeButton | Tap | Visual press state | Emits `start_session_requested({mode: "special_practice", grade_id, knowledge_point_id from current filters})` |
| RandomPracticeButton | Tap | Visual press state | Emits `start_session_requested({mode: "random_practice"})` |
| MockTestButton | Tap | Visual press state | Emits `start_session_requested({mode: "mock_test", grade_id from current filter})` |

---

## Events Fired

| Player Action | Event / Side Effect | Payload / Data |
|---|---|---|
| SignInButton tapped (开始学习) | `start_session_requested` signal | `{mode: "level", level_id: recent_level_id}` |
| LevelList item tapped | `start_session_requested` signal | `{mode: "level", level_id: selected_level_id}` |
| SpecialPracticeButton tapped | `start_session_requested` signal | `{mode: "special_practice", grade_id, knowledge_point_id}` |
| RandomPracticeButton tapped | `start_session_requested` signal | `{mode: "random_practice"}` |
| MockTestButton tapped | `start_session_requested` signal | `{mode: "mock_test", grade_id}` |
| StartLevelButton tapped (签到) | `open_sign_in_requested` signal | — |
| GrowthButton tapped | `open_growth_requested` signal | — |
| AchievementsButton tapped | `open_achievements_requested` signal | — |
| WrongBookButton tapped | `open_wrong_book_requested` signal | — |
| Grade/Module/Knowledge filter changed | Internal state change only | LevelList re-filtered; no signal emitted |

HomeScreen does not write to AppState directly. All state changes happen in PracticeScreen or the destination screens.

---

## Transitions & Animations

**Screen enter/exit**: Instant visibility toggle (ADR-0005 — no transition animations).

**In-screen state changes**:

| Moment | Animation | Duration |
|---|---|---|
| `refresh_view()` called | Progress labels update instantly | — |
| SignInButton → "已签到" state | Button dims and label changes instantly | — |
| Grade/Module filter change | LevelList updates instantly | — |

No micro-animations on HomeScreen — it is a navigation hub, not an activity screen. Instant updates are appropriate here.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Player level, EXP, gold | AppState (profile) | Read | Displayed in GrowthLabel |
| Streak days, study minutes | AppState (profile) | Read | Displayed in WeeklyLabel |
| Recent level ID | AppState | Read | Used by StartButton to start most recent level |
| Today's sign-in status | AppState (`last_sign_in`) | Read | Controls SignInButton enabled/disabled state |
| Grade list | ContentService | Read | Populates GradeOption dropdown |
| Module list (filtered by grade) | ContentService | Read | Populates ModuleOption dropdown |
| Knowledge point list (filtered by module) | ContentService | Read | Populates KnowledgeOption dropdown |
| Filtered level list | ContentService | Read | Populates LevelList based on current filter selections |

HomeScreen is **read-only** — it reads from AppState and ContentService but writes nothing. All state changes are delegated to destination screens.

---

## Accessibility

Target tier: **WCAG 2.1 AA** (per `design/accessibility-requirements.md`). Platform: touch-only Android.

### Touch Target Sizes (P-09)

| Component | Required | Implementation | Status |
|---|---|---|---|
| SignInButton ("开始学习") | 48×48 dp min | `custom_minimum_size = Vector2(0, 52)` | ✓ Compliant |
| StartLevelButton ("签到") | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| GrowthButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| AchievementsButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Fixed (was 46px) |
| WrongBookButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Fixed (was 46px) |
| SpecialPracticeButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| RandomPracticeButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| MockTestButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| GradeOption / ModuleOption / KnowledgeOption | 48×48 dp min | Default OptionButton height | ⚠ Verify in Godot 4.6 |
| LevelList items | 48×48 dp min | Default ItemList item height | ⚠ Verify — may need `fixed_item_height` |

### Text Contrast

| Element | Color | Required | Status |
|---|---|---|---|
| SummaryLabel | `Color(0.12, 0.11, 0.29)` (dark navy) | ≥4.5:1 | ✓ Likely compliant |
| GrowthLabel / WeeklyLabel | `Color(0.31, 0.36, 0.62)` (medium blue) | ≥4.5:1 | ⚠ Verify — borderline |
| HelperLabel | `Color(0.43, 0.47, 0.69)` (lighter blue) | ≥4.5:1 | ⚠ Verify — likely borderline |
| SignInButton label | `Color(1, 0.98, 0.94)` (near-white) on orange | ≥4.5:1 | ⚠ Verify orange background contrast |
| StartLevelButton "已签到" (disabled) | Grayed out | ≥3:1 | ⚠ Verify disabled state contrast |

### Color-Independent States

- StartLevelButton "已签到" state: must change label text, not just color
- LevelList selected item: must use highlight + text indicator, not color alone

### Focus Order (Touch Navigation)

Logical top-to-bottom: HeroBanner → SummaryLabel → GrowthLabel → WeeklyLabel → HelperLabel → MascotCard → SignInButton → StartLevelButton → GrowthButton → StudyTitle → GradeOption → ModuleOption → KnowledgeOption → LevelList → SpecialPracticeButton → RandomPracticeButton → MockTestButton → SecondaryTitle → AchievementsButton → WrongBookButton

### TalkBack (MVP baseline)

- SignInButton: tooltip "开始学习 — 继续最近的关卡"
- StartLevelButton: tooltip "签到 — 每日签到领取奖励"
- GrowthButton: tooltip "成长中心"
- AchievementsButton: tooltip "成就中心"
- WrongBookButton: tooltip "错题本"
- HeroBanner: `tooltip_text` describing the banner image (decorative — can be empty if not informative)
- MascotCard: `tooltip_text` "吉祥物" (decorative)

---

## Localization Considerations

The app is currently Chinese-only. Constraints for future localization:

| Element | Max Chinese Length | Expansion Risk | Notes |
|---|---|---|---|
| SignInButton "开始学习" | 4 chars | HIGH — "Start Learning" is 14 chars | Full-width button; must support text wrapping |
| StartLevelButton "签到" / GrowthButton "成长" | 2 chars | HIGH | Two buttons in QuickLinkRow; expansion will overflow |
| GrowthLabel "等级 Lv.N · EXP N · 金币 N" | ~20 chars | MEDIUM | Number values are dynamic; label must wrap |
| WeeklyLabel "连续签到 N 天 · 学习时长 N 分钟" | ~20 chars | MEDIUM | Same concern |
| HelperLabel "只保留最重要的入口..." | ~20 chars | LOW | Already supports `autowrap_mode = 3` |
| StudyTitle "选择学习内容" / SecondaryTitle "更多入口" | 4–5 chars | LOW | Card headers, full-width |
| Mode buttons (专项练习/随机练习/模拟测试) | 4 chars | MEDIUM | Three full-width buttons stacked vertically — expansion fits |
| AchievementsButton "成就中心" / WrongBookButton "错题本" | 3–4 chars | LOW | Full-width buttons stacked |

**Priority for localization engineer**: SignInButton "开始学习" and the QuickLinkRow (StartLevelButton + GrowthButton, side-by-side) are layout-critical — a 40% text expansion will overflow. Flag these as HIGH PRIORITY if localization is scoped.

---

## Acceptance Criteria

- [ ] HomeScreen loads within 500ms from app launch and displays correct level, EXP, gold, and streak data
- [ ] Tapping "开始学习" (SignInButton) navigates to PracticeScreen in level mode using the most recent level ID
- [ ] Tapping a level in LevelList navigates to PracticeScreen in level mode with the selected level ID
- [ ] When today's sign-in is already done, the 签到 quick link (StartLevelButton) shows "已签到" and is disabled (label change, not just color — WCAG AA color-independence)
- [ ] All interactive elements (SignInButton, quick links, mode buttons, secondary buttons) have touch targets ≥ 48×48 dp
- [ ] Grade/Module/Knowledge dropdowns correctly filter the LevelList (selecting grade 2 shows only grade 2 levels)
- [ ] When no levels match the current filter, LevelList shows "该筛选条件下暂无关卡" empty state
- [ ] `refresh_view()` updates all progress labels (level, EXP, gold, streak) with current AppState data
- [ ] Three-card layout (HeroCard / StudyCard / SecondaryCard) is visible and scrollable on a 720×1280 portrait viewport

---

## Open Questions

1. **Node naming inconsistency**: The node `SignInButton` carries the "开始学习" primary action label, and `StartLevelButton` carries the "签到" quick link label. The signal wiring in `home_screen.gd` is functionally correct, but the node names mislead readers. Recommended renames (low-risk, mechanical):
   - `SignInButton` → `PrimaryStartButton` (carries "开始学习")
   - `StartLevelButton` → `SignInQuickButton` (carries "签到")

   This is a refactor task that should be done before further UI iteration to prevent confusion. Track as a tech-debt or polish-phase item.

2. **OptionButton / ItemList touch target verification**: Godot 4.6 default OptionButton and ItemList item heights may be below 48dp. Verify and set `custom_minimum_size` or `fixed_item_height` as needed.

3. **SignInButton orange contrast**: The orange background (`Color(0.976, 0.451, 0.224)`) with near-white text needs contrast ratio verification. Orange backgrounds are often borderline for WCAG AA.

4. **GrowthLabel / WeeklyLabel / HelperLabel contrast**: Medium-blue and lighter-blue text on the white card background — same concern as PracticeScreen. Verify with a contrast tool. HelperLabel (lighter blue) is most likely to fail.

5. **QuickLinkRow overflow on localization**: Two side-by-side buttons (StartLevelButton + GrowthButton) will overflow with translated text. Consider a vertical stack fallback for non-Chinese locales.

6. **Player journey map**: No `design/player-journey.md` exists. HomeScreen is the most journey-critical screen (it's the hub) — a player journey map would validate the emotional arc assumptions made in Section B.

7. **Wrong_retry mode entry from HomeScreen**: HomeScreen has no direct "错题重练" button — students must go to PracticeScreen's mode selector. Consider adding a wrong_retry shortcut alongside the WrongBookButton in SecondaryCard.

8. **HeroBanner content responsibility**: The banner image (`hero_home_clean_v3.png`) is decorative. Confirm with art-director whether it should change seasonally / by event, or remain static for MVP.
