# HUD Design

> **Status**: In Review
> **Author**: ux-designer
> **Last Updated**: 2026-05-21
> **Template**: HUD Design

---

## HUD Philosophy

数一游园's HUD follows an **adaptive density** philosophy: minimal chrome while the student is answering, richer feedback at the moment of submission.

**Core principle**: The question is the experience. Every pixel of persistent chrome that competes with the question text is a distraction. During answering, only orientation information (progress, mode) is visible. After submission, a brief feedback moment surfaces the result and reward — then clears to make way for the next question.

**Three-layer model**:
1. **Persistent chrome** (always visible): Title bar (screen title + subtitle), bottom navigation bar. These orient the student within the app at all times.
2. **Session chrome** (visible during active practice sessions only): Progress indicator (N/10), mode/level label, back button. These orient the student within the current session.
3. **Feedback moment** (visible for ~200ms after submission, then transitions to Next button): Correct/incorrect indicator + EXP earned. This is the motivating payoff — brief, clear, then gone.

**What is NOT in the HUD**: EXP totals, gold totals, level, streak, task progress. These belong on HomeScreen and GrowthScreen — not in the session. Showing them during practice would distract from the math.

---

## Information Architecture

### Full Information Inventory

All information items the app's systems could surface on-screen:

| # | Item | Source System |
|---|------|--------------|
| 1 | Progress indicator (N/10) | PracticeSystem |
| 2 | Session mode name | PracticeSystem |
| 3 | Level/topic name | PracticeSystem |
| 4 | Question text | PracticeSystem (content) |
| 5 | Answer input (options / text field) | PracticeSystem (content) |
| 6 | Correct/incorrect result | PracticeSystem |
| 7 | EXP earned (per question / per session) | GrowthSystem |
| 8 | Gold earned (per question / per session) | GrowthSystem |
| 9 | Stars earned | PracticeSystem / GrowthSystem |
| 10 | Player level | GrowthSystem |
| 11 | EXP total | GrowthSystem |
| 12 | Gold total | GrowthSystem |
| 13 | Streak days | GrowthSystem |
| 14 | Task progress | GrowthSystem |
| 15 | Achievement progress | GrowthSystem |
| 16 | Screen title | UI & Navigation |
| 17 | Screen subtitle | UI & Navigation |
| 18 | Bottom navigation (5 tabs) | UI & Navigation |

### Categorization

| Item | Category | Rationale |
|------|----------|-----------|
| Progress indicator (N/10) | **Must Show** | Students need to know how far through the session they are |
| Session mode name | **Must Show** | Orients the student — "关卡闯关" vs "错题重练" sets expectations |
| Level/topic name | **Must Show** | Confirms what they're practicing |
| Question text | Content (not HUD) | The question is the experience, not chrome |
| Answer input | Content (not HUD) | Same — input is the core interaction |
| Correct/incorrect result | **Contextual** | Appears after submission (~200ms), then transitions to Next button |
| EXP earned | **Contextual** | Animated "+N EXP" float-up after correct answer; no persistent display |
| Gold earned | **Contextual** | Same as EXP — animated float-up only |
| Stars earned | **On Demand** | ResultScreen only — not shown per-question |
| Player level | **Hidden** | HomeScreen / GrowthScreen only — not during sessions |
| EXP total | **Hidden** | Same |
| Gold total | **Hidden** | Same |
| Streak days | **Hidden** | Same |
| Task progress | **Hidden** | GrowthScreen only |
| Achievement progress | **Hidden** | GrowthScreen only |
| Screen title | **Must Show** | Always visible in title bar — orients student within the app |
| Screen subtitle | **Must Show** | Always visible in title bar |
| Bottom navigation | **Must Show** | Always visible on main screens; behavior during sessions is defined in Dynamic Behaviors |

**Philosophy check**: The Must Show list has 5 items (progress, mode, level/topic, screen title, screen subtitle). This is lean — consistent with the adaptive philosophy. No conflict.

---

## Layout Zones

The persistent UI is divided into three zones. All zones respect the 720×1280 portrait viewport with no safe-zone margins required (Android full-screen is not used — the app uses the standard window with system bars).

### Zone 1: Title Bar (top, all screens)

```
┌─────────────────────────────────┐
│ [Screen Title]                  │  ← TitleLabel (font_size ~24)
│ [Screen Subtitle]               │  ← SubtitleLabel (font_size ~14)
└─────────────────────────────────┘
```

- Always visible on all 9 screens
- Updated by `app.gd._show_screen()` on every navigation
- Read-only display — no interactive elements
- Height: ~56dp (two lines of text with padding)

### Zone 2: Session Chrome (PracticeScreen only, during active session)

```
┌─────────────────────────────────┐
│ [← 返回首页]  关卡闯关 · 第1关  │  ← Back button + mode/level label
│ 第 3 / 10 题                    │  ← Progress indicator
└─────────────────────────────────┘
```

- Visible only when PracticeScreen is active and a session is in progress
- Part of PracticeScreen's layout (not a global overlay)
- Back button: 48×48 dp min (P-09)
- Progress label: secondary color, glanceable

### Zone 3: Bottom Navigation (main screens only)

```
┌─────────────────────────────────┐
│ [Home] [Practice] [Growth] [🎮] [⚙] │  ← 5 tabs, equal width
└─────────────────────────────────┘
```

- Visible on: HomeScreen, PracticeScreen (mode selector state), GrowthScreen, MiniGameScreen, SettingsScreen
- Hidden or behavior-defined on: SignInScreen, AchievementScreen, WrongBookScreen, ResultScreen (sub-screens)
- Tab height: ≥56dp (P-09 + icon + label)
- Active tab: highlighted (color + weight change — not color alone, per WCAG AA)

### Feedback Moment (in-card, PracticeScreen only)

Not a separate zone — rendered inside the Question Card as an inline element (FeedbackLabel). Appears after submission, clears on Next tap.

```
│ ┌─────────────────────────────┐ │
│ │  [Question text]            │ │
│ │  [Answer input]             │ │
│ │                             │ │
│ │  ✓ 回答正确！               │ │  ← FeedbackLabel (P-11)
│ └─────────────────────────────┘ │
│  [+12 EXP ↑]                    │  ← EXP float-up animation (Contextual)
```

---

## HUD Elements

### Zone 1: Title Bar

| Element | Category | Visual Form | Content | Update Behavior |
|---------|----------|-------------|---------|-----------------|
| TitleLabel | Must Show | Text label, ~24sp, dark navy | Screen title (e.g., "练习与闯关") | Event-driven — updated on every `_show_screen()` call |
| SubtitleLabel | Must Show | Text label, ~14sp, medium blue | Screen subtitle (e.g., "专项练习、随机练习、测试与错题重练") | Same as TitleLabel |

Animation: None — instant text swap on navigation (ADR-0005).

---

### Zone 2: Session Chrome

| Element | Category | Visual Form | Content | Update Behavior |
|---------|----------|-------------|---------|-----------------|
| BackButton | Must Show | Button, "返回首页", 48×48 dp min | Static label | Static during session |
| LevelLabel | Must Show | Text label, ~24sp | Mode name + level/topic (e.g., "关卡闯关 · 第1关") | Set once at `start_session()` |
| ProgressLabel | Must Show | Text label, ~17sp, medium blue | "第 N / 10 题" | Updated on each `show_question()` call |
| ModeLabel | Must Show | Text label, ~17sp, medium blue | Mode display name (e.g., "关卡闯关") | Set once at `start_session()` |

Animation: ProgressLabel updates instantly (no animation — frequent updates, animation would be distracting).

---

### Zone 3: Bottom Navigation

| Element | Category | Visual Form | Content | Update Behavior |
|---------|----------|-------------|---------|-----------------|
| HomeTab | Must Show | Button, icon + label "首页" | Static | Active state updates on navigation |
| PracticeTab | Must Show | Button, icon + label "练习" | Static | Active state updates on navigation |
| GrowthTab | Must Show | Button, icon + label "成长" | Static | Active state updates on navigation |
| MiniGameTab | Must Show | Button, icon + label "小游戏" | Static | Active state updates on navigation |
| SettingsTab | Must Show | Button, icon + label "设置" | Static | Active state updates on navigation |

Active state: color highlight + font weight change (not color alone — WCAG AA). Inactive tabs: secondary color.

---

### Feedback Moment (Contextual — PracticeScreen)

| Element | Category | Visual Form | Content | Trigger | Duration |
|---------|----------|-------------|---------|---------|----------|
| FeedbackLabel | Contextual | RichTextLabel, BBCode | "✓ 回答正确！" or "✗ 答案是 [correct]" | After SubmitButton tap | Visible until NextButton tap |
| EXP Float-up | Contextual | Animated Label | "+1 EXP" (only on correct answers) | After correct submission | ~800ms fade-up animation, then disappears |

**EXP float-up spec**: Label starts at FeedbackLabel position, translates upward ~40px, fades from full opacity to 0 over 800ms. Uses Godot `Tween`. Gated by P-06 (sound_enabled check does not apply — this is visual, not audio). No float-up on wrong answers (wrong answers should not feel rewarding).

**EXP grain decision** (resolved 2026-05-21, per TD recommendation): EXP is awarded at the **data layer per session** — `AppState.complete_session()` applies the full session reward at the end. The per-correct "+1 EXP" float-up is **UI animation only** — it is visual fanfare that reveals accrued credit progressively, not a real per-answer data write. This preserves the existing growth-progression ADR contract (ADR-0009: all EXP through `_apply_reward()` at session completion) while delivering the motivational feedback moment the HUD philosophy calls for.

### Feedback Color Palette (defined 2026-05-21, S1-13)

All colors verified against white card background (`Color(1, 1, 1)`, L=1.0) using WCAG 2.1 relative luminance formula.

| Role | Color constant | Hex | Luminance | Contrast vs white | Required | Status |
|---|---|---|---|---|---|---|
| **Correct-green** | `Color(0.0, 0.45, 0.20, 1)` | `#007333` | 0.1421 | **5.47:1** | ≥4.5:1 | ✅ PASS |
| **Wrong-red** | `Color(0.80, 0.10, 0.10, 1)` | `#CC1A1A` | 0.1404 | **5.51:1** | ≥4.5:1 | ✅ PASS |
| **EXP-gold** | `Color(0.75, 0.50, 0.0, 1)` | `#BF8000` | 0.2854 | **3.13:1** | ≥3:1 (large text ≥18sp) | ✅ PASS (large text) |

**EXP-gold note**: Gold on white inherently produces low contrast. `Color(0.75, 0.50, 0.0)` achieves 3.13:1, which passes the WCAG AA large-text threshold (≥3:1 for text ≥18sp or ≥14sp bold). The float-up label MUST use ≥18sp to qualify for this threshold. If a smaller font size is used, the color must be darkened further or a dark text stroke added.

**Implementation note**: These colors are defined here as the authoritative source. When implementing FeedbackLabel (S1-06 follow-up) and the EXP float-up animation, use these exact `Color()` values. Do not use BBCode color names (e.g., `[color=lime]`) — use the hex values above for precision.

---

## Dynamic Behaviors

### Bottom Navigation State Changes

| Trigger | Behavior |
|---------|----------|
| `start_session(config)` called | All 5 bottom nav tabs disabled (grayed, non-tappable). Prevents accidental session abandonment. |
| `session_finished(summary)` signal | Bottom nav tabs re-enabled. |
| `back_requested` signal (BackButton) | Bottom nav tabs re-enabled (session abandoned, returning to HomeScreen). |
| Normal screen navigation | Active tab highlights; all other tabs return to inactive state. |

**Implementation note**: `app.gd` must call `_set_nav_enabled(false)` on `start_session()` and `_set_nav_enabled(true)` on session end or back navigation. This resolves PracticeScreen Open Question #1 (bottom nav tab behavior during active session).

---

### Title Bar Updates

| Trigger | Behavior |
|---------|----------|
| Any `_show_screen()` call | TitleLabel and SubtitleLabel update instantly to the new screen's title/subtitle pair. |
| During active session | Title bar shows "练习与闯关" / "专项练习、随机练习、测试与错题重练" — does not update per-question. |

---

### Session Chrome Visibility

| Trigger | Behavior |
|---------|----------|
| PracticeScreen enters Mode Selector state | Session chrome (BackButton, LevelLabel, ProgressLabel, ModeLabel) hidden or shows mode-selector context. |
| `start_session(config)` called | Session chrome becomes visible; LevelLabel and ModeLabel set from config. |
| Each `show_question()` call | ProgressLabel updates to "第 N / 10 题". |
| Session complete | Session chrome remains visible until `app.gd` navigates to ResultScreen. |

---

### Feedback Moment Lifecycle

| Step | Action |
|------|--------|
| 1 | Student taps SubmitButton |
| 2 | Answer evaluated; FeedbackLabel appears (✓ or ✗ + text) |
| 3 | If correct: EXP float-up animation starts (+N EXP, 800ms fade-up) |
| 4 | SubmitButton hides; NextButton appears |
| 5 | Student taps NextButton |
| 6 | FeedbackLabel hides; EXP float-up (if still running) completes or is interrupted |
| 7 | Next question loads; input state resets |

The EXP float-up does NOT block the NextButton. The student can tap Next immediately; the animation completes or is cut off gracefully.

---

## Platform & Input Variants

**Single platform**: Android portrait 720×1280, touch-only. No gamepad, no keyboard, no landscape mode.

| Constraint | Implication |
|---|---|
| Portrait-only | All HUD zones are designed for portrait. No landscape variant needed. |
| Touch-only | All interactive HUD elements (BackButton, nav tabs) must meet P-09 (48×48 dp min). No hover states. |
| No safe-zone margins | App uses standard Android window (not full-screen/edge-to-edge). System status bar and navigation bar are outside the app viewport. No safe-zone insets required. |
| 720×1280 px viewport | Title bar ~56dp, bottom nav ~56dp, leaving ~1168dp for content. At 3x density, 56dp ≈ 168px. |
| Desktop (dev/preview only) | The app runs on desktop for development. HUD behavior is identical — no desktop-specific variant. |

---

## Accessibility

Target tier: **WCAG 2.1 AA** (per `design/accessibility-requirements.md`). Platform: touch-only Android.

### Touch Target Sizes (P-09)

| Element | Required | Notes |
|---|---|---|
| Bottom nav tabs (5) | ≥56×56 dp | Includes icon + label; height ≥56dp per accessibility-requirements.md |
| BackButton (session chrome) | ≥48×48 dp | Fixed in PracticeScreen.tscn (this session) |
| All other HUD elements | Non-interactive | No touch target requirement |

### Text Contrast

| Element | Color | Required | Status |
|---|---|---|---|
| TitleLabel | Dark navy `Color(0.12, 0.11, 0.29)` | ≥4.5:1 | ✓ Compliant (verified S1-08: ~12:1) |
| SubtitleLabel | Medium blue `Color(0.31, 0.36, 0.62)` | ≥4.5:1 | ✓ Compliant (verified S1-08: 5.81:1) |
| ProgressLabel / ModeLabel | Medium blue `Color(0.31, 0.36, 0.62)` | ≥4.5:1 | ✓ Compliant (5.81:1) |
| FeedbackLabel — correct | `Color(0.0, 0.45, 0.20)` (#007333) | ≥4.5:1 on white card | ✓ Defined S1-13: 5.47:1 |
| FeedbackLabel — wrong | `Color(0.80, 0.10, 0.10)` (#CC1A1A) | ≥4.5:1 on white card | ✓ Defined S1-13: 5.51:1 |
| EXP float-up "+1 EXP" | `Color(0.75, 0.50, 0.0)` (#BF8000) | ≥3:1 (large text ≥18sp) | ✓ Defined S1-13: 3.13:1 — must use ≥18sp |
| Bottom nav active tab | Highlighted color | ≥4.5:1 | ⚠ Verify when icons are implemented |
| Bottom nav inactive tab | Secondary color | ≥3:1 (large text) | ⚠ Verify when icons are implemented |

### Color-Independent States

- Bottom nav active tab: must use color + weight/shape change — not color alone
- FeedbackLabel correct/wrong: must use ✓/✗ icon + text — not color alone (P-11)
- EXP float-up: positive-only (correct answers) — no color-coding needed (it only appears on correct)

### Font Sizes

| Element | Required | Notes |
|---|---|---|
| TitleLabel | ≥18sp | Title — large text threshold |
| SubtitleLabel | ≥14sp | Body text minimum |
| ProgressLabel | ≥14sp | Body text minimum |
| ModeLabel | ≥14sp | Body text minimum |
| Bottom nav labels | ≥12sp | Secondary — minimum allowed per accessibility-requirements.md |
| FeedbackLabel | ≥14sp | Must be readable at a glance |
| EXP float-up | ≥14sp | Brief animation — must be legible |

### Motion / Animation

- EXP float-up (800ms): Brief, vertical translation + fade. Unlikely to cause discomfort.
- Reduced-motion mode: Not implemented in MVP (deferred to v1.1 per accessibility-requirements.md). 800ms is within acceptable range.

### TalkBack (MVP baseline)

- Bottom nav tabs: `tooltip_text` = tab name ("首页", "练习", "成长", "小游戏", "设置")
- BackButton: `tooltip_text` = "返回首页"
- TitleLabel / SubtitleLabel: Decorative text — no tooltip needed (content is already readable)

---

## Open Questions

1. **Bottom nav disabled state implementation**: `app.gd` needs a `_set_nav_enabled(bool)` method that disables/enables all 5 bottom nav buttons during active sessions. This resolves PracticeScreen Open Question #1. Assign to a gameplay-programmer story.

2. ~~**EXP float-up color**: The "+N EXP" float-up color is not yet defined.~~ **RESOLVED S1-13**: `Color(0.75, 0.50, 0.0)` (#BF8000), 3.13:1 contrast vs white — passes large-text threshold (≥18sp required). See Feedback Color Palette table above.

3. ~~**EXP amount per question**: The float-up shows "+N EXP" — but EXP is awarded per session (at `complete_session()`), not per question.~~ **RESOLVED 2026-05-21**: Data layer stays per-session (ADR-0009 contract preserved). UI float-up is animation-only showing a fixed motivational value (e.g., "+1 EXP"), not the real session EXP. See HUD Elements → Feedback Moment for full decision.

4. **Bottom nav icons**: The current implementation uses text-only tabs. Icons are referenced in the HUD design but not yet implemented. Assign to art-director for icon design.

5. ~~**SubtitleLabel / ProgressLabel / ModeLabel contrast**: `Color(0.31, 0.36, 0.62)` medium blue — verify.~~ **RESOLVED S1-08**: 5.81:1 — passes 4.5:1. No change needed.

6. ~~**FeedbackLabel green/red colors**: Specific color values not yet defined.~~ **RESOLVED S1-13**: Correct-green `Color(0.0, 0.45, 0.20)` (5.47:1), Wrong-red `Color(0.80, 0.10, 0.10)` (5.51:1). See Feedback Color Palette table above.

7. **P-11 Answer Feedback Display**: This pattern is used by the HUD (FeedbackLabel) but not yet formally registered in `design/ux/interaction-patterns.md`. Add before implementation stories are written.
