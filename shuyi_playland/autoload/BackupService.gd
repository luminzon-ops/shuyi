extends Node

const JSON_EXPORT_PATH := "user://backup_payload.json"
const ZIP_EXPORT_PATH := "user://shuyi_playland_backup.zip"
const DB_EXPORT_PATH := "user://backup_runtime.db"


func export_backup() -> Dictionary:
	var payload_text: String = JSON.stringify(AppState.save_data)
	var payload: Dictionary = {
		"exported_at": Time.get_datetime_string_from_system(),
		"version": AppState.get_save_overview().get("version", "0.5.0-expanded"),
		"save_overview": AppState.get_save_overview(),
		"save_data": AppState.save_data,
		"checksum_hint": str(payload_text.length()),
		"required_sections": ["profile", "settings", "progress", "tasks", "wrong_book", "answer_history", "achievements", "meta"]
	}
	var file: FileAccess = FileAccess.open(JSON_EXPORT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))
	DatabaseService.export_database_copy(DB_EXPORT_PATH)
	var zip: ZIPPacker = ZIPPacker.new()
	var opened: Error = zip.open(ProjectSettings.globalize_path(ZIP_EXPORT_PATH))
	if opened != OK:
		return {"ok": false, "message": "无法创建 ZIP 备份文件。"}
	zip.start_file("save_data.json")
	zip.write_file(JSON.stringify(payload, "\t").to_utf8_buffer())
	zip.close_file()
	if FileAccess.file_exists(DB_EXPORT_PATH):
		var db_file: FileAccess = FileAccess.open(DB_EXPORT_PATH, FileAccess.READ)
		zip.start_file("runtime.db")
		zip.write_file(db_file.get_buffer(db_file.get_length()))
		zip.close_file()
	zip.start_file("version.txt")
	zip.write_file(str(payload.get("version", "0.5.0-expanded")).to_utf8_buffer())
	zip.close_file()
	zip.start_file("checksum.txt")
	zip.write_file(str(payload.get("checksum_hint", "0")).to_utf8_buffer())
	zip.close_file()
	zip.close()
	return {"ok": true, "path": ZIP_EXPORT_PATH, "message": "已导出 ZIP 备份到 user://shuyi_playland_backup.zip"}


func import_backup() -> Dictionary:
	if not FileAccess.file_exists(ZIP_EXPORT_PATH):
		if FileAccess.file_exists(JSON_EXPORT_PATH):
			return _import_json_payload(JSON_EXPORT_PATH)
		return {"ok": false, "message": "未找到可导入的备份文件。"}
	var reader: ZIPReader = ZIPReader.new()
	var opened: Error = reader.open(ProjectSettings.globalize_path(ZIP_EXPORT_PATH))
	if opened != OK:
		return {"ok": false, "message": "ZIP 备份文件无法打开。"}
	if reader.file_exists("save_data.json"):
		var json_buffer: PackedByteArray = reader.read_file("save_data.json")
		var temp_json_path: String = "user://import_payload.json"
		var temp_file: FileAccess = FileAccess.open(temp_json_path, FileAccess.WRITE)
		temp_file.store_buffer(json_buffer)
		var result: Dictionary = _import_json_payload(temp_json_path)
		if reader.file_exists("runtime.db"):
			var db_buffer: PackedByteArray = reader.read_file("runtime.db")
			var temp_db_file: FileAccess = FileAccess.open(DB_EXPORT_PATH, FileAccess.WRITE)
			temp_db_file.store_buffer(db_buffer)
			DatabaseService.import_database_copy(DB_EXPORT_PATH)
		reader.close()
		return result
	reader.close()
	return {"ok": false, "message": "备份文件结构无效。"}


func _import_json_payload(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("save_data"):
		for section in parsed.get("required_sections", []):
			if not parsed["save_data"].has(section):
				return {"ok": false, "message": "备份缺少关键结构：%s" % section}
		if str(JSON.stringify(parsed["save_data"]).length()) != str(parsed.get("checksum_hint", "")):
			return {"ok": false, "message": "备份校验失败，数据长度不匹配。"}
		AppState.save_data = AppState._merge_defaults(parsed["save_data"])
		AppState.save_to_disk()
		AppState.state_changed.emit()
		return {"ok": true, "message": "备份导入成功。"}
	return {"ok": false, "message": "备份文件结构无效。"}
