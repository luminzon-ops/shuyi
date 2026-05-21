# Adoption Plan

> **Generated**: 2026-05-18
> **Project phase**: Production
> **Engine**: Godot 4.6.1 (GDScript)
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Step 1: Fix Blocking Gaps

### 1a. Create formal GDDs from existing design documents

**Problem**: `design/gdd/` is empty — template skills (`/design-review`, `/create-stories`, `/review-all-gdds`, `/gate-check`) have nothing to read. Existing Chinese design docs at project root contain equivalent information but not in the 8-section template format.

**Fix**: Run `/reverse-document design shuyi_playland/` to generate formal GDDs from code and existing Chinese docs. This skill will:
- Read the existing design docs (`数一游园_Godot开发方案.md`, `项目进度报告.md`, `项目工作交接报告.md`)
- Read source code in `shuyi_playland/` to verify actual implementation
- Produce GDD files in `design/gdd/` with all 8 required sections

**Time**: 1–2 sessions (multiple GDDs)

- [ ] `design/gdd/game-concept.md` created (from existing design docs)
- [ ] `design/gdd/content-system.md` created (年级→模块→知识点→关卡 structure)
- [ ] `design/gdd/practice-system.md` created (练习模式: 专项/随机/测试/错题)
- [ ] `design/gdd/question-types.md` created (10 题型 rendering and validation)
- [ ] `design/gdd/growth-system.md` created (等级/EXP/金币/任务/奖励)
- [ ] `design/gdd/persistence-system.md` created (SQLite + JSON backup)
- [ ] `design/gdd/ui-navigation.md` created (首页→各屏幕导航流)

### 1b. Create Architecture Decision Records

**Problem**: `docs/architecture/` doesn't exist — no ADRs, so `/architecture-review`, `/create-control-manifest`, and `/story-readiness` have nothing to validate.

**Fix**: Create key ADRs using `/architecture-decision` for the architectural decisions already made in the codebase. Priority order (based on existing code):

- [ ] `docs/architecture/adr-0001-offline-first-architecture.md` — SQLite + JSON local storage, no cloud dependency
- [ ] `docs/architecture/adr-0002-gdscript-only-stack.md` — GDScript as sole language, no C# or GDExtension
- [ ] `docs/architecture/adr-0003-autoload-singleton-pattern.md` — AppState, ContentService, BackupService, DatabaseService
- [ ] `docs/architecture/adr-0004-json-content-pipeline.md` — JSON data files driven by admin backend
- [ ] `docs/architecture/adr-0005-screen-navigation-pattern.md` — ScreenHolder-based screen transitions

**Each ADR must include**: Status, ADR Dependencies, Engine Compatibility, GDD Requirements Addressed, Performance Implications.

**Time**: ~30 min per ADR

### 1c. Bootstrap TR registry

**Problem**: `docs/architecture/tr-registry.yaml` missing — no stable requirement IDs, so traceability between GDDs, ADRs, and stories cannot be established.

**Fix**: Run `/architecture-review` after Step 1a and 1b are complete — this will bootstrap the TR registry from your GDDs and ADRs.

**Time**: 1 session (review can be long)

- [ ] `docs/architecture/tr-registry.yaml` created

---

## Step 2: Fix High-Priority Gaps

### 2a. Create systems index

**Problem**: No `design/gdd/systems-index.md` — `/map-systems` output missing, `/create-epics` cannot decompose systems.

**Fix**: Run `/map-systems` after GDDs are created in Step 1a. This will decompose the game concept into systems and create the index.

**Time**: 30 min

- [ ] `design/gdd/systems-index.md` created

### 2b. Create control manifest

**Problem**: No `docs/architecture/control-manifest.md` — no layer rules for stories.

**Fix**: Run `/create-control-manifest` after ADRs (Step 1b) and TR registry (Step 1c) are complete.

**Time**: 30 min

- [ ] `docs/architecture/control-manifest.md` created

### 2c. Create sprint tracking file

**Problem**: No `production/sprint-status.yaml` — `/sprint-status` falls back to markdown parsing.

**Fix**: Run `/sprint-plan update` when you have your first sprint ready.

**Time**: 5 min

- [ ] `production/sprint-status.yaml` created

### 2d. Create architecture traceability matrix

**Problem**: No `docs/architecture/architecture-traceability.md` — no persistent requirement matrix.

**Fix**: This is automatically created during `/architecture-review` in Step 1c.

**Time**: Included in Step 1c

- [ ] `docs/architecture/architecture-traceability.md` created

---

## Step 3: Bootstrap Infrastructure

### 3a. Register existing requirements (creates tr-registry.yaml)

Run `/architecture-review` — even though ADRs are new, this run bootstraps the TR registry from your GDDs and ADRs.

**Time**: 1 session (review can be long for large codebases)

- [ ] `docs/architecture/tr-registry.yaml` created

### 3b. Create control manifest

Run `/create-control-manifest`

**Time**: 30 min

- [ ] `docs/architecture/control-manifest.md` created

### 3c. Create sprint tracking file

Run `/sprint-plan update`

**Time**: 5 min (if sprint plan already exists as markdown)

- [ ] `production/sprint-status.yaml` created

### 3d. Set authoritative project stage

Run `/gate-check Production`

**Time**: 5 min

- [ ] `production/stage.txt` written authoritatively

---

## Step 4: Medium-Priority Gaps

### 4a. Set minimum test coverage

**Problem**: `Minimum Coverage` in tech prefs is `[TO BE CONFIGURED]`.

**Fix**: Decide and set a value. Suggested: `60%` for a mobile educational app with SQLite persistence.

- [ ] Minimum coverage set in `.claude/docs/technical-preferences.md`

### 4b. Populate Forbidden Patterns and Allowed Libraries

**Problem**: `Forbidden Patterns` and `Allowed Libraries` are empty placeholders.

**Fix**: Add project-specific entries after ADRs are created. Examples:
- Forbidden: `autoload.get_node()` outside of `_ready()`, hardcoded level data in scripts
- Allowed: SQLite GDExtension (current), GUT test framework

- [ ] Forbidden Patterns populated
- [ ] Allowed Libraries populated (at minimum: SQLite, GUT)

### 4c. Populate Architecture Decisions Log

**Problem**: Architecture Decisions Log has no entries.

**Fix**: This will auto-populate as you create ADRs in Step 1b. Each ADR creation adds an entry.

- [ ] Architecture Decisions Log updated with links to ADRs

### 4d. Migrate Chinese design documents into context

**Problem**: The 3 Chinese design docs at project root (`数一游园_Godot开发方案.md`, `项目进度报告.md`, `项目工作交接报告.md`) are not discoverable by template skills which look in `design/gdd/`.

**Fix**: After `/reverse-document` creates formal GDDs in Step 1a, these root-level docs remain as reference material. Consider adding a `design/gdd/SOURCES.md` that links to them for context.

- [ ] Source reference doc created linking to original Chinese design docs

---

## Step 5: Optional Improvements

### 5a. Add Missing Coverage Target

- [ ] Set `Minimum Coverage: 60%` in tech prefs (or your preferred target)

---

## What to Expect from Existing Stories

There are no existing stories in the template format, so no migration concerns apply. All new stories created via `/create-stories` will be in full template format from the start.

---

## Re-run

Run `/adopt` again after completing Step 3 to verify all blocking and high gaps are resolved. The new run will reflect the current state of the project.