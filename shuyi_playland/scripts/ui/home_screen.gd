extends Control

signal start_session_requested(config: Dictionary)
signal open_growth_requested
signal open_sign_in_requested
signal open_achievements_requested
signal open_wrong_book_requested

@onready var summary_label: Label = %SummaryLabel
@onready var growth_label: Label = %GrowthLabel
@onready var weekly_label: Label = %WeeklyLabel
@onready var grade_option: OptionButton = %GradeOption
@onready var module_option: OptionButton = %ModuleOption
@onready var knowledge_option: OptionButton = %KnowledgeOption
@onready var level_list: ItemList = %LevelList
@onready var sign_in_button: Button = %SignInButton
@onready var start_level_button: Button = %StartLevelButton
@onready var helper_label: Label = %HelperLabel
@onready var growth_button: Button = %GrowthButton
@onready var achievements_button: Button = %AchievementsButton
@onready var wrong_book_button: Button = %WrongBookButton
@onready var random_button: Button = %RandomPracticeButton
@onready var special_button: Button = %SpecialPracticeButton
@onready var mock_test_button: Button = %MockTestButton
@onready var hero_card: PanelContainer = $ScrollContainer/ContentMargin/ContentVBox/HeroCard
@onready var hero_banner: TextureRect = $ScrollContainer/ContentMargin/ContentVBox/HeroCard/HeroMargin/HeroVBox/HeroBanner
@onready var mascot_texture: TextureRect = $ScrollContainer/ContentMargin/ContentVBox/HeroCard/HeroMargin/HeroVBox/HeroInfoRow/MascotCard/MascotTexture

var current_levels: Array = []


func _ready() -> void:
	grade_option.item_selected.connect(_on_grade_changed)
	module_option.item_selected.connect(_on_module_changed)
	knowledge_option.item_selected.connect(_on_knowledge_changed)
	sign_in_button.pressed.connect(_on_primary_start_pressed)
	start_level_button.pressed.connect(func() -> void: open_sign_in_requested.emit())
	growth_button.pressed.connect(func() -> void: open_growth_requested.emit())
	achievements_button.pressed.connect(func() -> void: open_achievements_requested.emit())
	wrong_book_button.pressed.connect(func() -> void: open_wrong_book_requested.emit())
	random_button.pressed.connect(_on_random_pressed)
	special_button.pressed.connect(_on_special_pressed)
	mock_test_button.pressed.connect(_on_mock_test_pressed)
	AppState.state_changed.connect(func() -> void: refresh_view())
	_refresh_filters()
	refresh_view()
	_play_intro_motion()


func refresh_view(message: String = "") -> void:
	var profile: Dictionary = AppState.get_profile()
	summary_label.text = "欢迎回来，%s" % profile.get("nickname", "小园探险家")
	growth_label.text = "等级 Lv.%d · EXP %d · 金币 %d" % [profile.get("level", 1), profile.get("exp", 0), profile.get("gold", 0)]
	weekly_label.text = "连续签到 %d 天 · 已通关 %d · 学习 %d 分钟" % [profile.get("streak_days", 0), profile.get("levels_completed_count", 0), profile.get("study_minutes", 0)]
	helper_label.text = message if not message.is_empty() else "首页只保留最重要入口，减少干扰。"
	_refresh_level_list()


func _refresh_filters() -> void:
	grade_option.clear()
	for grade_data in ContentService.get_grades():
		grade_option.add_item(grade_data.get("name", ""))
		grade_option.set_item_metadata(grade_option.item_count - 1, grade_data.get("id", ""))
	if grade_option.item_count > 0:
		grade_option.select(0)
		_on_grade_changed(0)


func _on_grade_changed(index: int) -> void:
	module_option.clear()
	var grade_id: String = str(grade_option.get_item_metadata(index))
	for module_data in ContentService.get_modules_for_grade(grade_id):
		module_option.add_item(module_data.get("name", ""))
		module_option.set_item_metadata(module_option.item_count - 1, module_data.get("id", ""))
	if module_option.item_count > 0:
		module_option.select(0)
		_on_module_changed(0)


func _on_module_changed(index: int) -> void:
	knowledge_option.clear()
	if module_option.item_count == 0:
		current_levels = []
		_refresh_level_list()
		return
	var module_id: String = str(module_option.get_item_metadata(index))
	for knowledge_point in ContentService.get_knowledge_points(module_id):
		knowledge_option.add_item(knowledge_point.get("name", ""))
		knowledge_option.set_item_metadata(knowledge_option.item_count - 1, knowledge_point.get("id", ""))
	if knowledge_option.item_count > 0:
		knowledge_option.select(0)
		_on_knowledge_changed(0)
	else:
		current_levels = []
		_refresh_level_list()


func _on_knowledge_changed(index: int) -> void:
	if knowledge_option.item_count == 0:
		current_levels = []
		_refresh_level_list()
		return
	var knowledge_id: String = str(knowledge_option.get_item_metadata(index))
	current_levels = ContentService.get_levels(knowledge_id)
	_refresh_level_list()


func _refresh_level_list() -> void:
	level_list.clear()
	for level_data in current_levels:
		var level_id: String = str(level_data.get("id", ""))
		var unlocked: bool = AppState.is_level_unlocked(level_id)
		var record: Dictionary = AppState.get_level_record(level_id)
		var stars: int = int(record.get("stars", 0))
		var item_text: String = "%s ｜ %s ｜ %s" % [level_data.get("name", level_id), "已解锁" if unlocked else "未解锁", "★".repeat(stars)]
		level_list.add_item(item_text)
		level_list.set_item_metadata(level_list.item_count - 1, level_id)
	if level_list.item_count > 0:
		level_list.select(0)


func _on_primary_start_pressed() -> void:
	_on_start_level_pressed()


func _on_start_level_pressed() -> void:
	if level_list.item_count == 0 or level_list.get_selected_items().is_empty():
		helper_label.text = "请先选择一个可学习的内容。"
		return
	var selected_index: int = level_list.get_selected_items()[0]
	var level_id: String = str(level_list.get_item_metadata(selected_index))
	if not AppState.is_level_unlocked(level_id):
		helper_label.text = "该关卡暂未解锁，请先完成前置内容。"
		return
	start_session_requested.emit({"mode": "level", "level_id": level_id})


func _on_random_pressed() -> void:
	start_session_requested.emit({"mode": "random_practice"})


func _on_special_pressed() -> void:
	if knowledge_option.item_count == 0:
		helper_label.text = "当前模块暂无专项练习内容。"
		return
	var knowledge_id: String = str(knowledge_option.get_item_metadata(knowledge_option.get_selected_id()))
	start_session_requested.emit({"mode": "special_practice", "knowledge_point_id": knowledge_id})


func _on_mock_test_pressed() -> void:
	if grade_option.item_count == 0:
		helper_label.text = "当前暂无模拟测试内容。"
		return
	var grade_id: String = str(grade_option.get_item_metadata(grade_option.get_selected_id()))
	start_session_requested.emit({"mode": "mock_test", "grade_id": grade_id})


func _play_intro_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	hero_card.modulate.a = 0.0
	hero_banner.modulate.a = 0.0
	mascot_texture.scale = Vector2(0.9, 0.9)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hero_banner, "modulate:a", 1.0, 0.28)
	tween.tween_property(hero_card, "modulate:a", 1.0, 0.4)
	tween.tween_property(mascot_texture, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
