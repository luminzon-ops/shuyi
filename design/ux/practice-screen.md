# UX Spec: PracticeScreen

> **Status**: In Review
> **Author**: ux-designer
> **Last Updated**: 2026-05-20
> **Journey Phase(s)**: Core Loop — primary activity screen
> **Template**: UX Spec

---

## Purpose & Player Need

PracticeScreen is the app's core activity screen. Its single purpose is to present math questions one at a time and collect the student's answers. The player arrives wanting to **do math and see progress** — whether following the level path, drilling a topic, or reviewing mistakes. The screen must make answering feel effortless: the question is clear, the input method matches the question type, and submitting feels immediate. If this screen is slow, confusing, or frustrating, the entire app fails its purpose.

The five session modes (level, special_practice, random_practice, mock_test, wrong_retry) share this same purpose. Mode context is surfaced as a label, not a structural change.

---

## Player Context on Arrival

Students arrive at PracticeScreen voluntarily — from the bottom nav Practice tab, from HomeScreen's level shortcut, or from ResultScreen's retry button. On arrival, the screen immediately shows the session context (mode label + level/topic name) and the first question. The student's emotional state is generally motivated and ready; the design should reinforce this with a clear, uncluttered layout that says "here's your question, go."

Students arriving via wrong_retry may feel anxious about revisiting mistakes — the mode label ("错题重练") should be matter-of-fact, not alarming. Students arriving via retry from ResultScreen are in a determined state — the session should restart without friction.

The screen is never entered without a valid session config. If `start_session()` is called without questions, the screen shows an empty state (see States & Variants).

---

## Navigation Position

PracticeScreen is a top-level destination accessible via the bottom navigation bar (Practice tab). It is also reachable from HomeScreen via the level shortcut (opens in level mode with the most recent level) and from ResultScreen via the retry button (restores the previous session config).

Navigation hierarchy: `App → Practice tab` (primary) | `App → Home → level shortcut` | `App → Result → retry`

The bottom nav Practice tab is always visible on this screen, but tapping it while a session is in progress raises an open question (see Open Questions — tab behavior during active session).

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Bottom nav Practice tab | Tap Practice tab | No session config — screen shows mode selector |
| HomeScreen level shortcut | Tap level card/button | `config: {mode: "level", level_id: recent_level_id}` — skips mode selector, starts session directly |
| ResultScreen retry button | Tap "再来一次" | `config: retry_config` (same mode + level_id as previous session) — skips mode selector |

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| ResultScreen | Session completes (all questions answered) | Automatic — `session_finished(summary)` signal routed by `app.gd` |
| HomeScreen | Tap "返回首页" back button | Abandons in-progress session; partial session progress is not saved |

### Sub-states

PracticeScreen has two distinct sub-states:
- **Mode Selector** — shown when no session config is provided (bottom nav entry). Student picks a mode to start.
- **Active Session** — shown after `start_session(config)` is called. Presents questions one at a time.

---

## Layout Specification

### Information Hierarchy

Priority order (most → least important during active session):

1. **Question text** — the student's entire focus; must be largest and most prominent element
2. **Answer input** — options (P-03/P-05) or text field (P-04); the action the student takes
3. **Feedback** — correct/incorrect indicator shown after submission (P-11)
4. **Submit / Next button** — the action trigger; always reachable without scrolling
5. **Progress** (N/10) — orientation; glanceable, not decision-making
6. **Mode/level label** — context; glanceable
7. **Back button** — escape hatch; accessible but not prominent

### Layout Zones

Option A — top-to-bottom linear (matches current implementation):

```
[Back button] [Mode/Level label]   ← Top bar
[Progress: N/10]  [Mode name]      ← Progress strip
[                              ]
[   Question Card              ]   ← Dominant zone (question + input + feedback)
[                              ]
[Submit button] [Next button]      ← Action bar
```

### Component Inventory

| Zone | Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|---|
| Top bar | BackButton | Button | "返回首页" | Yes | P-09 (min 48×48 dp) |
| Top bar | LevelLabel | Label | Mode name + level/topic name | No | — |
| Progress strip | ProgressLabel | Label | "第 N / 10 题" | No | — |
| Progress strip | ModeLabel | Label | Mode display name (e.g. "关卡闯关") | No | — |
| Question card | QuestionLabel | RichTextLabel | Question text (BBCode-enabled) | No | — |
| Question card | OptionContainer | VBoxContainer | Option buttons (dynamically generated) | Yes | P-03 (choice/true_false), P-05 (matching/sorting) |
| Question card | AnswerInput | LineEdit | Free-text answer field | Yes | P-04 (fill_blank/mental_math/application/multi_step) |
| Question card | FeedbackLabel | RichTextLabel | Correct/incorrect feedback after submission | No | P-11 (new — see Open Questions) |
| Action bar | SubmitButton | Button | "提交答案" | Yes | P-09 |
| Action bar | NextButton | Button | "下一题" | Yes | P-09 |

**New pattern flagged**: P-11 Answer Feedback Display — the correct/incorrect visual state (icon + color + text) shown in FeedbackLabel after submission. To be added to `design/ux/interaction-patterns.md`.

### ASCII Wireframe

**Active session — choice question (P-03):**

```
┌─────────────────────────────────┐
│ [← 返回首页]  关卡闯关 · 第1关  │
│ 第 3 / 10 题                    │
│                                 │
│ ┌─────────────────────────────┐ │
│ │  下面哪个算式是正确的？      │ │
│ │                             │ │
│ │  [A. 3 + 4 = 8            ] │ │
│ │  [B. 5 + 2 = 7  ✓ selected] │ │
│ │  [C. 6 + 1 = 6            ] │ │
│ │  [D. 2 + 5 = 6            ] │ │
│ │                             │ │
│ │  ✓ 回答正确！               │ │
│ └─────────────────────────────┘ │
│                                 │
│ [    提交答案    ] [  下一题  ]  │
└─────────────────────────────────┘
```

**Active session — fill-blank question (P-04):**

```
┌─────────────────────────────────┐
│ [← 返回首页]  专项练习 · 加法   │
│ 第 5 / 10 题                    │
│                                 │
│ ┌─────────────────────────────┐ │
│ │  计算：25 + 37 = ___        │ │
│ │                             │ │
│ │  [输入答案_______________]  │ │
│ │                             │ │
│ │  ✗ 答案是 62               │ │
│ └─────────────────────────────┘ │
│                                 │
│ [    提交答案    ] [  下一题  ]  │
└─────────────────────────────────┘
```

---

## States & Variants

| State | Trigger | What Changes |
|---|---|---|
| **Mode Selector** | Bottom nav entry (no session config) | Question card hidden; 5 mode selection cards shown instead |
| **Active Session — Default** | `start_session(config)` called | Question card visible; progress shown; FeedbackLabel hidden; SubmitButton visible, NextButton hidden |
| **Active Session — Post-Submit** | Student taps SubmitButton | FeedbackLabel visible (correct/incorrect); SubmitButton hidden; NextButton visible |
| **Active Session — Last Question** | Question index = total - 1, post-submit | NextButton label = "完成" (not "下一题") |
| **Empty — No Wrong Questions** | wrong_retry mode, 0 wrong questions available | Question card replaced with empty state message: "暂无错题，继续练习吧！" (P-10) |
| **Session Complete** | All questions answered, NextButton tapped on last question | `session_finished(summary)` signal emitted; `app.gd` navigates to ResultScreen — no visible state on PracticeScreen |

### Mode Selector Layout

When no session config is provided, PracticeScreen shows a mode selection view:

| Mode Card | Label | Description |
|---|---|---|
| level | 关卡闯关 | 按关卡顺序练习 |
| special_practice | 专项练习 | 选择年级/模块/知识点 |
| random_practice | 随机练习 | 随机混合题目 |
| mock_test | 模拟测试 | 模拟考试题目 |
| wrong_retry | 错题重练 | 复习做错的题目 |

Tapping a mode card calls `start_session(config)` with the appropriate mode. For `level` mode, the most recent level is used. For `special_practice`, a filter selector may be needed (open question — see Open Questions).

---

## Interaction Map

Input method: **Touch-only** (Android). No gamepad. Android soft keyboard for text input (P-04).

| Component | Touch Action | Immediate Feedback | Outcome |
|---|---|---|---|
| BackButton | Tap | Visual press state | Emits `back_requested` → `app.gd` navigates to HomeScreen; in-progress session abandoned (no partial save) |
| Mode card (selector state) | Tap | Visual press state | Calls `start_session(config)` for selected mode; transitions to Active Session state |
| Option button — P-03 (choice/true_false) | Tap | Tapped button highlights; other options dim | Sets `selected_option`; SubmitButton enabled |
| Option button — P-05 (matching/sorting/drag_drop) | Tap | Button marked as selected | Appends button value to AnswerInput with `>` separator; SubmitButton enabled when at least one selection made |
| AnswerInput — P-04 (fill_blank/mental_math/application/multi_step) | Tap | Android soft keyboard opens | Allows text entry; SubmitButton enabled when input is non-empty |
| SubmitButton | Tap | Visual press state | Evaluates answer via `ContentService.evaluate_answer()`; records result via `AppState.record_answer()`; shows FeedbackLabel (P-11); hides SubmitButton; shows NextButton |
| NextButton | Tap | Visual press state | If not last question: advances to next question, resets input state. If last question: calls `_finish_session()`, emits `session_finished(summary)` |

---

## Events Fired

| Player Action | Event / Side Effect | Payload / Data |
|---|---|---|
| Mode card tapped | Internal state change only | — |
| Answer submitted (correct) | `AppState.record_answer(question_id, true, user_answer)` | `question_id`, `is_correct: true`, `user_answer` |
| Answer submitted (wrong) | `AppState.record_answer()` + `AppState._record_wrong_question()` | `question_id`, `is_correct: false`, `user_answer` |
| Answer submitted (either) | `AppState._evaluate_achievements()` called internally | Achievement progress updated as side effect |
| Session completed | `session_finished(summary)` signal emitted | `summary`: mode, correct_count, total_count, stars, reward (exp + gold) |
| Back button tapped | `back_requested` signal emitted | — |

**Architectural note**: Achievement evaluation is a side effect of `AppState.record_answer()` and `complete_session()`, not a direct UI event. The UI does not need to trigger it explicitly.

---

## Transitions & Animations

**Screen enter/exit**: Instant visibility toggle (no transition animation — ADR-0005 single-scene architecture constraint).

**In-screen micro-animations** (subtle, non-blocking):

| Moment | Animation | Duration | Notes |
|---|---|---|---|
| Screen enter | None — question appears immediately | — | ADR-0005 constraint |
| Answer submitted — correct | FeedbackLabel fades in with green tint; correct option button pulses green briefly | ~200ms | Must not delay NextButton appearance |
| Answer submitted — wrong | FeedbackLabel fades in with red tint; wrong option dims; correct option highlighted | ~200ms | Show correct answer to aid learning |
| Next question | Question card content updates instantly; option buttons regenerate; FeedbackLabel fades out | ~100ms | No slide animation — instant content swap |
| Session complete | None on PracticeScreen — ResultScreen handles celebration | — | `session_finished` signal triggers navigation |

**Reduced-motion**: MVP does not implement a reduced-motion mode (deferred to v1.1 per accessibility-requirements.md). Animations are brief enough (≤200ms) that they are unlikely to cause discomfort.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Question list for session | ContentService | Read | Fetched once at `start_session()` via mode-specific method |
| Question text, options, correct answer | ContentService (question data) | Read | Rendered by QuestionRenderer |
| Answer evaluation result | ContentService.evaluate_answer() | Read | Returns bool; called per submission |
| Answer record | AppState.record_answer() | Write | Persists answer history (capped at 200 entries) |
| Wrong question record | AppState._record_wrong_question() | Write | Adds to wrong book on incorrect answer |
| Session completion data | AppState.complete_session() | Write | Updates EXP, gold, task progress, achievement evaluation |
| Recent level ID | AppState.get_recent_level_id() | Read | Used as default level in level mode |
| Wrong question IDs | AppState.get_wrong_question_ids_for_retry() | Read | Used to fetch questions for wrong_retry mode |

**Data ownership**: PracticeScreen does not own any game state. It reads from ContentService and delegates all writes to AppState. The screen is stateless between sessions — all session state is held in local variables and discarded when the session ends or the screen is navigated away from.

---

## Accessibility

Target tier: **WCAG 2.1 AA** (per `design/accessibility-requirements.md`). Platform: touch-only Android.

### Touch Target Sizes (P-09)

| Component | Required | Implementation | Status |
|---|---|---|---|
| BackButton | 48×48 dp min | `custom_minimum_size = Vector2(48, 48)` | ✓ Fixed (was 40px) |
| SubmitButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| NextButton | 48×48 dp min | `custom_minimum_size = Vector2(0, 48)` | ✓ Compliant |
| Option buttons (P-03/P-05) | 48×48 dp min | Must set `custom_minimum_size` on generated buttons | ⚠ Verify in QuestionRenderer |

### Text Contrast

| Element | Color | Background | Required | Status |
|---|---|---|---|---|
| QuestionLabel | `Color(0.12, 0.11, 0.29)` (dark navy) | White card | ≥4.5:1 | ✓ Likely compliant — verify with tool |
| ProgressLabel / ModeLabel | `Color(0.31, 0.36, 0.62)` (medium blue) | App background | ≥4.5:1 | ⚠ Verify — medium blue may be borderline |
| FeedbackLabel | Green/red tint | White card | ≥4.5:1 | ⚠ Must verify feedback colors |

### Color-Independent Feedback (P-11)

Correct/incorrect feedback must use icon + text alongside color — never color alone:
- Correct: green tint + "✓ 回答正确！" text
- Wrong: red tint + "✗ 答案是 [correct_answer]" text

### Font Sizes

| Element | Required | Notes |
|---|---|---|
| QuestionLabel | ≥16sp | Core content — must be clearly readable |
| Option button text | ≥14sp | Set on dynamically generated buttons |
| ProgressLabel / ModeLabel | ≥14sp | Secondary info |

### Focus Order (Touch Navigation)

Logical top-to-bottom order: BackButton → ProgressLabel → QuestionLabel → OptionContainer / AnswerInput → SubmitButton / NextButton

### TalkBack (MVP baseline)

All interactive elements must have `tooltip_text`:
- BackButton: "返回首页"
- SubmitButton: "提交答案"
- NextButton: "下一题" / "完成"
- Option buttons: button label text (auto-set from button text)

---

## Localization Considerations

The app is currently Chinese-only. These constraints apply if localization is added in future:

| Element | Max Chinese Length | Expansion Risk | Notes |
|---|---|---|---|
| SubmitButton "提交答案" | 4 chars | HIGH — English "Submit Answer" is 13 chars | Button must support text wrapping or auto-shrink |
| NextButton "下一题" / "完成" | 3 chars | HIGH | Same concern as SubmitButton |
| ProgressLabel "第 N / 10 题" | ~10 chars | MEDIUM | Number format is locale-specific |
| Mode labels (关卡闯关 etc.) | 4–5 chars | MEDIUM | Short strings, low risk |
| Question text | Variable | LOW | Math content is largely language-neutral; Chinese punctuation (，、（）) normalized in evaluation |
| FeedbackLabel "✓ 回答正确！" | ~7 chars | MEDIUM | Feedback text must remain brief |

**Priority for localization engineer**: SubmitButton and NextButton labels are layout-critical — a 40% text expansion would overflow the action bar. Flag these as HIGH PRIORITY if localization is scoped.

---

## Acceptance Criteria

- [ ] PracticeScreen opens within 500ms from any entry point (bottom nav, HomeScreen shortcut, ResultScreen retry)
- [ ] All 5 session modes start correctly: level, special_practice, random_practice, mock_test, wrong_retry each present 10 questions (or fewer for wrong_retry when <10 wrong answers exist)
- [ ] Tapping BackButton during an active session navigates to HomeScreen and does not save partial session progress
- [ ] After submitting an answer, FeedbackLabel shows a correct (✓) or incorrect (✗) indicator with text — not color alone (WCAG AA color-independence requirement)
- [ ] Wrong_retry mode with 0 wrong questions shows the empty state message "暂无错题，继续练习吧！" instead of a question card
- [ ] All interactive elements (BackButton, option buttons, SubmitButton, NextButton) have touch targets ≥ 48×48 dp (verify with Android developer options "Show touch areas")
- [ ] Session completes and navigates to ResultScreen with correct summary data (mode, correct_count, total_count, stars, reward)
- [ ] SubmitButton is visible and NextButton is hidden at question start; after submission, SubmitButton is hidden and NextButton is visible
- [ ] On the last question, NextButton label reads "完成" (not "下一题")

---

## Open Questions

1. **Bottom nav tab behavior during active session**: Should tapping a bottom nav tab while a session is in progress be blocked (to prevent accidental session abandonment), or allowed (with a confirmation dialog)? Currently unspecified in the GDD. See also: interaction-patterns.md P-01 note.

2. **Special_practice mode filter selector**: When the student selects "专项练习" from the mode selector, they need to choose a grade/module/knowledge point. Is this filter UI part of PracticeScreen, or a separate screen? Not currently implemented.

3. **P-11 Answer Feedback Display**: This pattern (correct/incorrect visual state in FeedbackLabel) is used by this screen but not yet in the interaction pattern library. Add to `design/ux/interaction-patterns.md` before implementation.

4. **ProgressLabel contrast verification**: `Color(0.31, 0.36, 0.62)` on the app background needs contrast ratio verification with a tool. May be borderline for WCAG AA 4.5:1.

5. **Option button minimum_size in QuestionRenderer**: Dynamically generated option buttons must have `custom_minimum_size = Vector2(0, 48)` set in `question_renderer.gd`. Verify this is implemented.

6. **Wrong_retry mode — "完成" vs "下一题" on last question**: Confirm the last-question NextButton label change is implemented in `practice_screen.gd`.

7. **Player journey map**: No `design/player-journey.md` exists. This spec was designed without it. Consider creating a player journey map to validate the emotional arc assumptions made in Section B.
