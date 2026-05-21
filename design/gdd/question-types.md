---
status: reverse-documented
source: shuyi_playland/scripts/question_types/question_renderer.gd
date: 2026-05-18
verified-by: user
---

# Question Types Design

## Overview

The question type system renders and collects answers for 10 distinct question formats, each suited to different math skills. All types share a common evaluation path through `ContentService.evaluate_answer()`, but differ in how they present options and collect input.

## Player Fantasy

Students experience variety in how they practice — not just multiple choice, but filling in answers, connecting items, ordering, and solving word problems. The format matches the skill being tested.

## Detailed Rules

### Supported Types (10)

| Type | ID | Input Method | Description |
|------|----|-------------|-------------|
| Choice | `choice` | Tap option button | Single-select multiple choice |
| True/False | `true_false` | Tap option button | True or false judgment |
| Fill-blank | `fill_blank` | LineEdit text input | Free-form numeric or text answer |
| Mental math | `mental_math` | LineEdit text input | Quick mental arithmetic, accepts numeric answers |
| Matching | `matching` | Tap options → LineEdit | Pair items using `>` separator |
| Drag-drop | `drag_drop` | Tap options → LineEdit | Arrange items by tapping in order |
| Sorting | `sorting` | Tap options → LineEdit | Order items from small to large |
| Shape puzzle | `shape_puzzle` | Tap options → LineEdit | Select/construct geometric arrangements |
| Application | `application` | LineEdit text input | Word problems requiring calculation |
| Multi-step | `multi_step` | LineEdit text input | Problems requiring multiple calculation steps |

### P0 vs P1 Priority

| Priority | Types |
|----------|-------|
| **P0** (must-have, implemented) | choice, true_false, fill_blank, mental_math |
| **P1** (implemented, lower volume) | matching, drag_drop, sorting, shape_puzzle, application, multi_step |

### Rendering Logic

`QuestionRenderer.render(question, option_container, answer_input, select_callback)`:

1. Reads `question.type`
2. For **choice / true_false**: Creates Button nodes in `option_container`, hides `answer_input`. Each button calls `select_callback` on press.
3. For **fill_blank / mental_math**: Hides `option_container`, shows `answer_input` (LineEdit).
4. For **matching / drag_drop / sorting / shape_puzzle**: Creates Button nodes in `option_container` AND shows `answer_input`. Tapping a button appends its value to `answer_input.text` with `">"` separator.

### Answer Collection

`QuestionRenderer.build_user_answer(question_type, selected_option, answer_input)`:

- For choice/true_false: returns `selected_option`
- For fill_blank/mental_math: returns `answer_input.text`
- For complex types: returns `answer_input.text` (contains `>` separated selections or free text)

### Answer Evaluation

`ContentService.evaluate_answer(question, user_answer)`:

1. Normalize both answer and user input via `strip_edges().to_lower()`
2. For fill_blank/mental_math: attempt numeric comparison (`is_equal_approx`) if both parse as floats, otherwise exact text match
3. For complex types: normalize both strings (remove spaces, `，`→`,`, `→`/`-`→`>`, remove `=`), then exact match
4. For choice/true_false: exact match after normalization

## Formulas

- **Numeric comparison**: `is_equal_approx(expected.toFloat(), actual.toFloat())` — handles floating-point precision
- **Complex normalization**: `answer.replace(" ", "").replace("，", ",").replace("→", ">").replace("-", ">").replace("=", "").strip_edges().to_lower()`

## Edge Cases

- **Empty answer**: `user_answer` is empty string → will not match any correct answer
- **Whitespace in fill-blank**: `strip_edges()` removes leading/trailing whitespace before comparison
- **Chinese comma vs ASCII comma**: `，` (Chinese) is normalized to `,` for matching types
- **Arrow separator**: Both `→` and `-` are normalized to `>` for ordering answers
- **Case-insensitive**: Answers are compared in lowercase

## Dependencies

- ContentService (evaluate_answer, question data)
- PracticeScreen (session flow)

## Tuning Knobs

| Knob | Current Value | Location |
|------|---------------|----------|
| P0 question types | choice, true_false, fill_blank, mental_math | Hardcoded in QuestionRenderer |
| P1 question types | matching, drag_drop, sorting, shape_puzzle, application, multi_step | Hardcoded in QuestionRenderer |
| Complex type separator | `>` | QuestionRenderer normalization |

## Acceptance Criteria

- [ ] All 10 question types render correctly in PracticeScreen
- [ ] Answer evaluation handles numeric comparison for fill-blank and mental math
- [ ] Complex type normalization correctly normalizes Chinese punctuation and separators
- [ ] Empty answers are handled gracefully (no crash, marked incorrect)
- [ ] Tapping option buttons in complex types correctly appends to the answer input