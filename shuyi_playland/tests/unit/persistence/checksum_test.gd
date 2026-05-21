extends GdUnitTestSuite

## Unit tests for backup checksum upgrade (ADR-0001, S1-03).
## Verifies String.hash() is used — NOT character count.


const ZIP_EXPORT_PATH := "user://shuyi_playland_backup.zip"
const JSON_EXPORT_PATH := "user://backup_payload.json"


func after_test() -> void:
	for path in [ZIP_EXPORT_PATH, JSON_EXPORT_PATH, "user://import_payload.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_export_backup_checksum_is_string_hash_not_length() -> void:
	# The checksum must be String.hash() of the serialized save_data — NOT its length.
	# Note: the hash is computed over the round-tripped form (stringify → parse → stringify)
	# so it survives a JSON round-trip in the importer. See BackupService.export_backup().
	var result: Dictionary = BackupService.export_backup()
	# export_backup() must succeed
	assert_bool(bool(result.get("ok", false))).is_true()
	# Read the exported JSON to inspect the checksum_hint field
	# backup_payload.json must exist
	assert_bool(FileAccess.file_exists(JSON_EXPORT_PATH)).is_true()
	var file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	# backup_payload.json must be valid JSON
	assert_bool(parsed is Dictionary).is_true()
	var checksum_hint: String = str(parsed.get("checksum_hint", ""))
	# Compute expected hash via the same round-trip BackupService uses
	var raw_text: String = JSON.stringify(AppState.save_data)
	var roundtripped: Variant = JSON.parse_string(raw_text)
	var expected_payload: String = JSON.stringify(roundtripped)
	var expected_hash: String = str(expected_payload.hash())
	# checksum_hint must equal String.hash() of round-tripped serialized save_data
	assert_str(checksum_hint).is_equal(expected_hash)


func test_export_backup_checksum_is_not_character_count() -> void:
	# Regression guard: checksum must NOT be the character count.
	var result: Dictionary = BackupService.export_backup()
	# export_backup() must succeed
	assert_bool(bool(result.get("ok", false))).is_true()
	var file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var checksum_hint: String = str(parsed.get("checksum_hint", ""))
	var payload_text: String = JSON.stringify(AppState.save_data)
	var char_count: String = str(payload_text.length())
	# If the checksum equals the character count, the old algorithm is still in use.
	# (They could theoretically collide, but String.hash() of a typical save is a large
	# negative or positive 32-bit integer, not a small positive decimal like a char count.)
	# checksum_hint must NOT be the character count — String.hash() must be used
	assert_str(checksum_hint).is_not_equal(char_count)


func test_import_backup_accepts_valid_hash_checksum() -> void:
	# Export a backup, then import it — must succeed with the new hash-based checksum.
	BackupService.export_backup()
	var result: Dictionary = BackupService.import_backup()
	# import_backup() must succeed when checksum matches
	assert_bool(bool(result.get("ok", false))).is_true()


func test_import_backup_rejects_tampered_checksum() -> void:
	# Export a backup, then manually corrupt the checksum_hint — import must fail.
	BackupService.export_backup()
	# Read and tamper with the JSON payload
	var file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	# backup_payload.json must be valid JSON
	assert_bool(parsed is Dictionary).is_true()
	parsed["checksum_hint"] = "99999999"  # wrong hash
	var tampered_file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.WRITE)
	tampered_file.store_string(JSON.stringify(parsed))
	tampered_file.close()
	var result: Dictionary = BackupService._import_json_payload(JSON_EXPORT_PATH)
	# import must fail when checksum_hint is tampered
	assert_bool(bool(result.get("ok", true))).is_false()


func test_import_backup_rejects_old_length_based_checksum() -> void:
	# A backup created with the old algorithm (character count) must be rejected.
	# This is the key regression test for S1-03.
	BackupService.export_backup()
	var file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	# Replace checksum_hint with the old character-count value
	var payload_text: String = JSON.stringify(parsed.get("save_data", {}))
	parsed["checksum_hint"] = str(payload_text.length())
	var old_checksum_file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.WRITE)
	old_checksum_file.store_string(JSON.stringify(parsed))
	old_checksum_file.close()
	var result: Dictionary = BackupService._import_json_payload(JSON_EXPORT_PATH)
	# import must reject a backup with the old character-count checksum
	assert_bool(bool(result.get("ok", true))).is_false()
