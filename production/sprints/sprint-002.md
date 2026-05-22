# Sprint 2 — 2026-05-22 to 2026-06-04

## Sprint Goal

反馈感与打磨 — 把答题循环变得"玩起来爽"。在 Sprint 1 已建立的功能完整基础
上，加上音效、EXP 飘字、升级庆祝、结算页庆祝动画等正反馈层。

## Capacity

| | Value |
|---|---|
| Working days | 10 |
| Daily hours (solo, half-day) | ~3.5 hrs |
| Total hours | ~35 hrs |
| Buffer (20%) | 7 hrs |
| Available | ~28 hrs (~8 effective days) |

## Tasks

### Must Have (Critical Path)

| ID | Task | Type | Owner | Est. | Dep. | Acceptance Criteria |
|----|------|------|-------|------|------|---------------------|
| S2-01 | PracticeScreen 发出 `answer_result(is_correct: bool)` 信号 | Logic | godot-gdscript-specialist | 0.25d | — | `_on_submit_pressed()` 在评估后发信号；附带正误布尔；单元测试覆盖 |
| S2-02 | AppState 发出 `level_up(new_level: int)` 信号（ADR-0011 Migration step 6） | Logic | godot-gdscript-specialist | 0.25d | — | `_check_level_up()` 触发后发信号，新 level 作为 payload；单元测试覆盖 |
| S2-03 | app.gd 接 `answer_result` → `_play_sound(correct_player / wrong_player)` | Integration | godot-gdscript-specialist | 0.25d | S2-01 | 答对响 Bonus.wav，答错响 Alert.wav；`sound_enabled = false` 时全部静默；快速答题不叠音 |
| S2-04 | app.gd 接 `level_up` → `_play_sound(level_up_player)` + 视觉提示 | Integration | godot-gdscript-specialist | 0.5d | S2-02 | 升级时 LevelUp1.wav 响起；UI 上有视觉 toast / 动画提示新等级 |
| S2-05 | EXP 飘字动画（按 P-11 spec） | Visual/Feel | godot-gdscript-specialist | 0.5d | S2-01 | 答对时 `+1 EXP` 金色文字 (#BF8000) 上飘 ~40px，800ms 淡出；≥18sp；不阻塞 NextButton |
| S2-06 | 选项点击 Tween 微缩放反馈 | Visual/Feel | godot-gdscript-specialist | 0.25d | — | 选项按钮被点击时 ~100ms 缩放 0.95→1.0；触感更明显 |
| S2-07 | ResultScreen 庆祝动画 | Visual/Feel | godot-gdscript-specialist | 1d | — | 星级逐个出现（每颗 ~250ms）+ 金币从 0 跳动加到获得量（~600ms）+ EXP 进度条动态填充（~800ms）；不阻塞跳出按钮；动画总时长 ≤1.5s |

**Must Have 合计**：~3 天 / ~10.5 小时（37% 预算）

### Should Have (Stretch)

| ID | Task | Type | Est. | Dep. | Acceptance Criteria |
|----|------|------|------|------|---------------------|
| S2-08 | Audio warm-up（ADR-0011 风险缓解项）| Integration | 0.25d | — | `_init_audio_player()` 后立即 `play()` + `stop()` 预热；首次播放延迟 <50ms |
| S2-09 | 修订 `home-screen.md` UX spec 反映新设计 | Docs | 0.5d | — | 更新 HeroCard / PlayCard / LibraryScreen 入口；通过 `/ux-review home-screen` |
| S2-10 | 新建 `library-screen.md` UX spec | Docs | 0.5d | — | 完整 13 节 UX spec；通过 `/ux-review library-screen` |
| S2-11 | 题库 +30 题（部分目标，188 道；剩 +20 留 Sprint 3） | Content | 1d | — | `questions.json` ≥188 条，全部加载无错；覆盖至少 2 个新知识点 |

**Should Have 合计**：~2.25 天 / ~8 小时（28% 预算）

### Deferred to Sprint 3

- 学生 playtest（4–6 名）— 需要外部协调
- 题库剩余 +20 题
- Android 设备验证（ADR-0009 / ADR-0010 / ADR-0011 多个 Verification Required 项）
- HomeScreen UX spec 与新实现完全对齐的最终审核

## Sequencing Notes

1. **S2-01 + S2-02 先做** — 这两个是独立的、低风险的信号定义，是其他任务的依赖
2. **S2-03 + S2-05 配对** — 都依赖 S2-01；做完一个测一个，避免叠错
3. **S2-04 复杂度最低** — 视觉提示可用现成的 toast pattern；放中段
4. **S2-07 留到后段** — ResultScreen 改动最大，留充分时间调感
5. **每完成一项跑一次测试套件** — 防止 Sprint 1 那种"测试没真跑过"的复发

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Bonus.wav / Alert.wav / LevelUp1.wav 实际文件路径不对或缺失 | Medium | Low | `_init_audio_player()` 已 null-safe；先确认资源存在再做 S2-03/04，缺失则用占位 |
| Tween 在 ScreenHolder 隐藏的屏幕上行为异常 | Low | Low | 切屏前 `tween.kill()`；ResultScreen 添加 `tree_exiting` 清理 |
| 动画时长干扰用户操作节奏 | Low | Medium | 所有动画 ≤1.5s 总时长；按钮交互不被阻塞；用户跳出立刻 kill |
| 升级 toast 设计与现有 HUD philosophy 冲突（HUD spec 主张极简） | Low | Medium | toast 走 P-11 同款金色调，定位置与 EXP 飘字同区，不引入新 zone |

## Dependencies on External Factors

- 三个 SFX 文件需要确认在 `assets/Audio/` 下存在；缺失则部分 S2-03/04 推迟
- 题库扩充需要小学数学知识来出题（用户主导，AI 协助校对）

## Definition of Done

- [ ] 全部 Must Have 完成且通过验收标准
- [ ] 自动化测试 ≥66 个（增加 S2-01 / S2-02 信号测试）
- [ ] Headless boot 0 错误 0 警告
- [ ] Smoke check 通过（PASS 或 PASS WITH WARNINGS）
- [ ] 没引入 S1/S2 严重 bug
- [ ] 三个音效至少有占位资源接上
- [ ] Sprint 2 完成后跑一次完整 QA cycle（`/team-qa sprint`）
