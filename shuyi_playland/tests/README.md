# Test Infrastructure

**Engine**: Godot 4.6.1
**Test Framework**: GdUnit4 v6.1.3 (manually installed at `shuyi_playland/addons/gdUnit4/`)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-20

## Project Layout Note

The Godot project root is `shuyi_playland/`, not the repository root. All
`res://` paths resolve relative to `shuyi_playland/`. This `tests/` directory
lives inside `shuyi_playland/` so GdUnit4 can discover test suites.

## Directory Layout

```
shuyi_playland/tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

### In-editor (recommended for development)

Open the GdUnit4 panel (bottom dock) → Run All. Or right-click any test
file → "Run Tests".

### Headless (CI / scripted)

GdUnit4 5.x ships its own command-line entry point. Use it directly — do
not write a custom SceneTree runner.

```bash
# From shuyi_playland/
godot --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add res://tests/unit \
    --add res://tests/integration \
    --continue
```

The `runtest.cmd` (Windows) and `runtest.sh` (Linux/macOS) helpers in
`addons/gdUnit4/` accept `--godot_bin` or `$GODOT_BIN`.

## Test Naming

Per `.claude/rules/test-standards.md`:

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[system]_[scenario]_[expected_result]()`
- **Example**: `appstate_level_up_test.gd` → `test_appstate_level_up_carries_over_excess_exp()`

Test classes must extend `GdUnitTestSuite` and use Arrange/Act/Assert structure:

```gdscript
extends GdUnitTestSuite

func test_appstate_level_up_carries_over_excess_exp() -> void:
    # Arrange
    var profile := { "level": 1, "exp": 0 }
    var reward := { "exp": 250, "gold": 0 }

    # Act
    AppStateTestable.apply_reward_and_check_level(profile, reward)

    # Assert
    assert_int(profile.level).is_equal(2)
    assert_int(profile.exp).is_equal(50)  # carried over
```

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough doc OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request via
`.github/workflows/tests.yml` (uses `MikeSchulze/gdUnit4-action`).
A failed test suite blocks merging. Never skip failing tests with `--no-verify` —
fix the underlying issue.

## Key ADR References

- ADR-0009 (Growth Progression Engine) — `_check_level_up()`, `_update_streak_and_weekly()`, `_get_iso_week()` all require unit tests; Dec 28 / Jan 3 boundary dates are mandatory cases
- ADR-0010 (Performance Budget) — frame time, draw call, and memory budget validation must be done on Android device, not headlessly
- ADR-0011 (Audio Integration) — `_init_audio_player()` null-path and `_play_sound(null)` no-op are unit-testable; Android audio bus verification requires device
