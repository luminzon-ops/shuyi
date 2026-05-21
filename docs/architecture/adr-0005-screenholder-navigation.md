# ADR-0005: ScreenHolder Navigation Pattern

## Status
Accepted

## Date
2026-05-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | UI |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — `Control.visible`, `Node.add_child()`, `Signal.connect()` are core APIs stable since Godot 3.x |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Autoload Singleton Pattern — app.gd is not an autoload but follows the same signal-routing philosophy) |
| **Enables** | All UI screen transitions; all screen-to-screen communication |
| **Blocks** | Any story adding new screens or changing navigation flow |
| **Ordering Note** | None |

## Context

### Problem Statement
Shuyi Playland has 9 UI screens (Home, Practice, Growth, Sign-in, Achievements, Wrong Book, Result, Mini-game, Settings) that need to be shown, hidden, and transitioned between without scene tree changes. The app must run smoothly on Android with no loading screens or perceptible transitions.

### Constraints
- **Single-scene architecture**: `App.tscn` is the root scene; no `get_tree().change_scene()` calls
- **GDScript-only**: All screen logic in GDScript (ADR-0002)
- **Touch input**: No keyboard/gamepad navigation; all interaction is tap-based
- **Performance budget**: 60fps target; screen switching must be sub-frame

### Requirements
- Must switch between screens instantly (no loading, no fade unless decorative)
- Must preserve screen state when hidden (e.g., PracticeScreen remembers current question)
- Must route all inter-screen communication through a single controller
- Must update title bar on every navigation
- Must support optional per-screen `refresh_view()` call on entry

## Decision

### ScreenHolder Pattern

All 9 screens are instantiated as child `Control` nodes of a `ScreenHolder` (also a `Control`) at app startup. Only one screen is visible at a time. Navigation is controlled by `app.gd` (the root script of `App.tscn`), which toggles `visible` on screens and updates the title bar.

**Why pre-instantiate all screens**:
- No perceptible load time — screens are ready in memory
- State is preserved when hidden (question progress, scroll position, etc.)
- No scene tree manipulation overhead during navigation
- Simplest possible implementation for a small number of screens

**Why not `change_scene()`**:
- Would destroy screen state on navigation
- Would require save/load of transient UI state
- Would cause frame hitches during scene loading
- Overkill for 9 lightweight screens

### Screen Lifecycle

1. **Instantiate** (in `app.gd _ready()`): All 9 screens are `preload()`ed, `.instantiate()`ed, set to `visible = false`, and added as children of `ScreenHolder`
2. **Show** (`_show_screen(screen, title, subtitle)`): Hide all ScreenHolder children, show target screen, update title/subtitle labels, call `refresh_view()` if available
3. **Navigate** (bottom nav buttons or screen signals): `app.gd` receives signal, determines target screen, calls `_show_screen()`
4. **Hide** (implicit): Previous screen becomes invisible but remains in memory

### Signal Routing

No screen directly references another screen. All inter-screen communication flows through `app.gd`:

| Source Signal | app.gd Handler | Target Screen |
|---------------|----------------|---------------|
| `start_session_requested(config)` | `_start_session(config)` | PracticeScreen |
| `session_finished(summary)` | `_on_session_finished(summary)` | ResultScreen |
| `back_requested` | `_show_screen(home_screen, ...)` | HomeScreen (or context-appropriate) |
| `retry_requested` | `_retry_last_session()` | PracticeScreen |
| `game_finished(summary)` | `_on_game_finished(summary)` | ResultScreen |
| `open_growth_requested` | `_show_screen(growth_screen, ...)` | GrowthScreen |
| `open_sign_in_requested` | `_show_screen(sign_in_screen, ...)` | SignInScreen |
| `open_achievements_requested` | `_show_screen(achievement_screen, ...)` | AchievementScreen |
| `open_wrong_book_requested` | `_show_screen(wrong_book_screen, ...)` | WrongBookScreen |
| `start_wrong_retry_requested` | `_start_wrong_retry()` | PracticeScreen |

### Bottom Navigation Bar

5 fixed buttons at the bottom of the screen:
- **Home** → HomeScreen
- **Practice** → opens most recent level (or default)
- **Growth** → GrowthScreen
- **Mini-game** → MiniGameScreen
- **Settings** → SettingsScreen

Each button plays an optional click sound (respects `sound_enabled` setting).

### Title Bar

Two `Label` nodes (`%TitleLabel`, `%SubtitleLabel`) updated on every `_show_screen()` call. The title reflects the current screen; the subtitle provides context.

### Architecture Diagram

```
App.tscn (root Control)
├── TitleLabel
├── SubtitleLabel
├── ScreenHolder (Control)
│   ├── HomeScreen (Control, visible)
│   ├── PracticeScreen (Control, hidden)
│   ├── GrowthScreen (Control, hidden)
│   ├── SignInScreen (Control, hidden)
│   ├── AchievementScreen (Control, hidden)
│   ├── WrongBookScreen (Control, hidden)
│   ├── ResultScreen (Control, hidden)
│   ├── MiniGameScreen (Control, hidden)
│   └── SettingsScreen (Control, hidden)
└── BottomNavBar (HBoxContainer)
    ├── HomeButton
    ├── PracticeButton
    ├── GrowthButton
    ├── MiniGameButton
    └── SettingsButton
```

## Alternatives Considered

### Alternative 1: Scene Stack (Push/Pop)
- **Description**: Screens are pushed onto a stack; back button pops to previous screen
- **Pros**: Natural for deep navigation (e.g., Home → Growth → Achievements → back → Growth)
- **Cons**: More complex state management; stack can grow unexpectedly; back button behavior varies by platform
- **Rejection Reason**: The app's navigation is shallow and predictable. Most "back" actions go to a fixed parent screen (not the previous screen). A stack would add complexity for no benefit.

### Alternative 2: `change_scene()` with State Serialization
- **Description**: Each screen is a separate `.tscn` file loaded via `get_tree().change_scene()`
- **Pros**: Cleaner separation; each screen is an independent scene
- **Cons**: Destroys state on navigation; requires explicit save/load of transient UI state; frame hitches on Android; more complex signal routing across scene boundaries
- **Rejection Reason**: State preservation is critical (PracticeScreen remembers question index, scroll position, etc.). Reconstructing this state on every navigation would be error-prone and slow.

### Alternative 3: TabContainer
- **Description**: Use Godot's built-in `TabContainer` to manage screen visibility
- **Pros**: Built-in tab switching logic; handles visibility automatically
- **Cons**: TabContainer enforces a tab bar UI that doesn't match the app's custom bottom navigation design; harder to control transition animations and title updates
- **Rejection Reason**: The app's navigation is custom (5 bottom buttons, not tabs). TabContainer's built-in UI doesn't fit the design.

## Consequences

### Positive
- Instant screen switching — no loading, no state loss
- Simple implementation — toggle `visible`, update labels
- All screens are accessible for debugging in the scene tree
- State is preserved automatically (no explicit save/restore needed)
- `refresh_view()` hook allows screens to refresh data when revisited

### Negative
- All 9 screens consume memory simultaneously (~9 × screen node tree)
- Screens must handle being hidden gracefully (e.g., pause animations, stop timers)
- Adding a 10th screen requires modifying `app.gd` (hardcoded screen list)
- No built-in transition animation support (must be implemented per-screen if desired)

### Risks
- **Memory usage with many screens**: Currently 9 screens; if this grows to 20+, memory may become a concern. Mitigation: lazy instantiation for infrequently used screens, or scene-switching for deep sub-screens.
- **Screen state inconsistency**: A hidden screen may have stale data if `refresh_view()` is not called. Mitigation: all screens that display dynamic data implement `refresh_view()`; app.gd calls it on every navigation.
- **Navigation logic bloat**: `app.gd` accumulates routing logic as screens are added. Mitigation: keep routing table clean; if it grows beyond ~15 routes, consider a dedicated `NavigationManager` autoload.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| ui-navigation.md | 9 screens, instant switching | ScreenHolder toggles visibility; all screens pre-instantiated |
| ui-navigation.md | Signal-based routing | All inter-screen signals route through app.gd |
| ui-navigation.md | Title bar updates | `_show_screen()` updates TitleLabel and SubtitleLabel |
| ui-navigation.md | Bottom 5-button nav | HBoxContainer with 5 buttons, each mapped to a screen |
| ui-navigation.md | State preservation | Screens remain in memory when hidden; no state loss |
| practice-system.md | Session → Result navigation | `session_finished` signal → app.gd → ResultScreen |
| growth-system.md | Growth → Sign-in/Achievements links | `open_sign_in_requested` / `open_achievements_requested` signals |

## Performance Implications
- **CPU**: Negligible — toggling `visible` is a single boolean assignment per screen
- **Memory**: All 9 screen node trees in memory simultaneously; estimated <5MB total for lightweight UI screens
- **Load Time**: All screens load at startup; no per-navigation load time
- **Network**: None — fully offline

## Migration Plan
No migration needed — ScreenHolder pattern is already implemented.

Future improvements:
1. If screen count exceeds ~15, consider lazy instantiation for infrequently used screens
2. If transition animations are desired, add a `ScreenTransition` overlay between visibility toggles
3. If navigation logic grows, extract to a dedicated `NavigationManager` autoload

## Validation Criteria
- [ ] All 9 screens are pre-instantiated in `app.gd _ready()`
- [ ] Only one screen is visible at a time
- [ ] `_show_screen()` updates title and subtitle labels
- [ ] `refresh_view()` is called on screen entry when available
- [ ] Bottom nav buttons navigate to correct screens
- [ ] All inter-screen communication goes through `app.gd` (no direct screen-to-screen references)
- [ ] Screen state is preserved when hidden (e.g., PracticeScreen remembers current question)

## Related Decisions
- ADR-0002 (GDScript-Only Stack) — all screen scripts are GDScript
- ADR-0003 (Autoload Singleton Pattern) — app.gd accesses autoloads for state data
- ADR-0004 (JSON Content Pipeline) — ContentService provides data that screens display