---
status: reverse-documented
source: shuyi_playland/autoload/AppState.gd + autoload/BackupService.gd
date: 2026-05-18
revised: 2026-05-19
revision-note: SQLite Snapshot section replaced with Shadow Backup to match ADR-0001 (DatabaseService is non-functional on Android and scheduled for removal). Version string sourced from ProjectSettings, not hardcoded. Dependencies line on SQLite removed.
verified-by: user
---

# Persistence System Design

## Overview

The persistence system handles all data storage for the app: save/load via JSON (`AppState`), shadow-backup recovery for corruption resilience, and backup/export via ZIP (`BackupService`). It operates fully offline with no cloud dependency. JSON is the single source of truth — see ADR-0001 for the full architectural decision.

## Player Fantasy

The student's progress is always safe — automatic saves on every action, full backup/export for device transfers, and import to restore from any backup. Nothing is lost.

## Detailed Rules

### Save Data Structure

`AppState` manages a single `save_data: Dictionary` with these top-level keys:

| Key | Type | Content |
|-----|------|---------|
| `profile` | Dictionary | nickname, level, exp, gold, streak_days, last_sign_in, weekly_progress, total_correct_answers, levels_completed_count, study_minutes |
| `settings` | Dictionary | sound_enabled, animation_enabled, eye_care_enabled, eye_care_minutes |
| `progress` | Dictionary | unlocked_levels (Array), completed_levels (Dict), recent_level_id (String) |
| `tasks` | Dictionary | daily (Dict), weekly (Dict) — each keyed by task_id |
| `wrong_book` | Dictionary | keyed by question_id: {first_wrong_time, last_wrong_time, wrong_count, last_answer, mastered} |
| `answer_history` | Array | last 200 answer records: {question_id, correct, answer, time} |
| `achievements` | Dictionary | keyed by achievement_id: {unlocked, claimed, progress, title, description} |
| `meta` | Dictionary | app_version, last_mode, eye_care_tip |

### Save Triggers

Save is written to disk (`user://savegame.json`) after every state-changing action:
- `record_answer()` — every question answered
- `mark_sign_in()` — daily sign-in
- `complete_session()` — session completion
- `claim_task()` — task reward claimed
- `claim_achievement()` — achievement reward claimed
- `mark_wrong_question_mastered()` — wrong question mastered
- `update_setting()` — any setting changed

Writes use the **atomic write pattern** (write to `savegame.tmp`, then rename to `savegame.json`) to prevent corruption from Android process killing mid-write. See ADR-0001 for the full rationale.

### Merge Strategy

On load, incoming save data is deep-merged with defaults via `_merge_defaults()`:
- Each top-level section is merged individually
- Incoming values override defaults
- Missing sections fall back to defaults
- New keys added in updates (not in old saves) are preserved via defaults

### Shadow Backup

Before each `save_to_disk()` writes the new JSON, `BackupService` copies the current `savegame.json` to `savegame.bak` (one-previous-known-good). On load, the recovery chain is:

1. Try to parse `savegame.json` → use it if valid
2. Fall back to `savegame.bak` → use it if valid
3. Fall back to `default_save_data()` → fresh install state

This replaces the previous SQLite snapshot mechanism, which was non-functional on Android (the `sqlite3` binary is not accessible to apps). See ADR-0001 for the full architectural decision and the rationale for not using SQLite. `DatabaseService.gd` remains in the codebase as best-effort dead code pending removal.

### Backup/Export

`BackupService.export_backup()`:
1. Serializes all save data to JSON
2. Writes `user://backup_payload.json`
3. Creates ZIP archive (`user://shuyi_playland_backup.zip`) containing:
   - `save_data.json` — full save data
   - `version.txt` — app version string (read from `ProjectSettings`)
   - `checksum.txt` — `JSON.stringify(save_data).hash()` (32-bit hash) for integrity validation

`BackupService.import_backup()`:
1. Opens ZIP archive
2. Reads `save_data.json` and validates:
   - All `required_sections` are present
   - `checksum_hint` matches `JSON.stringify(save_data).hash()`
3. Merges imported data with defaults (`_merge_defaults()`)
4. Writes merged data to `AppState`
5. Emits `state_changed` signal

### Default Values

On fresh install (no save file), `AppState.default_save_data()` provides:
- Profile: nickname "小园探险家", level 1, exp 0, gold 120, streak 0
- Settings: sound on, animation on, eye_care on, 20-min interval
- Progress: only `level_grade1_addition_1` unlocked
- Tasks: empty daily/weekly
- Wrong book: empty
- Achievements: empty
- Meta: app version read at runtime from `ProjectSettings.get_setting("application/config/version")`

## Formulas

- **Answer history cap**: `min(history_size, 200)` — oldest entries sliced off
- **Checksum validation**: `JSON.stringify(save_data).hash() == checksum_hint` (32-bit hash)
- **Task target sync**: On load, task targets are overwritten from `task_rules.json` (allows tuning without version migration)

## Edge Cases

- **Corrupt save file**: If `JSON.parse_string()` returns non-Dictionary, falls back to `savegame.bak`; if that also fails, falls back to defaults
- **Missing save file**: Creates fresh defaults
- **Missing content files**: ContentService returns `[]`, never crashes
- **Import with missing sections**: Returns error identifying which section is missing
- **Import with checksum mismatch**: Returns error "备份校验失败，数据校验不匹配"
- **Interrupted write**: Atomic write pattern (write to `savegame.tmp`, then rename) prevents truncation; the previous `savegame.json` remains intact if the write is killed mid-flight
- **Task data without matching rules**: Defaults from `_merge_defaults()` ensure structure integrity

## Dependencies

- ContentService (task rules, growth rules for task target sync on load)
- Godot `FileAccess` API (JSON read/write)
- Godot `DirAccess` API (atomic rename, shadow backup copy)
- Godot `ZIPPacker`/`ZIPReader` API (backup export/import)
- Admin backend (produces JSON content files that the app reads, but not part of runtime persistence)

## Tuning Knobs

| Knob | Current Value | Location |
|------|---------------|----------|
| Starting gold | 120 | `AppState.default_save_data()` |
| Starting level | 1 | `AppState.default_save_data()` |
| Answer history cap | 200 | `AppState.record_answer()` |
| Eye-care default interval | 20 min | `AppState.default_save_data()` |
| Default nickname | "小园探险家" | `AppState.default_save_data()` |

## Acceptance Criteria

- [ ] Fresh install creates default save data with correct starting values
- [ ] App version in default save data is read from ProjectSettings, not hardcoded
- [ ] Every state-changing action triggers `save_to_disk()`
- [ ] `save_to_disk()` uses atomic write (write to `savegame.tmp`, then rename)
- [ ] Shadow backup (`savegame.bak`) is created before each save
- [ ] Load merges old save with new defaults without data loss
- [ ] Load fallback chain: primary → shadow backup → defaults
- [ ] Backup export creates valid ZIP with `save_data.json`, `version.txt`, `checksum.txt`
- [ ] Backup import validates required sections and hash-based checksum
- [ ] Corrupt or missing save files fall back gracefully (no crash)
- [ ] Import with missing sections returns a clear error message