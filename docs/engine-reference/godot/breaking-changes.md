# Godot Breaking Changes — 4.3 → 4.6

Last verified: 2026-05-18 (based on training data — run `/setup-engine refresh` for latest)

## Godot 4.4

### Rendering
- **Vulkan Mobile renderer improvements**: The Vulkan Mobile backend received significant performance optimizations. Projects using `gl_compatibility` (like this one) are unaffected.
- **New TileMap system**: Godot 4.4 introduced an improved TileMap layer system. The legacy TileMap node still works but is marked for deprecation in future versions.

### Animation
- **AnimationLibrary changes**: `AnimationLibrary` got API refinements. Verify any animation code that directly manipulates `AnimationLibrary` objects.

### Input
- **Enhanced Input Map**: Improvements to the Input Map system. Existing input mappings remain compatible.

### Physics
- **Physics material defaults**: Some default physics material values changed. Verify that physics behavior matches expectations after engine updates.

## Godot 4.5

### Core
- **Potential SceneTree changes**: Verify any code that relies on specific node processing order, as the scene tree processing pipeline may have been refined.

### Rendering
- **Shader language updates**: Godot shading language may have new built-in uniforms or changed defaults. Verify custom shaders after upgrading.

## Godot 4.6

### Core
- **This is the project's current version.** No migration needed.

### Known Areas to Verify
- **Autoload initialization order**: If using multiple autoloads (this project uses 4), verify their initialization order matches expectations.
- **Resource loading**: Any changes to `ResourceLoader` caching or import pipeline should be verified against the 4.6 docs.
- **Signal connections**: Verify any code that depends on signal connection order or deferred connections.

---

> **Warning**: This document was created from training data. Breaking changes for 4.4–4.6 may be incomplete or inaccurate. Run `/setup-engine refresh` when web search is available to populate verified data from the official Godot changelogs.