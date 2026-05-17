extends Node

const DB_PATH := "user://shuyi_playland_runtime.db"
const SQLITE_EXE := "sqlite3"


func _ready() -> void:
	initialize_database()


func initialize_database() -> void:
	_ensure_tables()
	write_snapshot(AppState.save_data)


func _ensure_tables() -> void:
	_run_sql_batch([
		"CREATE TABLE IF NOT EXISTS profile (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS progress (scope TEXT NOT NULL, item_key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(scope, item_key));",
		"CREATE TABLE IF NOT EXISTS wrong_book (question_id TEXT PRIMARY KEY, payload TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS tasks (group_name TEXT NOT NULL, task_id TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(group_name, task_id));",
		"CREATE TABLE IF NOT EXISTS answer_history (history_id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS achievements (achievement_id TEXT PRIMARY KEY, payload TEXT NOT NULL);",
		"CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);"
	])


func write_snapshot(save_data: Dictionary) -> void:
	_ensure_tables()
	_clear_tables()
	_write_key_value_table("profile", save_data.get("profile", {}))
	_write_key_value_table("settings", save_data.get("settings", {}))
	_write_progress(save_data.get("progress", {}))
	_write_tasks(save_data.get("tasks", {}))
	_write_wrong_book(save_data.get("wrong_book", {}))
	_write_answer_history(save_data.get("answer_history", []))
	_write_achievements(save_data.get("achievements", {}))
	_write_key_value_table("meta", save_data.get("meta", {}))


func export_database_copy(target_path: String) -> bool:
	if not FileAccess.file_exists(DB_PATH):
		return false
	return DirAccess.copy_absolute(DB_PATH, target_path) == OK


func import_database_copy(source_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	return DirAccess.copy_absolute(source_path, DB_PATH) == OK


func _clear_tables() -> void:
	_run_sql_batch([
		"DELETE FROM profile;",
		"DELETE FROM settings;",
		"DELETE FROM progress;",
		"DELETE FROM wrong_book;",
		"DELETE FROM tasks;",
		"DELETE FROM answer_history;",
		"DELETE FROM achievements;",
		"DELETE FROM meta;"
	])


func _write_key_value_table(table_name: String, payload: Dictionary) -> void:
	for key in payload.keys():
		var encoded_value: String = _sql_escape(JSON.stringify(payload[key]))
		_run_sql("INSERT INTO %s(key, value) VALUES('%s', '%s');" % [table_name, _sql_escape(str(key)), encoded_value])


func _write_progress(progress: Dictionary) -> void:
	for scope in progress.keys():
		var value: Variant = progress[scope]
		if value is Dictionary:
			for item_key in value.keys():
				_run_sql("INSERT INTO progress(scope, item_key, value) VALUES('%s', '%s', '%s');" % [_sql_escape(str(scope)), _sql_escape(str(item_key)), _sql_escape(JSON.stringify(value[item_key]))])
		elif value is Array:
			for index in value.size():
				_run_sql("INSERT INTO progress(scope, item_key, value) VALUES('%s', '%s', '%s');" % [_sql_escape(str(scope)), _sql_escape(str(index)), _sql_escape(JSON.stringify(value[index]))])
		else:
			_run_sql("INSERT INTO progress(scope, item_key, value) VALUES('%s', '%s', '%s');" % [_sql_escape(str(scope)), "value", _sql_escape(JSON.stringify(value))])


func _write_tasks(tasks: Dictionary) -> void:
	for group_name in tasks.keys():
		var task_group: Dictionary = tasks[group_name]
		for task_id in task_group.keys():
			_run_sql("INSERT INTO tasks(group_name, task_id, payload) VALUES('%s', '%s', '%s');" % [_sql_escape(str(group_name)), _sql_escape(str(task_id)), _sql_escape(JSON.stringify(task_group[task_id]))])


func _write_wrong_book(wrong_book: Dictionary) -> void:
	for question_id in wrong_book.keys():
		_run_sql("INSERT INTO wrong_book(question_id, payload) VALUES('%s', '%s');" % [_sql_escape(str(question_id)), _sql_escape(JSON.stringify(wrong_book[question_id]))])


func _write_answer_history(history: Array) -> void:
	for entry in history:
		_run_sql("INSERT INTO answer_history(payload) VALUES('%s');" % _sql_escape(JSON.stringify(entry)))


func _write_achievements(achievements: Dictionary) -> void:
	for achievement_id in achievements.keys():
		_run_sql("INSERT INTO achievements(achievement_id, payload) VALUES('%s', '%s');" % [_sql_escape(str(achievement_id)), _sql_escape(JSON.stringify(achievements[achievement_id]))])


func _run_sql_batch(statements: Array) -> void:
	for statement in statements:
		_run_sql(str(statement))


func _run_sql(statement: String) -> void:
	OS.execute(SQLITE_EXE, [ProjectSettings.globalize_path(DB_PATH), statement], [])


func _sql_escape(value: String) -> String:
	return value.replace("'", "''")
