---
status: reverse-documented
source: shuyi_playland/autoload/ContentService.gd + data/content/*.json
date: 2026-05-18
verified-by: user
---

# Content System Design

## Overview

The content system manages all educational content through a four-level hierarchy (Grade → Module → Knowledge Point → Level) stored as JSON files. ContentService loads these at startup and provides query methods for the rest of the app. The admin backend (Node.js) produces these JSON files for the client to consume.

## Player Fantasy

Students experience a clear, organized path through math topics — grade by grade, module by module, level by level. The hierarchy feels natural and progressive, not overwhelming.

## Detailed Rules

### Content Hierarchy

```
Grade (年级, e.g. "一年级")
  └─ Module (模块, e.g. "加法与减法")
       └─ Knowledge Point (知识点, e.g. "20以内加法")
            └─ Level (关卡, e.g. "森林营地.第一关")
                 └─ Questions (题目, 10 per level)
```

- Each grade contains 3–6 modules
- Each module contains 1–4 knowledge points
- Each knowledge point contains 1–3 levels
- Each level contains exactly **10 questions**

### Data Files (10 JSON configs)

| File | Purpose |
|------|---------|
| `grades.json` | Grade definitions |
| `modules.json` | Module definitions, linked to grade_id |
| `knowledge_points.json` | Knowledge point definitions, linked to module_id |
| `levels.json` | Level definitions, linked to knowledge_point_id, with reward overrides and unlock_next |
| `questions.json` | Full question bank (158 questions, target 300+) |
| `growth_rules.json` | Level-up curve, sign-in rewards, achievement rewards |
| `task_rules.json` | Daily and weekly task definitions with targets |
| `reward_rules.json` | Base rewards per session mode |
| `star_rules.json` | Star rating thresholds |
| `resource_map.json` | Asset ID to resource path mapping |

### Level Unlock Progression

When a level is completed, its `unlock_next` array lists the IDs of levels that become available. The default starting level is `level_grade1_addition_1`.

### Question Filtering

ContentService supports filtering questions by:
- `grade_id` — all questions for a grade
- `module_id` — all questions for a module
- `knowledge_point_id` — all questions for a knowledge point
- `type` — all questions of a specific type
- Random selection (`.get_random_questions(limit)`)
- Mock test selection (`.get_mock_test_questions(grade_id, limit)`, only questions with `include_in_mock_test: true`)

## Formulas

- **Level unlock**: `unlocked_levels += level_data["unlock_next"]` on completion
- **Question count per level**: fixed at 10

## Edge Cases

- **Empty filter results**: `get_questions_by_filters()` returns `[]` if no questions match; practice screen should handle gracefully
- **Missing content files**: ContentService returns `[]` for any missing JSON file, never crashes
- **Mock test with insufficient questions**: `.get_mock_test_questions()` shuffles and slices, returning fewer than `limit` if not enough questions exist

## Dependencies

- AppState (for session configuration and progress tracking)
- Admin backend (produces JSON content files)
- QuestionRenderer (consumes question data for display)

## Tuning Knobs

| Knob | Current Value | File |
|------|---------------|------|
| Questions per level | 10 | `levels.json` (question_count) |
| Level-up curve base | 100 | `growth_rules.json` |
| Sign-in EXP | 10 | `growth_rules.json` |
| Sign-in gold | 15 | `growth_rules.json` |
| Level reward (default) | 25 EXP, 18 gold | `reward_rules.json` |
| Mock test reward | 50 EXP, 36 gold | `reward_rules.json` |
| Star threshold (2★) | 80% accuracy | `star_rules.json` |
| Star threshold (3★) | 95% accuracy | `star_rules.json` |

## Acceptance Criteria

- [ ] All 10 JSON files load without errors on app startup
- [ ] Grade → Module → Knowledge Point → Level cascade returns correct data
- [ ] Level unlock propagation works when completing a level
- [ ] Question filtering by grade, module, knowledge point, and type all return correct subsets
- [ ] Mock test selection only includes questions with `include_in_mock_test: true`