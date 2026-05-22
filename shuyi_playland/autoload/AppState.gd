extends Node

signal state_changed
signal level_up(new_level: int)  ## ADR-0011 Migration step 6: emitted by _check_level_up() when level increases; consumed by app.gd to drive level-up SFX/animation

const SAVE_PATH := "user://savegame.json"
const SAVE_TMP_PATH := "user://savegame.tmp"
const SAVE_BAK_PATH := "user://savegame.bak"

var save_data: Dictionary = {}


func _ready() -> void:
	# Autoload order guard: ContentService must initialize before AppState.
	# If this fires, check project.godot [autoload] — ContentService must be listed first.
	assert(ContentService.content.size() > 0, "AppState._ready(): ContentService.content is empty — autoload order violation. ContentService must be listed before AppState in project.godot.")
	load_or_create()


func load_or_create() -> void:
	## Load fallback chain (ADR-0001): primary JSON → shadow backup → fresh defaults.
	var loaded: Dictionary = _try_load_json(SAVE_PATH)
	if loaded.is_empty():
		loaded = _try_load_json(SAVE_BAK_PATH)
	if loaded.is_empty():
		save_data = default_save_data()
	else:
		save_data = _merge_defaults(loaded)
	_reset_task_targets_from_rules()
	save_to_disk()
	state_changed.emit()


func _try_load_json(path: String) -> Dictionary:
	## Attempts to load and parse a JSON save file. Returns empty dict on any failure.
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func default_save_data() -> Dictionary:
	return {
		"profile": {
			"nickname": "小园探险家",
			"level": 1,
			"exp": 0,
			"gold": 120,
			"streak_days": 0,
			"last_sign_in": "",
			"weekly_progress": 0,
			"total_correct_answers": 0,
			"levels_completed_count": 0,
			"study_minutes": 0
		},
		"settings": {
			"sound_enabled": true,
			"animation_enabled": true,
			"eye_care_enabled": true,
			"eye_care_minutes": 20
		},
		"progress": {
			"unlocked_levels": ["level_grade1_addition_1"],
			"completed_levels": {},
			"recent_level_id": "level_grade1_addition_1"
		},
		"tasks": {
			"daily": {},
			"weekly": {}
		},
		"wrong_book": {},
		"answer_history": [],
		"achievements": {},
		"meta": {
			"app_version": "0.5.0-expanded",
			"last_mode": "level",
			"eye_care_tip": "每学习 20 分钟记得休息并看看远方。"
		}
	}


func _merge_defaults(incoming: Dictionary) -> Dictionary:
	var merged: Dictionary = default_save_data()
	for section in incoming.keys():
		if merged.has(section) and merged[section] is Dictionary and incoming[section] is Dictionary:
			var section_defaults: Dictionary = merged[section].duplicate(true)
			section_defaults.merge(incoming[section], true)
			merged[section] = section_defaults
		else:
			merged[section] = incoming[section]
	return merged


func _reset_task_targets_from_rules() -> void:
	var task_rules: Dictionary = ContentService.get_task_rules()
	var all_tasks: Dictionary = save_data.get("tasks", {})
	for group_name in ["daily", "weekly"]:
		var current_group: Dictionary = all_tasks.get(group_name, {})
		for rule in task_rules.get(group_name, []):
			var task_id: String = str(rule.get("id", ""))
			var current: Dictionary = current_group.get(task_id, {"progress": 0, "claimed": false})
			current["target"] = int(rule.get("target", 0))
			current["label"] = rule.get("label", task_id)
			current["reward"] = rule.get("reward", {"exp": 0, "gold": 0})
			current_group[task_id] = current
		all_tasks[group_name] = current_group
	save_data["tasks"] = all_tasks


func save_to_disk() -> void:
	## Atomic write pattern (ADR-0001): write to .tmp, shadow-backup current .json, rename .tmp → .json.
	## Prevents data corruption if the process is killed mid-write on Android.
	var json_text: String = JSON.stringify(save_data, "\t")
	# Step 1: write new data to temp file
	var tmp_file: FileAccess = FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	tmp_file.store_string(json_text)
	tmp_file.close()
	# Step 2: shadow backup — copy current primary to .bak (one-previous-known-good)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_BAK_PATH)
	# Step 3: atomic rename — .tmp becomes the new primary
	DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)


func get_profile() -> Dictionary:
	return save_data.get("profile", {})


func get_settings() -> Dictionary:
	return save_data.get("settings", {})


func get_task_summary() -> Dictionary:
	return save_data.get("tasks", {})


func get_achievements() -> Dictionary:
	return save_data.get("achievements", {})


func is_level_unlocked(level_id: String) -> bool:
	var unlocked: Array = save_data.get("progress", {}).get("unlocked_levels", [])
	return unlocked.has(level_id)


func get_recent_level_id() -> String:
	return save_data.get("progress", {}).get("recent_level_id", "")


func get_level_record(level_id: String) -> Dictionary:
	return save_data.get("progress", {}).get("completed_levels", {}).get(level_id, {})


func get_wrong_book_entries() -> Array:
	var entries: Array = save_data.get("wrong_book", {}).values()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("last_wrong_time", "") > b.get("last_wrong_time", ""))
	return entries


func mark_sign_in() -> Dictionary:
	var today: String = Time.get_date_string_from_system()
	if get_profile().get("last_sign_in", "") == today:
		return {"ok": false, "message": "今天已经签到过啦，继续闯关吧！"}
	var growth: Dictionary = ContentService.get_growth_rules()
	_update_streak_and_weekly(today)
	# Re-read profile after _update_streak_and_weekly() has written streak/weekly changes.
	var profile: Dictionary = get_profile()
	profile["last_sign_in"] = today
	save_data["profile"] = profile
	_apply_reward({"exp": int(growth.get("sign_in_exp", 10)), "gold": int(growth.get("sign_in_gold", 15))})
	_evaluate_achievements()
	save_to_disk()
	state_changed.emit()
	return {"ok": true, "message": "签到成功，获得 %d EXP 与 %d 金币！" % [int(growth.get("sign_in_exp", 10)), int(growth.get("sign_in_gold", 15))]}


func update_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = get_settings()
	settings[key] = value
	save_data["settings"] = settings
	save_to_disk()
	state_changed.emit()


func claim_task(group_name: String, task_id: String) -> Dictionary:
	var tasks: Dictionary = get_task_summary().get(group_name, {})
	if not tasks.has(task_id):
		return {"ok": false, "message": "任务不存在。"}
	var task_data: Dictionary = tasks[task_id]
	if bool(task_data.get("claimed", false)):
		return {"ok": false, "message": "奖励已经领取过了。"}
	if int(task_data.get("progress", 0)) < int(task_data.get("target", 0)):
		return {"ok": false, "message": "任务尚未完成。"}
	task_data["claimed"] = true
	tasks[task_id] = task_data
	var all_tasks: Dictionary = save_data.get("tasks", {})
	all_tasks[group_name] = tasks
	save_data["tasks"] = all_tasks
	_apply_reward(task_data.get("reward", {}))
	save_to_disk()
	state_changed.emit()
	return {"ok": true, "message": "已领取任务奖励。"}


func record_answer(question_id: String, is_correct: bool, user_answer: String) -> void:
	var history: Array = save_data.get("answer_history", [])
	history.append({
		"question_id": question_id,
		"correct": is_correct,
		"answer": user_answer,
		"time": Time.get_datetime_string_from_system()
	})
	if history.size() > 200:
		history = history.slice(history.size() - 200, history.size())
	save_data["answer_history"] = history
	var profile: Dictionary = get_profile()
	if is_correct:
		profile["total_correct_answers"] = int(profile.get("total_correct_answers", 0)) + 1
		save_data["profile"] = profile
	else:
		_record_wrong_question(question_id, user_answer)
	_evaluate_achievements()
	save_to_disk()
	state_changed.emit()


func _record_wrong_question(question_id: String, user_answer: String) -> void:
	var wrong_book: Dictionary = save_data.get("wrong_book", {})
	var current: Dictionary = wrong_book.get(question_id, {
		"question_id": question_id,
		"first_wrong_time": Time.get_datetime_string_from_system(),
		"last_wrong_time": "",
		"wrong_count": 0,
		"last_answer": "",
		"mastered": false
	})
	current["last_wrong_time"] = Time.get_datetime_string_from_system()
	current["wrong_count"] = int(current.get("wrong_count", 0)) + 1
	current["last_answer"] = user_answer
	current["mastered"] = false
	wrong_book[question_id] = current
	save_data["wrong_book"] = wrong_book


func mark_wrong_question_mastered(question_id: String) -> void:
	var wrong_book: Dictionary = save_data.get("wrong_book", {})
	if wrong_book.has(question_id):
		var current: Dictionary = wrong_book[question_id]
		current["mastered"] = true
		wrong_book[question_id] = current
		save_data["wrong_book"] = wrong_book
		save_to_disk()
		state_changed.emit()


func complete_session(mode: String, level_id: String, correct_count: int, total_count: int, result: Dictionary) -> void:
	var rewards: Dictionary = result.get("reward", {})
	var profile: Dictionary = get_profile()
	profile["levels_completed_count"] = int(profile.get("levels_completed_count", 0)) + (1 if mode in ["level", "special_practice", "wrong_retry", "random_practice", "mock_test"] else 0)
	profile["study_minutes"] = int(profile.get("study_minutes", 0)) + 5
	save_data["profile"] = profile
	_apply_reward(rewards)
	var progress: Dictionary = save_data.get("progress", {})
	if not level_id.is_empty():
		var completed_levels: Dictionary = progress.get("completed_levels", {})
		completed_levels[level_id] = {
			"correct_count": correct_count,
			"total_count": total_count,
			"stars": result.get("stars", 1),
			"completed_at": Time.get_datetime_string_from_system(),
			"mode": mode
		}
		progress["completed_levels"] = completed_levels
		progress["recent_level_id"] = level_id
		var unlocked: Array = progress.get("unlocked_levels", [])
		for next_level_id in ContentService.get_next_level_unlocks(level_id):
			if not unlocked.has(next_level_id):
				unlocked.append(next_level_id)
		progress["unlocked_levels"] = unlocked
	save_data["progress"] = progress
	_update_task_progress("complete_level", 1)
	_update_task_progress("complete_levels", 1, false)
	if mode in ["special_practice", "random_practice"]:
		_update_task_progress("special_practice", 1)
	if mode == "mini_game":
		_update_task_progress("mini_game_clear", 1)
	if mode == "wrong_retry":
		_update_task_progress("wrong_retry_clear", 1, false)
	_update_task_progress("earn_exp", int(rewards.get("exp", 0)), false)
	_evaluate_achievements()
	save_data.get("meta", {})["last_mode"] = mode
	save_to_disk()
	state_changed.emit()


func add_correct_answers(count: int) -> void:
	_update_task_progress("correct_questions", count)
	save_to_disk()
	state_changed.emit()


func get_wrong_question_ids_for_retry(limit: int = 10) -> Array:
	var ids: Array = []
	for entry in get_wrong_book_entries():
		if not entry.get("mastered", false):
			ids.append(entry.get("question_id", ""))
		if ids.size() >= limit:
			break
	return ids


func get_save_overview() -> Dictionary:
	return {
		"profile": get_profile(),
		"wrong_book_count": get_wrong_book_entries().size(),
		"version": save_data.get("meta", {}).get("app_version", "0.5.0-expanded")
	}


func _apply_reward(reward: Dictionary) -> void:
	## Sole EXP mutation path. All EXP gains MUST go through here (ADR-0009).
	## Applies exp + gold, increments weekly_progress, then checks for level-up.
	var profile: Dictionary = get_profile()
	profile["exp"] = int(profile.get("exp", 0)) + int(reward.get("exp", 0))
	profile["gold"] = int(profile.get("gold", 0)) + int(reward.get("gold", 0))
	profile["weekly_progress"] = min(int(profile.get("weekly_progress", 0)) + int(reward.get("exp", 0)), 100)
	save_data["profile"] = profile
	_check_level_up()


func _update_task_progress(task_key: String, amount: int, daily: bool = true) -> void:
	var task_group: String = "daily" if daily else "weekly"
	var tasks: Dictionary = save_data.get("tasks", {}).get(task_group, {})
	if not tasks.has(task_key):
		return
	var task_data: Dictionary = tasks[task_key]
	task_data["progress"] = min(int(task_data.get("progress", 0)) + amount, int(task_data.get("target", 0)))
	tasks[task_key] = task_data
	var all_tasks: Dictionary = save_data.get("tasks", {})
	all_tasks[task_group] = tasks
	save_data["tasks"] = all_tasks


func _increment_weekly_progress(amount: int) -> void:
	var profile: Dictionary = get_profile()
	profile["weekly_progress"] = min(int(profile.get("weekly_progress", 0)) + amount, 100)
	save_data["profile"] = profile


func _check_level_up() -> void:
	## Checks for level-up after every EXP gain. Uses while loop for carry-over (ADR-0009).
	## Reads and writes save_data["profile"] directly — must be called after _apply_reward()
	## has already saved the updated exp to save_data.
	var profile: Dictionary = get_profile()
	var growth: Dictionary = ContentService.get_growth_rules()
	var exp_points: int = int(profile.get("exp", 0))
	var starting_level: int = int(profile.get("level", 1))
	var current_level: int = starting_level
	var curve_base: int = int(growth.get("level_up_curve_base", 100))
	while exp_points >= current_level * curve_base:
		exp_points -= current_level * curve_base
		current_level += 1
	profile["level"] = current_level
	profile["exp"] = exp_points
	save_data["profile"] = profile
	# ADR-0011: emit a level_up signal whenever the level actually increased.
	# Multi-level jumps emit once with the final level — handlers care about the
	# fact of a level-up, not each step. The signal is the contract for the
	# level-up SFX and any UI celebration.
	if current_level > starting_level:
		level_up.emit(current_level)


func _date_to_unix(date: String) -> float:
	## Converts a "YYYY-MM-DD" date string to a Unix timestamp.
	## Appends "T00:00:00" because date-only strings return -1 on Android.
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00")


func _days_between(a: String, b: String) -> int:
	## Returns the number of days between two "YYYY-MM-DD" date strings.
	## Uses roundi() (not int()) to avoid float truncation where 0.9999... would become 0.
	return roundi((_date_to_unix(b) - _date_to_unix(a)) / 86400.0)


func _day_of_year(year: int, month: int, day: int) -> int:
	var days_in_month: Array[int] = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var is_leap: bool = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
	if is_leap:
		days_in_month[2] = 29
	var doy: int = day
	for m: int in range(1, month):
		doy += days_in_month[m]
	return doy


func _iso_weekday_of_jan1(year: int) -> int:
	## Returns ISO weekday of January 1 for the given year: 1=Mon … 7=Sun.
	## Uses Tomohiko Sakamoto algorithm.
	var y: int = year - 1
	var wd: int = (y + y / 4 - y / 100 + y / 400 + 1) % 7  # 0=Sun, 1=Mon … 6=Sat
	return wd if wd != 0 else 7


func _weeks_in_year(year: int) -> int:
	## Returns 52 or 53 — the number of ISO weeks in the given year.
	## A year has 53 weeks if Jan 1 is Thursday, or if it's a leap year with Jan 1 on Wednesday.
	var jan1_wd: int = _iso_weekday_of_jan1(year)
	if jan1_wd == 4:
		return 53
	if jan1_wd == 3 and ((year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)):
		return 53
	return 52


func _get_iso_week(date_string: String) -> int:
	## Returns the ISO 8601 week number (1–53) for a "YYYY-MM-DD" date string.
	## Correctly handles year-boundary edge cases (Dec 28–31 may be week 1 of the next year).
	var dt: Dictionary = Time.get_datetime_dict_from_datetime_string(date_string + "T00:00:00", true)
	var year: int = dt["year"]
	var month: int = dt["month"]
	var day: int = dt["day"]
	# Godot weekday: 0=Sun, 1=Mon … 6=Sat → ISO: 1=Mon … 7=Sun
	var godot_wd: int = dt["weekday"]
	var iso_wd: int = godot_wd if godot_wd != 0 else 7
	var doy: int = _day_of_year(year, month, day)
	var w: int = (doy - iso_wd + 10) / 7
	if w < 1:
		w = _weeks_in_year(year - 1)
	elif w > _weeks_in_year(year):
		w = 1
	return w


func _update_streak_and_weekly(today: String) -> void:
	## Updates streak_days and weekly_progress based on the gap since last sign-in.
	## Must be called BEFORE updating last_sign_in in mark_sign_in().
	## Reads save_data["profile"] directly to see the persisted last_sign_in value.
	var profile: Dictionary = save_data.get("profile", {})
	var last: String = profile.get("last_sign_in", "")
	if last == "":
		profile["streak_days"] = 1
	elif _days_between(last, today) == 1:
		profile["streak_days"] = int(profile.get("streak_days", 0)) + 1
	else:
		profile["streak_days"] = 1
	if last != "" and _get_iso_week(today) != _get_iso_week(last):
		profile["weekly_progress"] = 0
	save_data["profile"] = profile


func _evaluate_achievements() -> void:
	var achievements: Dictionary = save_data.get("achievements", {})
	var profile: Dictionary = get_profile()
	for definition in ContentService.get_achievement_definitions():
		var achievement_id: String = definition.get("id", "")
		var current: Dictionary = achievements.get(achievement_id, {"unlocked": false, "claimed": false, "progress": 0})
		var progress_value: int = 0
		match definition.get("type", ""):
			"levels_completed":
				progress_value = int(profile.get("levels_completed_count", 0))
			"streak_days":
				progress_value = int(profile.get("streak_days", 0))
			"correct_answers":
				progress_value = int(profile.get("total_correct_answers", 0))
		current["progress"] = progress_value
		if progress_value >= int(definition.get("target", 0)):
			current["unlocked"] = true
		current["title"] = definition.get("title", achievement_id)
		current["description"] = definition.get("description", "")
		achievements[achievement_id] = current
	save_data["achievements"] = achievements


func claim_achievement(achievement_id: String) -> Dictionary:
	var achievements: Dictionary = get_achievements()
	if not achievements.has(achievement_id):
		return {"ok": false, "message": "成就不存在。"}
	var current: Dictionary = achievements[achievement_id]
	if not current.get("unlocked", false):
		return {"ok": false, "message": "成就尚未解锁。"}
	if current.get("claimed", false):
		return {"ok": false, "message": "成就奖励已经领取。"}
	current["claimed"] = true
	achievements[achievement_id] = current
	save_data["achievements"] = achievements
	for reward in ContentService.get_growth_rules().get("achievement_rewards", []):
		if reward.get("id", "") == achievement_id:
			_apply_reward(reward)
			break
	save_to_disk()
	state_changed.emit()
	return {"ok": true, "message": "成就奖励已领取。"}
