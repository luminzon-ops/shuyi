extends Control

## HomeScreen — intent-first hub.
## Three responsibilities:
## (1) "Continue learning" CTA — recommends the next level after the most recently completed one
## (2) Quick links to status views (sign-in, growth, achievements)
## (3) "换个玩法" 2x2 grid: random / mock test / library / wrong retry

signal start_session_requested(config: Dictionary)
signal open_growth_requested
signal open_sign_in_requested
signal open_achievements_requested
signal open_wrong_book_requested
signal open_library_requested

@onready var summary_label: Label = %SummaryLabel
@onready var growth_label: Label = %GrowthLabel
@onready var exp_progress_bar: ProgressBar = %ExpProgressBar
@onready var exp_progress_label: Label = %ExpProgressLabel
@onready var continue_button: Button = %ContinueButton
@onready var sign_in_button: Button = %SignInButton
@onready var growth_button: Button = %GrowthButton
@onready var achievements_button: Button = %AchievementsButton
@onready var random_card: Button = %RandomCard
@onready var mock_test_card: Button = %MockTestCard
@onready var library_card: Button = %LibraryCard
@onready var wrong_retry_card: Button = %WrongRetryCard

var _continue_level_id: String = ""


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	sign_in_button.pressed.connect(func() -> void: open_sign_in_requested.emit())
	growth_button.pressed.connect(func() -> void: open_growth_requested.emit())
	achievements_button.pressed.connect(func() -> void: open_achievements_requested.emit())
	random_card.pressed.connect(func() -> void: start_session_requested.emit({"mode": "random_practice"}))
	mock_test_card.pressed.connect(_on_mock_test_pressed)
	library_card.pressed.connect(func() -> void: open_library_requested.emit())
	wrong_retry_card.pressed.connect(_on_wrong_retry_pressed)
	AppState.state_changed.connect(func() -> void: refresh_view())
	refresh_view()
	_play_intro_motion()


func refresh_view() -> void:
	var profile: Dictionary = AppState.get_profile()
	var nickname: String = str(profile.get("nickname", "小园探险家"))
	var level: int = int(profile.get("level", 1))
	var exp_points: int = int(profile.get("exp", 0))
	var streak: int = int(profile.get("streak_days", 0))
	summary_label.text = "你好 %s，今天也加油！" % nickname
	growth_label.text = "Lv.%d · EXP %d · 🔥 %d 天" % [level, exp_points, streak]
	# Progress to next level: exp / (level * curve_base)
	var curve_base: int = int(ContentService.get_growth_rules().get("level_up_curve_base", 100))
	var threshold: int = level * curve_base
	exp_progress_bar.max_value = float(threshold)
	exp_progress_bar.value = float(exp_points)
	exp_progress_label.text = "%d / %d EXP" % [exp_points, threshold]
	_update_continue_button()
	_update_wrong_retry_card()


func _update_continue_button() -> void:
	# Recommend the next level after the most recently completed one.
	# If no completed levels, fall back to the most recent attempted level.
	# If neither, fall back to the default starter level.
	_continue_level_id = _resolve_continue_level()
	if _continue_level_id.is_empty():
		continue_button.text = "开始学习"
		continue_button.disabled = true
		return
	continue_button.disabled = false
	var level_data: Dictionary = ContentService.get_level(_continue_level_id)
	var level_name: String = str(level_data.get("name", _continue_level_id))
	var verb: String = "续练" if AppState.get_level_record(_continue_level_id).get("stars", 0) == 0 else "下一关"
	continue_button.text = "%s：%s" % [verb, level_name]


func _resolve_continue_level() -> String:
	# Priority 1: most recent attempted level if it isn't fully cleared
	var recent_id: String = AppState.get_recent_level_id()
	if not recent_id.is_empty():
		var record: Dictionary = AppState.get_level_record(recent_id)
		if int(record.get("stars", 0)) == 0:
			return recent_id
		# Priority 2: next level after the recent one
		var next_id: String = _find_next_level_after(recent_id)
		if not next_id.is_empty():
			return next_id
		# No next level, replay the recent
		return recent_id
	# Priority 3: default starter
	return "level_grade1_addition_1"


func _find_next_level_after(level_id: String) -> String:
	# Walk through grades → modules → knowledge points → levels in order
	# until we find the level_id, then return the next one in sequence.
	var found: bool = false
	for grade_data in ContentService.get_grades():
		var grade_id: String = str(grade_data.get("id", ""))
		for module_data in ContentService.get_modules_for_grade(grade_id):
			var module_id: String = str(module_data.get("id", ""))
			for knowledge_data in ContentService.get_knowledge_points(module_id):
				var knowledge_id: String = str(knowledge_data.get("id", ""))
				for level_data in ContentService.get_levels(knowledge_id):
					var current_id: String = str(level_data.get("id", ""))
					if found:
						return current_id
					if current_id == level_id:
						found = true
	return ""


func _update_wrong_retry_card() -> void:
	var ids: Array = AppState.get_wrong_question_ids_for_retry(99)
	var count: int = ids.size()
	wrong_retry_card.text = "🔁\n错题重练\n%d 道待练" % count if count > 0 else "🔁\n错题重练\n暂无错题 ✨"


func _on_continue_pressed() -> void:
	if _continue_level_id.is_empty():
		return
	start_session_requested.emit({"mode": "level", "level_id": _continue_level_id})


func _on_mock_test_pressed() -> void:
	# Use the recent level's grade if known, else default to grade_1.
	var grade_id: String = "grade_1"
	var recent_id: String = AppState.get_recent_level_id()
	if not recent_id.is_empty():
		var level_data: Dictionary = ContentService.get_level(recent_id)
		var inferred: String = str(level_data.get("grade_id", ""))
		if not inferred.is_empty():
			grade_id = inferred
	start_session_requested.emit({"mode": "mock_test", "grade_id": grade_id})


func _on_wrong_retry_pressed() -> void:
	# Reuse the existing wrong-retry signal pattern via WrongBookScreen,
	# or start the session directly if there are wrong questions to retry.
	var ids: Array = AppState.get_wrong_question_ids_for_retry(10)
	if ids.is_empty():
		# No wrong questions — open WrongBookScreen so the empty state explains itself.
		open_wrong_book_requested.emit()
		return
	start_session_requested.emit({"mode": "wrong_retry", "question_ids": ids})


func _play_intro_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
