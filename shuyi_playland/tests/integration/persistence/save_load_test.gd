extends GdUnitTestSuite

## Integration tests for atomic write + shadow backup (ADR-0001, S1-01).
## Tests save_to_disk(), load_or_create(), and the fallback chain.


const SAVE_PATH := "user://savegame.json"
const SAVE_TMP_PATH := "user://savegame.tmp"
const SAVE_BAK_PATH := "user://savegame.bak"


func after_test() -> void:
	# Clean up test files after each test to avoid cross-test contamination.
	for path in [SAVE_PATH, SAVE_TMP_PATH, SAVE_BAK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_save_to_disk_writes_primary_json() -> void:
	AppState.save_data["profile"] = AppState.save_data.get("profile", {}).duplicate()
	AppState.save_data["profile"]["nickname"] = "test_atomic"
	AppState.save_to_disk()
	# savegame.json must exist after save_to_disk()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()


func test_save_to_disk_no_tmp_file_remains() -> void:
	# After a successful save, the .tmp file must be gone (renamed to .json).
	AppState.save_to_disk()
	# savegame.tmp must not exist after successful save — it was renamed to .json
	assert_bool(FileAccess.file_exists(SAVE_TMP_PATH)).is_false()


func test_save_to_disk_creates_shadow_backup() -> void:
	# First save creates .json. Second save must create .bak from the first .json.
	AppState.save_to_disk()
	# First save must create .json
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	AppState.save_to_disk()
	# Second save must create .bak from the previous .json
	assert_bool(FileAccess.file_exists(SAVE_BAK_PATH)).is_true()


func test_save_to_disk_bak_contains_previous_data() -> void:
	# .bak must contain the data from before the current save, not the current save.
	AppState.save_data["profile"]["nickname"] = "before_save"
	AppState.save_to_disk()
	AppState.save_data["profile"]["nickname"] = "after_save"
	AppState.save_to_disk()
	# .bak should contain "before_save"
	var bak_file: FileAccess = FileAccess.open(SAVE_BAK_PATH, FileAccess.READ)
	var bak_parsed: Variant = JSON.parse_string(bak_file.get_as_text())
	# .bak must be valid JSON
	assert_bool(bak_parsed is Dictionary).is_true()
	# .bak must contain the data from before the current save
	assert_str(str(bak_parsed.get("profile", {}).get("nickname", ""))).is_equal("before_save")


func test_load_or_create_loads_primary_when_valid() -> void:
	# Write a known-good primary file, then load it.
	var test_data: Dictionary = AppState.default_save_data()
	test_data["profile"]["nickname"] = "primary_load_test"
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(test_data))
	file.close()
	AppState.load_or_create()
	# load_or_create() must load from primary JSON when it exists and is valid
	assert_str(str(AppState.get_profile().get("nickname", ""))).is_equal("primary_load_test")


func test_load_or_create_falls_back_to_bak_when_primary_corrupt() -> void:
	# Write corrupt primary, valid backup — must load from backup.
	var bak_data: Dictionary = AppState.default_save_data()
	bak_data["profile"]["nickname"] = "from_backup"
	var bak_file: FileAccess = FileAccess.open(SAVE_BAK_PATH, FileAccess.WRITE)
	bak_file.store_string(JSON.stringify(bak_data))
	bak_file.close()
	var corrupt_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	corrupt_file.store_string("{ this is not valid json }")
	corrupt_file.close()
	AppState.load_or_create()
	# load_or_create() must fall back to .bak when primary JSON is corrupt
	assert_str(str(AppState.get_profile().get("nickname", ""))).is_equal("from_backup")


func test_load_or_create_falls_back_to_defaults_when_both_corrupt() -> void:
	# Both files corrupt — must use defaults without crashing.
	for path in [SAVE_PATH, SAVE_BAK_PATH]:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string("not json")
		f.close()
	AppState.load_or_create()
	# Default nickname is "小园探险家"
	# load_or_create() must use defaults when both primary and backup are corrupt
	assert_str(str(AppState.get_profile().get("nickname", ""))).is_equal("小园探险家")


func test_load_or_create_falls_back_to_defaults_when_no_files_exist() -> void:
	# No files at all — must use defaults without crashing.
	AppState.load_or_create()
	# load_or_create() must produce non-empty save_data when no files exist
	assert_bool(AppState.save_data.is_empty()).is_false()
	# Default save_data must have 'profile' key
	assert_bool(AppState.save_data.has("profile")).is_true()
