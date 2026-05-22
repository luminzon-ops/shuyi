extends Control

const HOME_SCENE := preload("res://scenes/home/HomeScreen.tscn")
const PRACTICE_SCENE := preload("res://scenes/practice/PracticeScreen.tscn")
const SETTINGS_SCENE := preload("res://scenes/settings/SettingsScreen.tscn")
const GROWTH_SCENE := preload("res://scenes/growth/GrowthScreen.tscn")
const WRONG_BOOK_SCENE := preload("res://scenes/wrong_book/WrongBookScreen.tscn")
const SIGN_IN_SCENE := preload("res://scenes/sign_in/SignInScreen.tscn")
const ACHIEVEMENT_SCENE := preload("res://scenes/achievements/AchievementScreen.tscn")
const RESULT_SCENE := preload("res://scenes/result/ResultScreen.tscn")
const MINI_GAME_SCENE := preload("res://scenes/mini_games/MiniGameScreen.tscn")
const LIBRARY_SCENE := preload("res://scenes/library/LibraryScreen.tscn")

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var screen_holder: Control = %ScreenHolder
@onready var bottom_nav_card: PanelContainer = %BottomNavCard
@onready var home_button: Button = %HomeButton
@onready var practice_button: Button = %PracticeButton
@onready var growth_button: Button = %GrowthButton
@onready var mini_game_button: Button = %MiniGameButton
@onready var settings_button: Button = %SettingsButton

var home_screen: Control
var practice_screen: Control
var settings_screen: Control
var growth_screen: Control
var wrong_book_screen: Control
var sign_in_screen: Control
var achievement_screen: Control
var result_screen: Control
var mini_game_screen: Control
var library_screen: Control

# Audio players — owned by app.gd per ADR-0011.
# Any of these may be null if the corresponding file is missing at startup;
# _play_sound() handles null gracefully so audio is never a hard dependency.
var click_player: AudioStreamPlayer
var correct_player: AudioStreamPlayer    # planned: played on correct answer
var wrong_player: AudioStreamPlayer      # planned: played on wrong answer
var level_up_player: AudioStreamPlayer   # planned: played when level increases


func _ready() -> void:
	# Audio: initialize all players via the canonical factory (ADR-0011).
	# Files may not exist yet for the planned slots — null is acceptable.
	click_player = _init_audio_player("res://assets/Audio/Sounds/Menu/Accept6.wav")
	correct_player = _init_audio_player("res://assets/Audio/Sounds/Bonus/Bonus.wav")
	wrong_player = _init_audio_player("res://assets/Audio/Sounds/Alert/Alert.wav")
	level_up_player = _init_audio_player("res://assets/Audio/Jingles/LevelUp1.wav")
	home_screen = HOME_SCENE.instantiate()
	practice_screen = PRACTICE_SCENE.instantiate()
	settings_screen = SETTINGS_SCENE.instantiate()
	growth_screen = GROWTH_SCENE.instantiate()
	wrong_book_screen = WRONG_BOOK_SCENE.instantiate()
	sign_in_screen = SIGN_IN_SCENE.instantiate()
	achievement_screen = ACHIEVEMENT_SCENE.instantiate()
	result_screen = RESULT_SCENE.instantiate()
	mini_game_screen = MINI_GAME_SCENE.instantiate()
	library_screen = LIBRARY_SCENE.instantiate()
	for screen in [home_screen, practice_screen, settings_screen, growth_screen, wrong_book_screen, sign_in_screen, achievement_screen, result_screen, mini_game_screen, library_screen]:
		screen.visible = false
		screen_holder.add_child(screen)
	home_button.pressed.connect(func() -> void: _navigate(home_screen, "数一游园", "任务、成长与学习入口"))
	practice_button.pressed.connect(_open_recent_level)
	growth_button.pressed.connect(func() -> void: _navigate(growth_screen, "成长中心", "等级、任务、签到与成就"))
	mini_game_button.pressed.connect(_open_mini_game)
	settings_button.pressed.connect(func() -> void: _navigate(settings_screen, "设置中心", "音效、动画、护眼与备份"))
	home_screen.open_growth_requested.connect(func() -> void: _show_screen(growth_screen, "成长中心", "等级、任务、签到与成就"))
	home_screen.open_sign_in_requested.connect(func() -> void: _show_screen(sign_in_screen, "签到中心", "连续签到和每日奖励"))
	home_screen.open_wrong_book_requested.connect(func() -> void: _show_screen(wrong_book_screen, "错题本", "按知识点整理薄弱题目"))
	home_screen.open_achievements_requested.connect(func() -> void: _show_screen(achievement_screen, "成就中心", "勋章与成长奖励"))
	home_screen.open_library_requested.connect(func() -> void: _show_screen(library_screen, "题库", "按年级和知识点选择关卡"))
	home_screen.start_session_requested.connect(_start_session)
	library_screen.back_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	library_screen.start_session_requested.connect(_start_session)
	practice_screen.back_requested.connect(func() -> void:
		_set_nav_visible(true)
		_show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	practice_screen.session_finished.connect(_on_session_finished)
	practice_screen.session_error.connect(func(_reason: String) -> void: _set_nav_visible(true))
	wrong_book_screen.start_wrong_retry_requested.connect(_start_wrong_retry)
	sign_in_screen.back_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	growth_screen.back_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	growth_screen.open_achievements_requested.connect(func() -> void: _show_screen(achievement_screen, "成就中心", "勋章与成长奖励"))
	growth_screen.open_sign_in_requested.connect(func() -> void: _show_screen(sign_in_screen, "签到中心", "连续签到和每日奖励"))
	achievement_screen.back_requested.connect(func() -> void: _show_screen(growth_screen, "成长中心", "等级、任务、签到与成就"))
	wrong_book_screen.back_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	result_screen.back_home_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	result_screen.retry_requested.connect(_retry_last_session)
	mini_game_screen.back_requested.connect(func() -> void: _show_screen(home_screen, "数一游园", "任务、成长与学习入口"))
	mini_game_screen.game_finished.connect(_on_game_finished)
	_show_screen(home_screen, "数一游园", "任务、成长与学习入口")


func _navigate(screen: Control, title: String, subtitle: String) -> void:
	_play_click()
	_show_screen(screen, title, subtitle)


func _show_screen(screen: Control, title: String, subtitle: String) -> void:
	for child in screen_holder.get_children():
		child.visible = child == screen
	title_label.text = title
	subtitle_label.text = subtitle
	if screen.has_method("refresh_view"):
		screen.call("refresh_view")


func _open_recent_level() -> void:
	var level_id: String = AppState.get_recent_level_id()
	if level_id.is_empty():
		level_id = "level_grade1_addition_1"
	_start_session({"mode": "level", "level_id": level_id})


func _start_session(config: Dictionary) -> void:
	_play_click()
	_set_nav_visible(false)
	practice_screen.call("start_session", config)
	_show_screen(practice_screen, "练习与闯关", "专项练习、随机练习、测试与错题重练")


func _start_wrong_retry() -> void:
	var ids: Array = AppState.get_wrong_question_ids_for_retry(10)
	_start_session({"mode": "wrong_retry", "question_ids": ids})


func _retry_last_session() -> void:
	_start_session(result_screen.call("get_retry_config"))


func _on_session_finished(summary: Dictionary) -> void:
	_set_nav_visible(true)
	result_screen.call("apply_summary", summary)
	_show_screen(result_screen, "结算页", "星级、奖励与下一步建议")


func _open_mini_game() -> void:
	_play_click()
	mini_game_screen.call("start_game")
	_show_screen(mini_game_screen, "数学小游戏", "收集金币并快速答题")


func _on_game_finished(summary: Dictionary) -> void:
	result_screen.call("apply_summary", summary)
	_show_screen(result_screen, "小游戏结算", "奖励已经发放，继续挑战吧")


func _set_nav_visible(visible_state: bool) -> void:
	## Hides/shows the entire bottom nav card during active practice sessions.
	## Hiding the parent PanelContainer (not just the buttons) collapses the layout
	## so no white space remains at the bottom of the screen during a session.
	## HUD spec, ADR-0005.
	bottom_nav_card.visible = visible_state


func _init_audio_player(path: String) -> AudioStreamPlayer:
	## Canonical factory for all AudioStreamPlayer instances (ADR-0011).
	## Returns null if the resource doesn't exist — never throws, never warns,
	## so missing assets degrade silently. All players are added as children of
	## app.gd so they live for the app lifetime.
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = "Master"
	add_child(player)
	return player


func _play_sound(player: AudioStreamPlayer) -> void:
	## Canonical playback method (ADR-0011). Gates on:
	## (1) the player itself exists (null check first to avoid AppState lookup)
	## (2) the global sound_enabled setting
	## stop() before play() prevents stacking on rapid taps.
	if player == null:
		return
	if not AppState.get_settings().get("sound_enabled", true):
		return
	player.stop()
	player.play()


func _play_click() -> void:
	## Convenience wrapper preserved for existing call sites (_navigate, _start_session, _open_mini_game).
	_play_sound(click_player)
