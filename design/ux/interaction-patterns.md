# Interaction Pattern Library

> **Status**: In Design
> **Author**: ux-designer
> **Last Updated**: 2026-05-20
> **Template**: Interaction Pattern Library

---

## Overview

本库记录数一游园（Shuyi Playland）所有屏幕中使用的交互模式。所有模式均基于以下约束：

- **平台**：Android 竖屏 720×1280，纯触控
- **用户**：小学生（6–12岁），触控操作为主，无键盘/手柄
- **架构**：单场景 ScreenHolder，无页面跳转动画（ADR-0005）

新增 UI 组件时，优先从本库选用已有模式；若需引入新模式，须在本库登记后方可在 UX spec 中引用。

---

## Pattern Catalog

| # | 模式名 | 分类 | 使用屏幕 |
|---|--------|------|---------|
| P-01 | Bottom Tab Navigation | 导航 | 所有主屏幕 |
| P-02 | Screen Visibility Switch | 导航 | 全局（ScreenHolder） |
| P-03 | Option Button Select | 输入 | PracticeScreen（choice / true_false） |
| P-04 | Text Input Answer | 输入 | PracticeScreen（fill_blank / mental_math） |
| P-05 | Sequential Tap Build | 输入 | PracticeScreen（matching / drag_drop / sorting） |
| P-06 | Gated Sound Playback | 反馈 | 全局（导航点击音效） |
| P-07 | Reward Claim Gate | 状态 | GrowthScreen / AchievementScreen |
| P-08 | Session Flow | 流程 | PracticeScreen → ResultScreen |
| P-09 | Touch Target Sizing | 无障碍 | 所有屏幕 |
| P-10 | Empty State Display | 数据展示 | WrongBookScreen / AchievementScreen |

---

## Patterns

### P-01 Bottom Tab Navigation

**Category**: 导航
**Used In**: 所有主屏幕

**Description**: 底部固定 5 个 tab 按钮（Home / Practice / Growth / MiniGame / Settings），始终可见。点击切换主屏幕，当前激活 tab 有视觉高亮，其余 tab 为非激活状态。点击时触发 P-06 音效。

**Specification**:
- 5 个按钮等宽排列，占满底部导航栏
- 当前激活 tab 视觉高亮（颜色/图标变化）
- 点击非当前 tab 触发 P-02 Screen Visibility Switch
- 点击当前激活 tab 无操作（不重复刷新）
- 触控区域满足 P-09 Touch Target Sizing（最小 48×48 dp）

**When to Use**: 在任何主屏幕之间切换时。
**When NOT to Use**: 在子屏幕（SignIn / Achievements / WrongBook / Result）中不显示底部 tab，或 tab 处于禁用状态（如练习进行中）。

---

### P-02 Screen Visibility Switch

**Category**: 导航
**Used In**: 全局（ScreenHolder）

**Description**: 所有 9 个屏幕在启动时预实例化为 ScreenHolder 的子节点，导航时仅切换 `visible` 属性，不销毁或重建节点。进入屏幕时若该屏幕有 `refresh_view()` 方法则调用之。

**Specification**:
- 导航时：隐藏所有子节点，仅显示目标屏幕
- 同步更新顶部 TitleLabel 和 SubtitleLabel
- 若目标屏幕有 `refresh_view()` 方法，调用之以刷新数据
- 无过渡动画（单场景架构约束，ADR-0005）
- 隐藏的屏幕保留其内存状态

**When to Use**: 所有屏幕切换均使用此模式。
**When NOT to Use**: 不适用于弹窗/对话框（应使用 overlay 而非切换屏幕）。

---

### P-03 Option Button Select

**Category**: 输入
**Used In**: PracticeScreen（choice / true_false 题型）

**Description**: 题目选项以 Button 列表呈现，单选。点击即选中，无需额外确认步骤。选中后该按钮高亮，其余选项变灰。

**Specification**:
- 选项按钮动态生成，数量由题目数据决定（choice 通常 4 个，true_false 2 个）
- 点击选项：高亮选中项，其余变灰，记录 `selected_option`
- 选中后显示提交按钮（或自动提交，取决于实现）
- 触控区域满足 P-09（最小 48×48 dp）
- 选项文字超长时自动换行，按钮高度自适应

**When to Use**: 有限选项、单选场景。
**When NOT to Use**: 需要自由输入时使用 P-04；需要排序/组合时使用 P-05。

---

### P-04 Text Input Answer

**Category**: 输入
**Used In**: PracticeScreen（fill_blank / mental_math / application / multi_step 题型）

**Description**: 显示 LineEdit 输入框，隐藏选项按钮区。学生手动输入答案后点击提交。

**Specification**:
- 隐藏选项容器，显示 LineEdit
- Android 软键盘弹出时，输入框保持可见（布局需适配键盘遮挡）
- 数字类题目建议触发数字键盘（`keyboard_type = TYPE_NUMBER`）
- 提交前不做实时验证，仅在提交时评估
- 输入框内容在题目切换时清空

**When to Use**: 需要自由输入答案（数字或文字）的题型。
**When NOT to Use**: 有限选项时使用 P-03；需要构建序列时使用 P-05。

---

### P-05 Sequential Tap Build

**Category**: 输入
**Used In**: PracticeScreen（matching / drag_drop / sorting / shape_puzzle 题型）

**Description**: 同时显示选项按钮区和 LineEdit 答案框。点击选项按钮将其值追加到答案框（以 `>` 分隔），学生通过依次点击构建答案序列。

**Specification**:
- 选项按钮区和 LineEdit 同时可见
- 点击选项按钮：将按钮文字追加到 `answer_input.text`，格式为 `A>B>C`
- 答案框只读（不允许手动编辑，防止格式错误）
- 提供"清除"按钮重置答案框
- 已选中的按钮可视觉标记（防止重复选择）

**When to Use**: 需要排序、配对或组合选项的题型。
**When NOT to Use**: 单选用 P-03；自由输入用 P-04。

---

### P-06 Gated Sound Playback

**Category**: 反馈
**Used In**: 全局（导航点击音效；计划扩展至答题音效、升级音效）

**Description**: 播放音效前检查两个条件：① 设置中 `sound_enabled == true`；② 音频文件在运行时存在。任一条件不满足则静默跳过，不报错、不影响功能。

**Specification**:
- 播放前检查：`AppState.get_settings().get("sound_enabled", true)`
- 播放前检查：`player != null`（文件不存在时 player 为 null）
- 播放时先 `stop()` 再 `play()`，防止快速点击叠音
- 所有 AudioStreamPlayer 在 `app.gd._ready()` 时统一初始化（ADR-0011）
- 音效切换（关闭→开启）在下一次操作时立即生效

**When to Use**: 所有需要音效反馈的交互。
**When NOT to Use**: 不适用于背景音乐（MVP 不实现）。

---

### P-07 Reward Claim Gate

**Category**: 状态
**Used In**: GrowthScreen（任务领取）/ AchievementScreen（成就领取）

**Description**: 奖励解锁后不自动发放，需学生主动点击"领取"按钮。AppState 层双重防重复：已解锁 + 未领取才允许领取。

**Specification**:
- 未解锁：按钮禁用或不显示
- 已解锁未领取：按钮激活，显示"领取"
- 点击领取：调用 `AppState.claim_task()` 或 `claim_achievement()`，AppState 验证后发放奖励
- 已领取：按钮变灰或显示"已领取"，不可再次点击
- 领取成功后触发 `state_changed` 信号，UI 自动刷新

**When to Use**: 所有需要主动领取的奖励场景。
**When NOT to Use**: 不适用于自动发放的奖励（如答题即时 EXP，无需点击）。

---

### P-08 Session Flow

**Category**: 流程
**Used In**: PracticeScreen → ResultScreen

**Description**: 完整练习会话的端到端流程，从启动到结算。

**Specification**:
- `start_session(config)` 接收 mode、level_id 等参数，拉取题目
- 逐题展示：根据题型选用 P-03 / P-04 / P-05
- 每题提交后立即评估，记录结果，不显示对错（继续下一题）
- 全部题目完成后计算结果（accuracy / stars / reward）
- 发出 `session_finished(summary)` 信号，由 `app.gd` 导航至 ResultScreen
- ResultScreen 展示结算数据，提供"再来一次"和"返回主页"

**When to Use**: 所有 6 种练习模式均使用此流程。
**When NOT to Use**: 不适用于非练习类交互（如设置、签到）。

---

### P-09 Touch Target Sizing

**Category**: 无障碍
**Used In**: 所有屏幕

**Description**: 所有可交互元素的最小触控区域为 48×48 dp（约 144×144 px @ 3x density，对应 720px 宽屏幕约 144px）。视觉尺寸可小于触控区，通过透明 padding 扩大点击区域。

**Specification**:
- 最小触控区：48×48 dp
- 在 720×1280 px 屏幕上，48 dp ≈ 144 px（按 3x density 估算）
- 小图标按钮（如返回箭头）通过 `minimum_size` 或透明 padding 扩大触控区
- 相邻按钮间距 ≥ 8 dp，防止误触
- 底部导航 tab 按钮高度 ≥ 56 dp（含图标+文字）

**When to Use**: 所有可交互元素，无例外。
**When NOT to Use**: 纯展示元素（标签、图片）不需要触控区规范。

---

### P-10 Empty State Display

**Category**: 数据展示
**Used In**: WrongBookScreen / AchievementScreen（及任何可能为空的列表）

**Description**: 当列表或内容区无数据时，显示有意义的占位内容，而非空白区域。占位内容说明"为什么是空的"和"如何填充"。

**Specification**:
- 空状态时显示：图标（可选）+ 主文案 + 引导文案
- 主文案说明当前状态（"还没有错题"）
- 引导文案指向下一步行动（"继续练习，错题会自动收录"）
- 空状态不显示加载动画（数据已确认为空，非加载中）
- 文案使用鼓励性语气，符合小学生用户群体

**When to Use**: 任何可能为空的列表、成就墙、错题本。
**When NOT to Use**: 加载中状态应使用加载指示器，而非空状态文案。

---

## Gaps & Patterns Needed

以下交互场景在现有 GDD 中已提及，但尚未形成正式模式，待后续 UX spec 撰写时补充：

- **Loading / Progress Indicator** — 内容加载中的等待状态（目前 ContentService 在 `_ready()` 同步加载，暂无异步加载场景）
- **Confirmation Dialog** — 危险操作前的二次确认（如备份覆盖、数据重置）
- **Toast / Snackbar Notification** — 轻量级操作反馈（如"签到成功！+50 EXP"）
- **Scroll List** — 长列表滚动（错题本、成就列表可能超出屏幕高度）
- **Star Rating Display** — 结算页星级展示动画

## Open Questions

- 底部导航 tab 在练习进行中是否应禁用？（防止意外退出会话）目前 GDD 未明确。
- P-05 Sequential Tap Build 是否需要"撤销上一步"功能（而非只有"全部清除"）？
- 答题音效（正确/错误）的触发时机：提交后立即播放，还是等待评估结果显示后播放？
