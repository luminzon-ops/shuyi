# ADR-0004: JSON Content Pipeline

## Status
Accepted

## Date
2026-05-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (data pipeline, content delivery) |
| **Knowledge Risk** | MEDIUM |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — `FileAccess`, `JSON.parse_string()`, `DirAccess`, `ResourceLoader` are stable across 4.3–4.6 |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (GDScript-Only Stack — content loading uses GDScript FileAccess/JSON APIs), ADR-0003 (Autoload Singleton Pattern — ContentService is the autoload that loads content) |
| **Enables** | All gameplay features — questions, levels, rules, rewards are all loaded via this pipeline |
| **Blocks** | Any story that adds new content types or changes content structure |
| **Ordering Note** | ContentService must load at startup (autoload order: before AppState) |

## Context

### Problem Statement
Shuyi Playland delivers 158 math questions, 24 levels, 28 modules, and game rules (star thresholds, rewards, tasks, growth) to the Android client. These must be organized, versioned, and updatable without rebuilding the APK. The content is produced by a Node.js admin backend and consumed by the Godot client.

### Constraints
- **Offline-first**: Content is bundled with the APK; no runtime download (ADR-0001)
- **GDScript-only**: Content loading uses built-in `FileAccess` and `JSON.parse_string()` (ADR-0002)
- **Admin-managed**: A local Node.js/Express backend produces JSON files; the client reads them
- **Small scale**: ~1MB total content data; linear array scans are sufficient

### Requirements
- Content must be data-driven (not hardcoded in scripts)
- Content must be bundled with the APK (no runtime network dependency)
- Content must be queryable by grade, module, knowledge point, level, and question type
- Content format must be human-readable for debugging and manual editing
- Content must support incremental updates (adding questions/levels without code changes)

## Decision

### JSON Files as the Content Format

All game content is stored as JSON files in `res://data/content/`. These files are read-only at runtime, loaded once at startup by `ContentService`, and queried in-memory throughout the app session.

**Why JSON**:
- Human-readable and editable — teachers/parents can view/modify content without Godot editor
- Godot-native loading via `FileAccess` + `JSON.parse_string()` — no custom parser needed
- Admin backend already produces JSON — no format conversion needed
- `_merge_defaults()` pattern for player data does NOT apply to content — content is always read from disk, not merged with defaults

### 10 Content Files

| File | Content | Size | Loaded By |
|------|---------|------|-----------|
| `grades.json` | Grade definitions (id, name, order) | ~200 B | ContentService |
| `modules.json` | Module definitions (id, grade_id, name) | ~2 KB | ContentService |
| `knowledge_points.json` | Knowledge point definitions (id, module_id, name) | ~2 KB | ContentService |
| `levels.json` | Level definitions (id, kp_id, name, question_count, reward, unlock_next) | ~3 KB | ContentService |
| `questions.json` | Full question bank (id, type, stem, options, answer, explanation, grade/module/kp/level links) | ~50-100 KB | ContentService |
| `growth_rules.json` | Level-up curve, sign-in rewards, achievement rewards | ~500 B | ContentService |
| `task_rules.json` | Daily and weekly task definitions with targets and rewards | ~1 KB | ContentService |
| `reward_rules.json` | Base rewards per session mode (level, mock_test, random_practice, mini_game) | ~500 B | ContentService |
| `star_rules.json` | Star rating thresholds (accuracy >= X% → Y stars) | ~300 B | ContentService |
| `resource_map.json` | Asset ID to resource path mapping (optional loading hints) | ~1 KB | ContentService |

### Content Loading Strategy

`ContentService._ready()`:
1. Iterates `CONTENT_FILES` dictionary (maps key → `res://` path)
2. For each file: checks existence, opens via `FileAccess`, parses via `JSON.parse_string()`
3. Stores parsed data in `content: Dictionary` keyed by the same keys
4. All content is loaded synchronously at startup — no async/threaded loading

**Why synchronous loading**: Total content is ~1MB. On Android, `FileAccess` read + `JSON.parse_string()` of 1MB takes <100ms. The app shows a splash screen during startup, making this imperceptible. Async loading would add complexity with no user-visible benefit.

### Query Methods

ContentService provides typed query methods instead of exposing the raw `content` dictionary:

- `get_grades() → Array` — all grade definitions
- `get_modules_for_grade(grade_id) → Array` — modules filtered by grade
- `get_knowledge_points(module_id) → Array` — knowledge points filtered by module
- `get_levels(knowledge_point_id) → Array` — levels filtered by knowledge point
- `get_questions_for_level(level_id) → Array` — questions filtered by level
- `get_random_questions(limit) → Array` — shuffled, sliced random subset
- `get_mock_test_questions(grade_id, limit) → Array` — filtered by `include_in_mock_test` flag
- `get_questions_by_filters(filters, limit) → Array` — multi-criteria filter (grade, module, kp, type)

**Why methods instead of raw dictionary access**: Encapsulates the data structure, allows refactoring the JSON format without changing all call sites, and centralizes filtering logic.

### Answer Evaluation and Result Calculation

Two pure functions that use content data to produce game results:

- `evaluate_answer(question, user_answer) → bool` — normalizes both inputs, applies type-specific comparison (numeric for fill_blank/mental_math, complex normalization for matching/drag_drop/sorting/etc.)
- `calculate_result(mode, level_id, correct_count, total_count) → Dictionary` — computes accuracy, star rating (from `star_rules.json`), and reward (from level override or `reward_rules.json`)

These are pure functions (no side effects, no state mutation) and can be unit-tested independently.

### Content Update Workflow

```
Admin Backend (Node.js, port 3131)
  ├─ Content editors modify questions, levels, rules via web UI
  ├─ Backend serializes to JSON files in storage/
  └─ Export endpoint produces client-ready JSON bundle

Developer
  ├─ Run backend export → copies JSON to shuyi_playland/data/content/
  ├─ Verify in Godot editor (F5)
  └─ Build APK → JSON files are bundled automatically

End User
  └─ APK contains latest content; no runtime download needed
```

**Note**: Content updates require rebuilding and redeploying the APK. There is no runtime content download. This is by design (offline-first constraint from ADR-0001).

## Alternatives Considered

### Alternative 1: Godot Resource (`.tres`) Files
- **Description**: Content stored as Godot custom Resource classes (`.tres` files)
- **Pros**: Type-safe properties, Godot editor integration, built-in import pipeline
- **Cons**: Binary format is not human-readable; requires Godot editor to edit; harder to produce from admin backend (would need GDScript export script); format may change between Godot versions
- **Rejection Reason**: JSON is the de facto standard for content interchange. The admin backend is Node.js/JSON-native. Using `.tres` would create a format conversion step and make manual editing impossible.

### Alternative 2: SQLite for Content
- **Description**: Content stored in SQLite tables, queried at runtime
- **Pros**: Faster filtering queries, relational integrity, smaller file size
- **Cons**: Requires schema design for content tables; harder to version control (binary file); requires SQLite module for reliable Android support (ADR-0001 established this is problematic)
- **Rejection Reason**: Content data is small (~1MB), read once at startup, and filtering is done via linear array scans in GDScript. SQLite's query performance advantage is irrelevant when data is already in memory. JSON is simpler and more debuggable.

### Alternative 3: Hardcoded Content in GDScript
- **Description**: Questions, levels, and rules defined as GDScript constants or enums
- **Pros**: Zero loading time, type-safe, no file I/O
- **Cons**: Requires code changes for every content update; impossible for non-programmers to edit; APK rebuild required for every content change (same as JSON, but code changes are riskier than data changes)
- **Rejection Reason**: The primary requirement is data-driven content. Hardcoding violates this completely and makes content authoring inaccessible to non-technical team members or AI agents.

## Consequences

### Positive
- Human-readable JSON makes content debugging and manual editing trivial
- Admin backend's JSON output maps directly to client input — no conversion step
- Synchronous loading is simple and fast for the data size
- Pure functions (`evaluate_answer`, `calculate_result`) are easily unit-testable
- Content updates are isolated from code changes — safe to modify JSON without touching GDScript

### Negative
- Content updates require APK rebuild and redeploy — no runtime content patching
- Linear array scans for filtering (e.g., `get_questions_by_filters`) are O(n) — acceptable for 158 questions, but may slow if content grows to 1000+ questions
- No built-in data validation — malformed JSON will crash at startup if not handled (ContentService does check for `null` parse results, returning `[]`)
- JSON has no schema enforcement — a typo in a question field (e.g., `answe` instead of `answer`) will not be caught until runtime

### Risks
- **Content JSON corruption in APK bundling**: If a JSON file is malformed, the app crashes on startup. Mitigation: add a JSON validation step to the build pipeline (e.g., a pre-build script that validates all JSON files against a schema).
- **Performance at scale**: If the question bank grows to 1000+ questions, linear scans may become a bottleneck. Mitigation: profile first, then consider indexing by grade/module/kp in ContentService (e.g., pre-building lookup dictionaries at load time).
- **No content versioning**: Old save files may reference question IDs that no longer exist after a content update. Mitigation: include content version in save data; on load, validate referenced question IDs exist in current content.
- **Admin backend dependency**: Content authoring requires the Node.js backend running. Mitigation: document the setup in README; consider adding a standalone content editor tool.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| content-system.md | 4-level hierarchy (grade→module→kp→level) | JSON files model the hierarchy; query methods navigate it |
| content-system.md | Questions per level (10) | `levels.json` specifies `question_count`; ContentService enforces it |
| content-system.md | Level unlock progression | `levels.json` specifies `unlock_next` array |
| content-system.md | Question filtering by grade/module/kp/type | `get_questions_by_filters()` implements multi-criteria filtering |
| practice-system.md | Answer evaluation per type | `evaluate_answer()` applies type-specific comparison logic |
| practice-system.md | Result calculation (stars, rewards) | `calculate_result()` reads `star_rules.json` and `reward_rules.json` |
| growth-system.md | Task rules and growth rules | `task_rules.json` and `growth_rules.json` drive the progression system |
| question-types.md | 10 question types supported | `questions.json` `type` field; `evaluate_answer()` handles all types |

## Performance Implications
- **CPU**: ~1MB JSON parse at startup; linear array scans for filtering (O(n) where n = question count)
- **Memory**: ~1MB for in-memory content dictionary — well within budget
- **Load Time**: <100ms synchronous load on Android for current content size
- **Network**: None — content is bundled

## Migration Plan
No migration needed — content pipeline is already JSON-based. Future improvements:
1. Add JSON schema validation to build pipeline
2. Add content version field to save data for compatibility checking
3. If question bank exceeds ~500 questions, add indexed lookup dictionaries in ContentService

## Validation Criteria
- [ ] All 10 JSON files load without errors on app startup
- [ ] ContentService returns correct data for all query methods
- [ ] `evaluate_answer()` handles all 10 question types correctly
- [ ] `calculate_result()` computes correct stars and rewards for all modes
- [ ] Malformed JSON file returns empty data without crashing (graceful degradation)
- [ ] Content data is never written at runtime (read-only)
- [ ] Adding a new question to `questions.json` makes it available without code changes

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — content is bundled, not downloaded
- ADR-0002 (GDScript-Only Stack) — content loading uses GDScript FileAccess/JSON APIs
- ADR-0003 (Autoload Singleton Pattern) — ContentService is the autoload that owns content loading