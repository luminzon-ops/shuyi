# Godot 4.6 — Current Best Practices

Last verified: 2026-05-18 (based on training data — run `/setup-engine refresh` for latest)

## GDScript

- **Static typing**: Use static typing (`var health: int = 100`) for all production code. Godot 4.6 continues to improve static type inference and error reporting.
- **Signal connections**: Prefer `signal_name.connect(callable)` over `object.signal_name.connect(callable)` for clarity. Use `_on_signal_name` naming convention for connected methods.
- **Resource preloading**: Use `@export` and `@onready` annotations consistently. `@export` for inspector-visible properties, `@onready` for node references.
- **Scene instantiation**: Use `preload()` for frequently instantiated scenes, `load()` for conditional loads.

## Mobile-Specific (Android)

- **Compatibility renderer**: Use `gl_compatibility` for mobile targets (this project already does).
- **Viewport**: Set `window/stretch/mode="canvas_items"` and `window/stretch/aspect="expand"` for responsive mobile layouts (this project already does).
- **Touch input**: Use `InputEventScreenTouch` and `InputEventScreenDrag` for multi-touch. For single-touch UI, `gui_input` events work correctly.
- **Screen orientation**: Set `window/handheld/orientation` in project.godot (this project uses portrait mode = 1).

## Performance

- **Draw calls**: Minimize for mobile. Use texture atlases, tilemaps, and mesh merging where possible.
- **Physics**: Avoid per-frame `_physics_process()` overhead — batch physics operations.
- **Memory**: Monitor with `Performance.get_monitor()`. Mobile ceiling is 256MB for this project.
- **Scene loading**: Use `ResourceLoader.load_threaded()` for large scenes on mobile to avoid frame hitches.

## Content Pipeline

- **JSON data**: This project uses JSON for content (questions, modules, etc.). Prefer `JSON.parse_string()` over the deprecated `parse()` method.
- **SQLite**: For runtime save data. Ensure the SQLite module or addon is compatible with 4.6.1.
- **Autoload pattern**: This project uses 4 autoloads — they initialize in declaration order from `project.godot`.

## Project-Specific Patterns

- **Screen navigation**: Uses `ScreenHolder` pattern (see `scenes/App.tscn` and `scripts/core/app.gd`)
- **Content data**: All game content is loaded from JSON files in `data/content/`
- **State management**: `AppState.gd` is the central state autoload, using JSON serialization for saves