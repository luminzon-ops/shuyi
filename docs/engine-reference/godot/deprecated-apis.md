# Godot Deprecated APIs — 4.3 → 4.6

Last verified: 2026-05-18 (based on training data — run `/setup-engine refresh` for latest)

## Removals and Replacements

| Old API | New API | Version | Notes |
|---------|---------|---------|-------|
| `TileMap` node (legacy) | `TileMapLayer` node | 4.4+ | Legacy TileMap still works but is deprecated. New projects should use TileMapLayer. This project doesn't use TileMaps. |
| `AnimationNodeBlendTree` old blend modes | Verify against 4.6 docs | 4.4+ | AnimationTree blend API may have refinements. |

## APIs to Verify

The following APIs are known to have changed or been refined between 4.3 and 4.6. Before using any of these in new code, verify against the official Godot 4.6 documentation:

- **`InputMap`** — Input mapping API received improvements; verify any edge cases
- **`ResourceLoader.load()`** — Caching behavior may have changed; verify synchronous vs threaded loading expectations
- **`SceneTree` node processing** — `_process()` and `_physics_process()` call order refinements
- **`RenderingServer`** — Various rendering server methods may have new signatures in the Compatibility renderer
- **`Theme`** — Theme system refinements; check if any custom theme resources behave differently

## Project-Specific Notes

This project uses:
- **Rendering**: `gl_compatibility` — stable across 4.3–4.6
- **Autoloads**: 4 singletons (`AppState`, `ContentService`, `BackupService`, `DatabaseService`) — verify initialization order after any engine update
- **SQLite**: Via GDScript — verify the SQLite addon or native module is compatible with 4.6.1
- **JSON content pipeline**: Uses `JSON.parse_string()` — stable API, no expected changes

---

> **Warning**: This document was created from training data. Deprecated APIs for 4.4–4.6 may be incomplete. Run `/setup-engine refresh` when web search is available to populate verified data from official Godot changelogs.