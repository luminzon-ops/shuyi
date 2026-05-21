# ADR-0001: Offline-First Data Architecture

## Status
Accepted

## Date
2026-05-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.1 |
| **Domain** | Core (data persistence, storage) |
| **Knowledge Risk** | MEDIUM — Godot 4.4–4.6 are near/beyond LLM training cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None — `FileAccess`, `JSON.parse_string()`, `ZIPPacker`/`ZIPReader`, `DirAccess` are stable across 4.3–4.6 |
| **Verification Required** | None — all APIs used are within training data coverage |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR) |
| **Enables** | ADR-0003 (Autoload Singleton Pattern — depends on this storage architecture), ADR-0004 (JSON Content Pipeline — content data is read-only, but shares patterns) |
| **Blocks** | None |
| **Ordering Note** | Must be Accepted before any persistence-related stories can be marked Ready |

## Context

### Problem Statement
Shuyi Playland is a fully offline Android app for elementary math practice. All player data (progress, settings, achievements, wrong book, tasks) must persist across app restarts, survive app updates, and be transferable between devices via export/import. No cloud or server dependency exists for runtime data — the app must function entirely without network access.

### Constraints
- **Offline-first**: No network dependency for any save/load operation
- **Android target**: Path `user://` resolves to internal app storage; no external SD card writes
- **Small data footprint**: Player save data is a single Dictionary (~10–50KB serialized)
- **Content data is read-only**: Questions, levels, rules come from bundled JSON files; player data is the only mutable state
- **Godot 4.6.1**: Uses `FileAccess`, `JSON`, `ZIPPacker`/`ZIPReader`, and `DirAccess`

### Requirements
- Must save player state after every state-changing action (answer recorded, level completed, sign-in, task claimed)
- Must support backup export (ZIP containing JSON data) and import with validation
- Must handle corrupt or missing save files by falling back to fresh defaults
- Must support schema evolution — adding new fields to save_data should not break old saves
- Must survive app updates that add new top-level sections to save_data
- Must use atomic writes to prevent data loss on interrupted writes (Android process killing)

## Decision

### Primary Store: JSON File (`user://savegame.json`)

The JSON file is the single source of truth for all player state. Every state-changing action calls `AppState.save_to_disk()`, which serializes `save_data` to `user://savegame.json` via `JSON.stringify()`.

**Why JSON over SQLite as primary**:
- Human-readable for debugging
- Directly serializable from Godot's Dictionary type
- No schema migration needed — `_merge_defaults()` handles new fields
- Small data size makes the performance difference negligible

### Atomic Write Pattern (MANDATORY)

To prevent data loss from Android process killing mid-write, `save_to_disk()` MUST use the write-to-temp-then-rename pattern:

```
1. Write serialized JSON to user://savegame.tmp
2. Close the temp file
3. Rename savegame.tmp → savegame.json (DirAccess.rename overwrites the old file)
```

This eliminates the corruption window. If the app is killed during step 1, the old `savegame.json` remains intact. If killed during step 3, either the temp file or the primary file is complete.

**Do NOT** write directly to `savegame.json` — `FileAccess.open(WRITE)` truncates the file before writing, creating a window where the file is empty.

### Shadow Backup: JSON File (`user://savegame.bak`)

On every `save_to_disk()`, before writing the new save file:
1. If `savegame.json` exists, copy it to `savegame.bak`
2. Then write the new data using the atomic write pattern above

On `load_or_create()`:
1. Try to load `savegame.json`
2. If JSON parse fails, try to load `savegame.bak`
3. If both fail, create fresh defaults

This provides one-previous-known-good recovery without depending on SQLite.

**Why shadow JSON over SQLite**: The previous implementation used `OS.execute("sqlite3", ...)` to write a redundant snapshot, but `sqlite3` is not accessible to Android apps (it exists only in the ADB/root shell). The SQLite snapshot was non-functional on the target platform. A shadow JSON file provides equivalent recovery with zero platform dependency.

### Autoload Initialization Order (MANDATORY)

`AppState._ready()` depends on `ContentService` data (task rules, growth rules) via `_reset_task_targets_from_rules()`. Therefore, the autoload order in `project.godot` MUST be:

```
ContentService → AppState → BackupService → DatabaseService
```

**Note**: `DatabaseService` (SQLite) is retained for potential future GDExtension-based SQLite support, but is currently best-effort and non-functional on Android. It MUST NOT be depended on for any load-time data recovery.

### Backup/Export: ZIP (`user://shuyi_playland_backup.zip`)

`BackupService` creates a ZIP archive containing:
1. `save_data.json` — full serialized save data
2. `version.txt` — app version string
3. `checksum.txt` — SHA-256 hash of the save data JSON (for integrity validation)

Import validates required sections and checksum before restoring.

**Checksum upgrade**: The previous implementation used character count as a checksum, which cannot detect corruption — only truncation. The new implementation uses `JSON.stringify(save_data).hash()` (32-bit integer hash from Godot's String.hash()) for meaningful integrity validation.

### Schema Evolution: Deep Merge

On load, imported data is deep-merged with defaults via `_merge_defaults()`:
- Each top-level section is merged individually
- Incoming values override defaults
- Missing sections fall back to defaults
- New keys added in app updates automatically appear via defaults

This eliminates the need for explicit schema versioning — the default data acts as the schema.

### Architecture Diagram

```
┌─────────────┐  state changes  ┌──────────────┐
│  App Code   │ ──────────────→ │  AppState.gd  │
│  (screens) │                 │ (in-memory     │
└─────────────┘                │  Dictionary)   │
                               └───────┬───────┘
                                       │ save_to_disk()
                          ┌─────────────┴─────────────┐
                          │                             │
                ┌─────────▼─────────┐     ┌────────────▼────────────┐
                │  JSON File         │     │  Shadow Backup            │
                │  (primary)         │     │  (previous known-good)   │
                │  user://savegame   │     │  user://savegame.bak     │
                └─────────┬─────────┘     └──────────────────────────┘
                          │
                ┌─────────▼──────────┐
                │  BackupService     │
                │  (ZIP export/import)│
                │  user://backup.zip  │
                └────────────────────┘
```

### Key Interfaces

**AppState (source of truth)**:
- `save_data: Dictionary` — single in-memory state
- `save_to_disk()` — writes JSON using atomic write pattern, then updates shadow backup
- `load_or_create()` — loads JSON; falls back to shadow backup; then to defaults
- `state_changed` signal — emitted after every mutation

**BackupService (export/import)**:
- `export_backup()` → Dictionary with ok/path/message
- `import_backup()` → Dictionary with ok/message
- Validates: required sections, hash-based checksum

**ContentService (read-only)**:
- Loads JSON content at `_ready()`, never writes
- Provides query methods for grades, modules, levels, questions
- `evaluate_answer()` and `calculate_result()` are pure functions

**DatabaseService (retained, best-effort)**:
- Currently non-functional on Android (sqlite3 binary not accessible)
- Retained for potential future GDExtension-based SQLite support
- MUST NOT be depended on for primary or backup data recovery

## Alternatives Considered

### Alternative 1: SQLite-Only
- **Description**: All player data in SQLite. JSON only for import/export.
- **Pros**: Faster queries, atomic transactions, built-in data integrity
- **Cons**: Requires schema migration for every data change; harder to debug (binary file); requires a GDExtension module for reliable Android support; schema migration code adds maintenance complexity for a small data set
- **Rejection Reason**: The data set is small (~10–50KB). JSON is human-readable, debuggable, and self-migrating via `_merge_defaults()`. SQLite's advantages don't outweigh the migration and dependency complexity for this scale.

### Alternative 2: JSON-Only (No Redundancy)
- **Description**: Only the primary JSON file, no backup mechanism.
- **Pros**: Simplest possible architecture, minimum I/O on every save
- **Cons**: If JSON corrupts on write, player loses all progress with no recovery path
- **Rejection Reason**: A shadow backup file costs nearly nothing (one file copy per save) and provides a meaningful recovery path. The I/O cost is negligible for a 10–50KB file.

### Alternative 3: JSON + SQLite via OS.execute (Previous Implementation)
- **Description**: JSON primary + SQLite redundant snapshot via `OS.execute("sqlite3", ...)`
- **Pros**: Queryable backup, familiar SQL interface
- **Cons**: sqlite3 binary is not accessible to Android apps (only available via ADB/root); `OS.execute()` spawns a shell process per SQL statement (25+ processes per save); SQL injection surface via string concatenation; doubles I/O for no functional benefit on the target platform
- **Rejection Reason**: DatabaseService was non-functional on Android, making the "redundant recovery" claim false. Replacing with shadow JSON backup provides equivalent recovery with zero platform dependency.

## Consequences

### Positive
- Human-readable save files make debugging and manual testing easy
- `_merge_defaults()` eliminates explicit schema migration — new fields appear automatically
- Shadow JSON backup provides recovery from corrupt primary file without SQLite dependency
- Atomic write pattern eliminates the data corruption window on Android process killing
- Hash-based checksum detects data corruption in backups, not just truncation
- Content data (questions, rules) is completely separate from player data — no risk of user data corrupting game content
- Autoload initialization order guarantees ContentService data is available when AppState needs it

### Negative
- Shadow backup is one-previous-known-good only — if both files are corrupt, defaults are used
- Hash checksum is 32-bit (`String.hash()`), not cryptographically secure — but sufficient for corruption detection in an offline app
- DatabaseService code remains in the codebase as best-effort but is effectively dead code on Android

### Risks
- **JSON corruption on interrupted write (previous)**: MITIGATED by atomic write pattern (write-to-temp-rename)
- **Both primary and shadow backup corrupt**: Mitigated by `_merge_defaults()` — partial data merges with defaults; also mitigated by ZIP backup export which provides an out-of-band recovery path
- **Backup ZIP growing large**: Current data is ~10–50KB. No practical risk at this scale.
- **Concurrent access**: Not a concern — single-user, single-process app. No mutex needed.
- **Autoload order regression**: If autoload order changes in project.godot, `AppState._ready()` could call `ContentService` before it's initialized. Mitigated by documenting the mandatory order in this ADR and adding a runtime assert in `AppState._ready()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| persistence-system.md | Save triggers on every state-changing action | `save_to_disk()` is called after every mutation in AppState |
| persistence-system.md | JSON file as single source of truth | JSON is primary; shadow backup is previous-known-good |
| persistence-system.md | Backup export/import with validation | BackupService creates ZIP with JSON + version + hash checksum |
| persistence-system.md | Merge defaults on load for schema evolution | `_merge_defaults()` deep-merges incoming data with defaults |
| persistence-system.md | Fall back to defaults on corrupt/missing save | `load_or_create()` tries JSON, then shadow backup, then defaults |
| content-system.md | Content data is read-only at runtime | ContentService loads JSON at `_ready()`, never writes |
| growth-system.md | Task targets synced from content rules on load | `_reset_task_targets_from_rules()` called after ContentService is initialized (autoload order guarantee) |

## Performance Implications
- **CPU**: Negligible — JSON serialization of ~10–50KB is sub-millisecond on any Android device
- **Memory**: ~50KB for in-memory `save_data` Dictionary — well within budget
- **I/O per save**: Two file writes (shadow backup + atomic write) — both ~10–50KB, negligible
- **Load Time**: Sub-millisecond JSON parse + merge on every startup
- **Network**: None — fully offline

## Migration Plan

This ADR documents and corrects the existing architecture. The following code changes are required:

1. **Implement atomic write pattern**: Modify `AppState.save_to_disk()` to write to `savegame.tmp`, then rename to `savegame.json`. Remove direct overwrite.

2. **Add shadow backup logic**: Before atomic write, copy existing `savegame.json` to `savegame.bak`. On load, try `savegame.json` first, then `savegame.bak`, then defaults.

3. **Fix autoload initialization order**: In `project.godot`, move `ContentService` before `AppState`. This ensures `ContentService._ready()` runs before `AppState._ready()` calls `ContentService.get_task_rules()`.

4. **Upgrade backup checksum**: Replace `str(payload_text.length())` with `str(JSON.stringify(save_data).hash())` in BackupService.

5. **Fix version string in default save data**: Change `"app_version": "0.5.0-expanded"` to read from ProjectSettings at runtime: `ProjectSettings.get_setting("application/config/version")`.

6. **DatabaseService status**: Deprecate and schedule for removal. The `OS.execute("sqlite3", ...)` approach is non-functional on Android (sqlite3 binary not accessible to apps). Shadow JSON backup provides equivalent recovery. Remove `DatabaseService` from autoloads and delete the file in a future cleanup pass. Do not add any new code depending on SQLite.

## Validation Criteria
- [ ] `AppState.save_to_disk()` uses atomic write pattern (write to temp, then rename)
- [ ] Shadow backup (`savegame.bak`) is created before every save
- [ ] `load_or_create()` tries primary JSON, then shadow backup, then defaults
- [ ] Autoload order in `project.godot` is ContentService → AppState → BackupService → DatabaseService
- [ ] `AppState._ready()` can successfully call `ContentService.get_task_rules()` at startup
- [ ] `BackupService.export_backup()` creates a valid ZIP with JSON + version + hash checksum
- [ ] `BackupService.import_backup()` validates required sections and hash checksum before restoring
- [ ] App functions correctly if primary JSON is corrupt (falls back to shadow backup)
- [ ] App functions correctly if both primary and shadow backup are corrupt (falls back to defaults)
- [ ] Version string in default save data reads from ProjectSettings, not hardcoded

## Related Decisions
- ADR-0003 (Autoload Singleton Pattern) — AppState and BackupService are autoloads defined by that ADR; initialization order is mandated here
- ADR-0004 (JSON Content Pipeline) — Content data uses the same JSON approach but is read-only