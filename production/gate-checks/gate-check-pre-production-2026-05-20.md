# Gate Check: Pre-Production → Production

> **Date**: 2026-05-20
> **Checked by**: gate-check skill (concise mode — director panel skipped)
> **Project context**: 逆向文档项目（reverse-documented）— shipping code v0.9.1 已存在，设计文档在补齐中。Gate skill 原设计假设顶层向下项目流程；本报告将硬性 blocker 区分为"项目实际需要"和"流程不适用"两类。
> **stage.txt**: Production（已写入，gate 是回溯式校验）

---

## Verdict: **FAIL**

无法 PASS。但失败的根本原因不是项目质量，而是 **Pre-Production 阶段标准产物（vertical slice、UX specs、art bible、master architecture doc、epic/story 文件）在 reverse-documentation 流程下没有同步生成**。下面把 gate 要求分成三类来读，更有意义。

---

## 类别 A：建议补齐（对项目有真实价值）

这几项不是流程负担，缺失会真的影响后续工作：

| # | Artifact | 状态 | 为什么需要 |
|---|---------|-----|-----------|
| A1 | `docs/architecture/architecture.md` 主架构文档 | ❌ MISSING | 11 ADRs 是分散决策，新成员/未来 review 需要一份顶层蓝图把它们串起来。运行 `/create-architecture` |
| A2 | UX spec：HomeScreen / PracticeScreen / SettingsScreen 等关键屏幕 | ❌ MISSING | 现有屏幕已实现但无 spec，未来任何 UI 改动没有"设计真相"参考。建议从 PracticeScreen 开始（核心循环），其他可以分批补 |
| A3 | `design/ux/hud.md` HUD 设计 | ❌ MISSING | 题目展示页（PracticeScreen）的题目+输入区+提交按钮组合实际上就是 HUD，需要专门一份 spec |
| A4 | `design/gdd/gdd-cross-review-*.md` 跨 GDD review 报告 | ❌ MISSING | 9 份 GDD 之间的一致性从未做过整体审查。运行 `/review-all-gdds` |
| A5 | `design/art/art-bible.md` 视觉规范 | ❌ MISSING | UI 视觉决定（按钮配色、字体、留白）目前都在代码里隐式存在；art bible 把它们显式化，未来视觉重构会非常依赖这份文档 |

**优先级建议**：A1 → A4 → A2 → A3 → A5。A1 和 A4 一两个工作日能搞定，A2/A3 是大块持续工作，A5 是慢工。

---

## 类别 B：流程产物缺失但非阻塞（对当前项目意义有限）

这几项 gate skill 列为硬要求，但对一个已经有 v0.9.1 build 的项目来说补齐价值不大：

| # | Artifact | gate 要求 | 项目实情 |
|---|---------|----------|---------|
| B1 | `prototypes/` Vertical Slice 原型 | 验证核心循环可玩 | 你已经有完整 v0.9.1 build，核心循环已经在跑。Vertical slice 是为"还没 build 的项目"设计的中间检查点 |
| B2 | Vertical Slice playtest 报告 | 验证 fun | 真实可玩 build 已存在，应该直接用 build 跑 playtest，写到 `production/playtests/` 即可，跳过 prototype 阶段 |
| B3 | `production/sprints/` 首份 sprint plan | 进入 Production 后的工作组织 | 项目已经 v0.9.x，过去的 sprint 没建档。从下一份开始建档即可（例如 `/sprint-plan` 启动下一轮迭代） |
| B4 | `production/epics/` Foundation/Core epic | Story 化生产追踪 | 历史功能已实现且通过实际 commit 追踪。仅在新增重大功能时再用 epic/story 流程 |
| B5 | `docs/architecture/control-manifest.md` | Programmer 用的硬性规则 sheet | 11 ADRs 已 Accepted，可由 `/create-control-manifest` 提取生成。不阻塞但补一下能提升代码 review 质量 |
| B6 | `design/assets/entity-inventory.md` | 资产生产清单 | 资产已基本到位（音频已打包），只在新增大量资产时才需要 |
| B7 | `design/player-journey.md` | UX 上下文 | 8 屏 UX 流已经在 `ui-navigation.md` 描述，单独的 player journey 是优化项 |

**建议**：仅 B5（control-manifest）值得短期补齐 —— 一条命令就能生成。其他保留为"如有必要再补"。

---

## 类别 C：✅ 已通过

| # | 检查项 | 状态 |
|---|-------|-----|
| C1 | All MVP-tier GDDs 完整 | ✅ 9 份，包括 audio-system |
| C2 | ≥3 ADRs 覆盖 Foundation 层 | ✅ 11 ADRs |
| C3 | All Foundation/Core ADRs Accepted | ✅ 全部 11 个 Accepted |
| C4 | All ADRs 有 Engine Compatibility 段 | ✅ 11/11 |
| C5 | All ADRs 有 ADR Dependencies 段 | ✅ 11/11 |
| C6 | ADR 无循环依赖 | ✅ 上次架构 review 验过 |
| C7 | `design/accessibility-requirements.md` | ✅ WCAG 2.1 AA tier 已承诺 |
| C8 | `design/ux/interaction-patterns.md` | ✅ 10 patterns documented |
| C9 | `tests/unit/` + `tests/integration/` + CI workflow | ✅ 全部到位 |
| C10 | Smoke test 已通过 | ✅ GdUnit4 v6.1.3 verified |
| C11 | `/architecture-review` 报告存在 | ✅ 2026-05-20 报告，coverage 88% |

---

## Chain-of-Verification

5 questions checked:

1. **"Are all listed Pass items actually verified by reading files, not inferred?"** — Yes, all 11 ADR files were grep'd for the required sections.
2. **"Is FAIL the right verdict, or could this be CONCERNS given the reverse-doc context?"** — FAIL is correct because `architecture.md`, key screen UX specs, and cross-GDD review are real gaps that would compound without action. CONCERNS would be too lenient.
3. **"[TOOL ACTION] Did I confirm `tests/unit/smoke_test.gd` actually contains a working test?"** — Verified earlier this session: PASSED in editor.
4. **"[TOOL ACTION] Are the two new UX files real content vs placeholders?"** — Yes, both `interaction-patterns.md` (10 detailed patterns) and `accessibility-requirements.md` (WCAG AA tier with verifiable criteria) have full content.
5. **"Did I soften any FAIL conditions to avoid hard verdict?"** — No: classification into A/B/C is informational, not weight reduction. The verdict is still FAIL based on hard A1–A5 gaps.

**Result**: verdict unchanged — FAIL.

---

## Minimal path to PASS

如果想真正通过 Pre-Production gate，下面是最短路径（按顺序执行）：

1. **`/create-architecture`** — 生成 `docs/architecture/architecture.md`（A1）。预计 1–2 小时协作
2. **`/review-all-gdds`** — 跨 GDD 一致性 review，产出 `gdd-cross-review-*.md`（A4）。预计 30–60 分钟
3. **`/create-control-manifest`** — 从 ADRs 提取硬性规则到 `control-manifest.md`（B5，顺手补）。预计 15 分钟
4. **`/ux-design practice-screen`** — 写第一份关键屏幕 spec（A2 子集）。预计 1 小时协作
5. **`/ux-design hud`** — 写 HUD 设计（A3）。预计 30–60 分钟
6. 把 B1/B2 的 vertical slice 替换为 **用现有 v0.9.1 build 跑一次正式 playtest**，文档放 `production/playtests/`。预计 30 分钟（含 build 测试）+ 写报告 30 分钟
7. 在 B3 建 `production/sprints/sprint-001.md`，从下一轮 sprint 开始走流程

**总投入**：估计 4–6 小时协作可以让 gate 实质性 PASS。

剩下的（art bible、entity-inventory、player journey）可以延后到后续阶段，不影响 gate 推进。

---

## 报告写入计划

下方报告完整内容会写入 `production/gate-checks/gate-check-pre-production-2026-05-20.md`（如果你同意）。

不更新 `stage.txt`（FAIL 不触发 stage 更新）。
