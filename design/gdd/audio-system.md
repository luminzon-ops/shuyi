---
status: partially-implemented
source: shuyi_playland/scripts/core/app.gd (click sound); assets/Audio/ (bundled asset library)
date: 2026-05-19
verified-by: user
---

# Audio System Design

## Overview

The audio system provides sound feedback for navigation and gameplay events. The MVP implementation plays a single click sound on every navigation action, gated by a user-controlled `sound_enabled` setting and a runtime file-existence check. A rich asset library (40 music tracks, 100+ SFX) is bundled but not yet wired up. The planned expansion adds correct/wrong answer SFX and a level-up jingle, all using the same gated pattern.

## Player Fantasy

Every tap feels responsive — a satisfying click confirms the action. Correct answers feel rewarding; wrong answers feel gentle, not punishing. The student can silence everything with one toggle if they are in a quiet environment.

## Detailed Rules

### Sound Toggle

- `AppState.get_settings().get("sound_enabled", true)` — global on/off toggle
- Default: `true` (sound on)
- Controlled from the Settings screen
- When `sound_enabled == false`, all audio playback is suppressed; no `AudioStreamPlayer` calls are made

### Click Sound (Implemented — TR-ui-009)

- **Trigger**: Every navigation action (`_navigate()`, `_start_session()`, `_open_mini_game()`)
- **File**: `res://assets/Audio/Sounds/Menu/Accept6.wav`
- **Player**: `AudioStreamPlayer` node added to `app.gd` at startup; bus: `"Master"`
- **Gating**: Plays only if `sound_enabled == true` AND `click_player != null`
- **File-existence guard**: `click_player` is `null` if `ResourceLoader.exists(click_sound_path)` returns `false` at startup. Navigation continues silently if the file is missing — audio is never a hard dependency.
- **Overlap prevention**: `click_player.stop()` is called before `click_player.play()` to prevent overlapping clicks on rapid taps

### Correct Answer SFX (Planned — not yet implemented)

- **Trigger**: `AppState.record_answer()` returns `is_correct == true`
- **Candidate files**: `res://assets/Audio/Sounds/Bonus/Bonus.wav` or `Bonus2.wav`
- **Player**: Separate `AudioStreamPlayer` in `app.gd` or `PracticeScreen.gd`; bus: `"Master"`
- **Gating**: Same `sound_enabled` check as click sound

### Wrong Answer SFX (Planned — not yet implemented)

- **Trigger**: `AppState.record_answer()` returns `is_correct == false`
- **Candidate files**: `res://assets/Audio/Sounds/Alert/Alert.wav` or `Alert2.wav`
- **Player**: Separate `AudioStreamPlayer`; bus: `"Master"`
- **Gating**: Same `sound_enabled` check

### Level-Up Jingle (Planned — not yet implemented)

- **Trigger**: `AppState._check_level_up()` detects a level increase
- **Candidate files**: `res://assets/Audio/Jingles/LevelUp1.wav`
- **Player**: Separate `AudioStreamPlayer`; bus: `"Master"`
- **Gating**: Same `sound_enabled` check
- **Non-blocking**: Jingle plays over other sounds; does not pause gameplay

### Background Music (Not in scope — documented as gap)

- 40 OGG music tracks are bundled at `res://assets/Audio/Musics/`
- No background music is currently wired up
- Background music is deferred to a future version; it is not part of the MVP or planned expansion
- When implemented, it will require a separate `AudioStreamPlayer` with looping enabled and a volume control independent of the SFX toggle

## Formulas

- **Sound gate**: `sound_enabled AND file_exists(path)` — both conditions must be true for any sound to play
- **No volume formula**: All sounds play at default volume (1.0) on the `"Master"` bus; no per-sound volume scaling in MVP

## Edge Cases

- **Missing audio file**: `ResourceLoader.exists()` check at startup prevents a null `AudioStreamPlayer`; navigation and gameplay continue silently
- **Rapid taps**: `click_player.stop()` before `click_player.play()` prevents click sound stacking
- **Sound disabled mid-session**: `sound_enabled` is checked at play time, not at startup — toggling sound off in Settings takes effect immediately on the next navigation action
- **Level-up during session**: Level-up jingle (planned) must not interrupt or delay the session result flow; it plays non-blocking over other sounds
- **Multiple correct answers in quick succession**: Correct answer SFX (planned) should use `stop()` + `play()` to prevent stacking, same as click sound

## Dependencies

- `AppState` — provides `get_settings().sound_enabled`; `record_answer()` triggers answer SFX (planned); `_check_level_up()` triggers level-up jingle (planned)
- `app.gd` — owns the `AudioStreamPlayer` nodes for click sound; will own answer SFX and level-up jingle players
- `ui-navigation.md` — click sound is triggered by every `_navigate()` call (TR-ui-009)
- `growth-system.md` — level-up jingle is triggered by `_check_level_up()` (ADR-0009)

## Tuning Knobs

| Knob | Current Value | Location | Adjustable? |
|------|---------------|----------|-------------|
| Click sound file | `Accept6.wav` | `app.gd` (hardcoded path) | Yes — change path |
| Sound enabled default | `true` | `AppState` default settings | Yes — JSON |
| Audio bus | `"Master"` | `app.gd` | Yes — change bus name |
| Correct answer SFX file | `Bonus.wav` (planned) | `app.gd` | Yes |
| Wrong answer SFX file | `Alert.wav` (planned) | `app.gd` | Yes |
| Level-up jingle file | `LevelUp1.wav` (planned) | `app.gd` | Yes |

## Acceptance Criteria

- [ ] **[TR-ui-009]** Click sound plays on every navigation action when `sound_enabled == true` and `Accept6.wav` exists
- [ ] Click sound is silent when `sound_enabled == false`
- [ ] Click sound is silent (no crash) when `Accept6.wav` is missing
- [ ] Rapid taps do not stack click sounds (stop before play)
- [ ] Toggling sound off in Settings silences audio immediately on the next action
- [ ] *(Planned)* Correct answer SFX plays when `is_correct == true` and sound is enabled
- [ ] *(Planned)* Wrong answer SFX plays when `is_correct == false` and sound is enabled
- [ ] *(Planned)* Level-up jingle plays when level increases and sound is enabled; does not block gameplay
