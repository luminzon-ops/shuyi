# ADR-0011: Audio Integration Architecture

## Status
Accepted

> **Godot Specialist Review (Engine Compatibility)**: MINOR NOTES (incorporated) 2026-05-19
> **TD-ADR Review**: APPROVE 2026-05-19
> **Promoted Proposed → Accepted**: 2026-05-20 via `/architecture-review`. Verification Required items (`AudioStreamPlayer.bus = "Master"` on Android, `ResourceLoader.exists()` for `.wav` in APK) are inherited as implementation-story test obligations. Migration Plan step 6 (add `level_up(new_level: int)` signal to AppState in coordination with ADR-0009) is now actionable.

## Date
2026-05-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Audio |
| **Knowledge Risk** | LOW — `AudioStreamPlayer`, `ResourceLoader.exists()`, and the `"Master"` audio bus are stable across all Godot 4.x versions |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — `AudioStreamPlayer.play()`, `AudioStreamPlayer.stop()`, `AudioStreamPlayer.bus`, `ResourceLoader.exists()` are stable across 4.x |
| **Verification Required** | Verify `AudioStreamPlayer.bus = "Master"` is valid on Android (the Master bus exists by default in all Godot 4 projects); verify `ResourceLoader.exists()` correctly detects `.wav` files on Android APK (bundled resources use `res://` paths which are accessible via ResourceLoader) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Offline-First Data Architecture — `sound_enabled` setting lives in `save_data.settings`; AppState provides `get_settings()`), ADR-0003 (Autoload Singleton Pattern — AppState is the autoload that provides the sound gate), ADR-0005 (ScreenHolder Navigation Pattern — `app.gd` owns all navigation and is the natural owner of navigation audio), ADR-0009 (Growth Progression Engine — `_check_level_up()` is the trigger site for the level-up jingle) |
| **Enables** | None — this is a leaf ADR |
| **Blocks** | Any story implementing answer SFX or level-up jingle |
| **Ordering Note** | Must be Accepted before audio implementation stories can be marked Ready |

## Context

### Problem Statement
The click sound implementation in `app.gd` is undocumented at the ADR level. There is no architectural contract defining `AudioStreamPlayer` ownership, the file-existence guard pattern, or the `sound_enabled` gate. The planned SFX expansion (correct/wrong answer feedback, level-up jingle) has no defined architectural home — without a contract, each developer will make independent decisions about where to put audio players, creating inconsistent ownership and duplicated gate logic.

### Constraints
- **GDScript-only**: No C# or GDExtension (ADR-0002)
- **Audio is never a hard dependency**: Missing audio files must not crash the app or block gameplay; the file-existence guard is mandatory
- **Single global sound toggle**: `sound_enabled` in `save_data.settings` controls all audio; no per-category volume in MVP
- **app.gd owns navigation**: All navigation actions flow through `app.gd`; it is the natural owner of navigation audio (ADR-0005)
- **No background music in MVP**: 40 OGG tracks are bundled but not wired up; this ADR does not cover music playback

### Requirements
- Must play click sound on every navigation action (TR-ui-009)
- Must gate all audio on `AppState.get_settings().get("sound_enabled", true)`
- Must guard all audio on `ResourceLoader.exists(path)` at startup — missing files produce `null` players, not crashes
- Must prevent click sound stacking on rapid taps (`stop()` before `play()`)
- Must support planned expansion: correct answer SFX, wrong answer SFX, level-up jingle
- All `AudioStreamPlayer` nodes must be owned by `app.gd`

## Decision

### app.gd Owns All AudioStreamPlayers

`app.gd` instantiates and owns all `AudioStreamPlayer` nodes at startup. Each player is created only if its audio file exists at `res://`. If the file is missing, the player variable remains `null` and all calls to that player are silently skipped.

```gdscript
# app.gd — audio player declarations
var click_player: AudioStreamPlayer       # res://assets/Audio/Sounds/Menu/Accept6.wav
var correct_player: AudioStreamPlayer     # res://assets/Audio/Sounds/Bonus/Bonus.wav (planned)
var wrong_player: AudioStreamPlayer       # res://assets/Audio/Sounds/Alert/Alert.wav (planned)
var level_up_player: AudioStreamPlayer    # res://assets/Audio/Jingles/LevelUp1.wav (planned)
```

**Why app.gd (not a dedicated AudioManager autoload)**:
- `app.gd` already owns the click sound and the `_play_click()` method — extending it is consistent with the existing pattern
- Audio in this app is triggered by navigation events (click) and gameplay events routed through `app.gd` (session start, level-up signal) — the owner of those events is the natural owner of their audio
- Adding a fifth autoload for 4 audio players violates the spirit of ADR-0003's deliberate limit; the audio system is not complex enough to warrant its own autoload

**Why not per-screen AudioStreamPlayers**:
- The `sound_enabled` gate and file-existence guard would need to be duplicated in every screen
- `app.gd` already receives all gameplay signals (`session_finished`, `back_requested`) — it can trigger audio without screens needing audio awareness

### Startup Initialization Pattern

```gdscript
func _init_audio_player(path: String) -> AudioStreamPlayer:
    if not ResourceLoader.exists(path):
        return null
    var player := AudioStreamPlayer.new()
    player.stream = load(path)
    player.bus = "Master"
    add_child(player)
    return player

func _ready() -> void:
    click_player   = _init_audio_player("res://assets/Audio/Sounds/Menu/Accept6.wav")
    correct_player = _init_audio_player("res://assets/Audio/Sounds/Bonus/Bonus.wav")
    wrong_player   = _init_audio_player("res://assets/Audio/Sounds/Alert/Alert.wav")
    level_up_player = _init_audio_player("res://assets/Audio/Jingles/LevelUp1.wav")
    # ... rest of _ready()
```

**`_init_audio_player()` is the canonical pattern** for all future audio players. Any new sound added to the app must use this method — never instantiate `AudioStreamPlayer` directly without the `ResourceLoader.exists()` guard.

### Sound Gate Pattern

```gdscript
func _play_sound(player: AudioStreamPlayer) -> void:
    if player == null:          # null check first — avoids settings lookup on no-op path
        return
    if not AppState.get_settings().get("sound_enabled", true):
        return
    player.stop()
    player.play()
```

All audio playback goes through `_play_sound()`. The `stop()` before `play()` prevents stacking on rapid triggers.

### Trigger Sites

| Sound | Trigger | Method |
|-------|---------|--------|
| Click | Every `_navigate()`, `_start_session()`, `_open_mini_game()` call | `_play_sound(click_player)` |
| Correct answer | `session_finished` signal with correct answer data, OR direct call from `PracticeScreen` via signal | `_play_sound(correct_player)` |
| Wrong answer | Same as correct answer, opposite condition | `_play_sound(wrong_player)` |
| Level-up jingle | `AppState` emits `level_up(new_level: int)` signal from `_check_level_up()`; `app.gd` connects to it | `_play_sound(level_up_player)` |

**Level-up trigger decision**: `app.gd` must NOT connect to `AppState.state_changed` and diff `profile.level` to detect level-ups. That approach couples `app.gd` to AppState's internal state schema and is fragile to schema changes. The correct approach is an explicit `level_up(new_level: int)` signal emitted by `AppState._check_level_up()`. This signal must be added as part of the audio implementation story (see Migration Plan step 6).

**Answer SFX trigger**: `PracticeScreen` emits an `answer_result(is_correct: bool)` signal; `app.gd` connects to it and calls `_play_sound(correct_player)` or `_play_sound(wrong_player)` accordingly. `app.gd` must NOT connect to `AppState.state_changed` to detect answer results — same fragility concern as the level-up case.

**AppState initialization assumption**: `_play_sound()` calls `AppState.get_settings()` at play time. Audio calls must only occur after `AppState._ready()` has completed. Given the autoload initialization order (ContentService → AppState → BackupService — ADR-0001), this is guaranteed for all user-triggered audio. Do not call `_play_sound()` from `app.gd._ready()` before the autoload chain completes.

### Architecture Diagram

```
app.gd._ready()
    ├── _init_audio_player(click_path)    → click_player
    ├── _init_audio_player(correct_path)  → correct_player (planned)
    ├── _init_audio_player(wrong_path)    → wrong_player (planned)
    └── _init_audio_player(level_up_path) → level_up_player (planned)

Navigation action (_navigate, _start_session, _open_mini_game)
    └── _play_sound(click_player)

PracticeScreen emits answer_result(is_correct)
    ├── is_correct == true  → _play_sound(correct_player)
    └── is_correct == false → _play_sound(wrong_player)

AppState._check_level_up() detects level increase
    └── [signal or direct call] → app.gd._play_sound(level_up_player)
```

### Key Interfaces

**app.gd (new/modified)**:
- `_init_audio_player(path: String) -> AudioStreamPlayer` — new; canonical factory for all audio players; returns `null` if file missing
- `_play_sound(player: AudioStreamPlayer) -> void` — new; canonical playback method; gates on `sound_enabled` and null check; stops before playing
- `click_player: AudioStreamPlayer` — existing; now initialized via `_init_audio_player()`
- `correct_player: AudioStreamPlayer` — new (planned)
- `wrong_player: AudioStreamPlayer` — new (planned)
- `level_up_player: AudioStreamPlayer` — new (planned)

**Forbidden pattern added**: Instantiating `AudioStreamPlayer` directly without `_init_audio_player()` — see registry update.

## Alternatives Considered

### Alternative 1: Dedicated AudioManager Autoload
- **Description**: A fifth autoload `AudioManager.gd` owns all `AudioStreamPlayer` nodes and exposes `play_click()`, `play_correct()`, `play_wrong()`, `play_level_up()` methods. All callers use `AudioManager.play_*()`.
- **Pros**: Single-responsibility; audio logic is isolated from navigation logic; independently testable; easy to extend with volume controls or audio categories.
- **Cons**: Adds a fifth autoload to a project that ADR-0003 deliberately limited to four; the audio system is 4 players and 2 methods — the abstraction cost exceeds the benefit; `app.gd` already owns the click sound and the navigation events that trigger it; splitting ownership creates a dependency where `app.gd` must call `AudioManager` for every navigation action.
- **Rejection Reason**: ADR-0003 established a deliberate limit on autoloads. The audio system is not complex enough to justify a new autoload. If audio grows significantly (music system, per-category volume, audio bus routing), an AudioManager autoload can be introduced at that point.

### Alternative 2: Per-Screen AudioStreamPlayers
- **Description**: Each screen that needs audio (PracticeScreen for answer SFX, HomeScreen for navigation) owns its own `AudioStreamPlayer` nodes.
- **Pros**: Each screen is self-contained; no dependency on `app.gd` for audio.
- **Cons**: The `sound_enabled` gate and `_init_audio_player()` guard must be duplicated in every screen; `app.gd` already handles navigation events and is the natural trigger site for navigation audio; answer SFX would require PracticeScreen to own audio players that are only needed for 10 questions per session.
- **Rejection Reason**: Duplicating the gate logic across screens creates maintenance risk. `app.gd` is already the signal hub for all inter-screen communication (ADR-0005); centralising audio there is consistent with the existing architecture.

### Alternative 3: AudioBus Architecture with Volume Controls
- **Description**: Create separate audio buses (SFX, Music, UI) with independent volume controls. Each player is assigned to the appropriate bus. Settings screen exposes per-bus volume sliders.
- **Pros**: Fine-grained volume control; standard game audio architecture; easy to add music without affecting SFX volume.
- **Cons**: Requires creating custom audio buses in the Godot project settings; adds UI complexity (volume sliders vs. simple on/off toggle); the current MVP has only one sound category (SFX) and no music — the architecture is premature.
- **Rejection Reason**: Out of scope for MVP. The single `sound_enabled` toggle is sufficient for the current feature set. Audio bus architecture can be introduced when background music is implemented.

## Consequences

### Positive
- `_init_audio_player()` is the single canonical pattern for all future audio — no ad-hoc `AudioStreamPlayer` instantiation
- `_play_sound()` centralises the gate logic — `sound_enabled` and null checks are never duplicated
- Missing audio files are handled gracefully at startup — no runtime crashes from missing assets
- The planned expansion (answer SFX, level-up jingle) has a defined architectural home before implementation begins

### Negative
- `app.gd` grows slightly larger as audio players are added; it is already a multi-responsibility controller (navigation + signal routing + audio)
- The answer SFX trigger mechanism is deferred to the implementation story — two acceptable options are documented but not decided

### Risks
- **`app.gd` God Object drift**: As more responsibilities are added to `app.gd`, it risks becoming a God Object. Mitigation: if `app.gd` exceeds ~200 lines, extract audio into a helper class (not an autoload) that `app.gd` instantiates.
- **Level-up signal path**: The trigger for the level-up jingle requires a `level_up(new_level: int)` signal from `AppState._check_level_up()` to `app.gd`. This signal does not currently exist. The implementation story must add it. If the signal is not added, the level-up jingle will never play.
- **Android audio latency on first play**: On Android, the audio engine initializes lazily. The first `play()` call on a cold `AudioStreamPlayer` can have a noticeable delay (50–200ms). Mitigation: during `_ready()`, after initializing each player, call `player.play()` then immediately `player.stop()` as a warm-up call. This pre-initializes the audio thread without audible output.
- **WAV import settings on Android**: Godot's default WAV import mode may not be optimal for mobile. For short UI sounds under ~1 second, uncompressed is fine. For longer sounds (e.g., `LevelUp1.wav`), verify the `.import` file uses IMA-ADPCM compression to reduce memory and load time.
- **`AppState` initialization order**: `_play_sound()` calls `AppState.get_settings()` at play time. If called before `AppState._ready()` completes, `get_settings()` returns `{}` and the `sound_enabled` fallback silently enables sound. This is not a risk given the current architecture (all user-triggered audio occurs after startup), but must not be violated by future code that calls `_play_sound()` during `_ready()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| audio-system.md | Click sound on navigation, gated by sound_enabled + file existence (TR-ui-009) | `_init_audio_player()` + `_play_sound()` pattern; `app.gd` owns all players; file-existence guard at startup |
| audio-system.md | Planned answer SFX and level-up jingle | Defines ownership (app.gd), initialization pattern, and trigger sites for all planned sounds |

## Performance Implications
- **CPU**: Negligible — `AudioStreamPlayer.play()` is a single method call; no per-frame processing
- **Memory**: 4 `AudioStreamPlayer` nodes + 4 loaded `AudioStream` resources; estimated ~2–5MB for WAV files; well within the 80MB asset budget (ADR-0010)
- **Load Time**: `_init_audio_player()` calls `load()` synchronously at startup; 4 small WAV files add negligible startup time
- **Network**: None

## Migration Plan
1. Refactor `app.gd` to extract the existing click player initialization into `_init_audio_player()`
2. Replace the existing `_play_click()` method with `_play_sound(click_player)`
3. Add `correct_player`, `wrong_player`, `level_up_player` declarations (initialized to `null`)
4. Initialize planned players via `_init_audio_player()` in `_ready()` (files may not exist yet — null is acceptable)
5. Add `answer_result(is_correct: bool)` signal to `PracticeScreen`; connect in `app.gd`
6. Add level-up signal to `AppState` (e.g., `level_up(new_level: int)`); emit from `_check_level_up()`; connect in `app.gd`
7. Implement `_play_sound(correct_player)` and `_play_sound(wrong_player)` in the answer_result handler
8. Implement `_play_sound(level_up_player)` in the level_up handler

## Validation Criteria
- [ ] Click sound plays on every navigation action when `sound_enabled == true` and `Accept6.wav` exists
- [ ] Click sound is silent when `sound_enabled == false`
- [ ] Click sound is silent (no crash) when `Accept6.wav` is missing at startup
- [ ] Rapid navigation taps do not stack click sounds
- [ ] `_init_audio_player()` returns `null` for a non-existent path without crashing
- [ ] `_play_sound(null)` is a no-op (no crash)
- [ ] *(Planned)* Correct answer SFX plays when `is_correct == true` and sound is enabled
- [ ] *(Planned)* Wrong answer SFX plays when `is_correct == false` and sound is enabled
- [ ] *(Planned)* Level-up jingle plays when level increases and sound is enabled

## Related Decisions
- ADR-0001 (Offline-First Data Architecture) — `sound_enabled` lives in `save_data.settings`
- ADR-0003 (Autoload Singleton Pattern) — AudioManager autoload rejected; audio stays in app.gd
- ADR-0005 (ScreenHolder Navigation Pattern) — app.gd owns navigation and is the natural audio owner
- ADR-0009 (Growth Progression Engine) — `_check_level_up()` is the level-up trigger; must emit a signal for app.gd to connect to
- ADR-0010 (Performance Budget) — 4 WAV files fit within the 80MB asset memory budget
