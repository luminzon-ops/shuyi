extends Control

## LibraryScreen — browse all levels by grade/module/knowledge point.
## Migrated from the old HomeScreen StudyCard. Two playstyles:
## (1) pick a level from the list → starts level mode
## (2) tap "按知识点抽题" → starts special_practice mode for the current knowledge point

signal back_requested
signal start_session_requested(config: Dictionary)

@onready var grade_option: OptionButton = %LibraryGradeOption
@onready var module_option: OptionButton = %LibraryModuleOption
@onready var knowledge_option: OptionButton = %LibraryKnowledgeOption
@onready var level_list: ItemList = %LibraryLevelList
@onready var start_level_button: Button = %LibraryStartLevelButton
@onready var special_practice_button: Button = %LibrarySpecialPracticeButton
@onready var back_button: Button = %LibraryBackButton
@onready var helper_label: Label = %LibraryHelperLabel

var current_levels: Array = []


func _ready() -> void:
	grade_option.item_selected.connect(_on_grade_changed)
	module_option.item_selected.connect(_on_module_changed)
	knowledge_option.item_selected.connect(_on_knowledge_changed)
	start_level_button.pressed.connect(_on_start_level_pressed)
	special_practice_button.pressed.connect(_on_special_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())


func refresh_view() -> void:
	helper_label.text = "选择年级、模块、知识点，按一关或抽题练习"
	if grade_option.item_count == 0:
		_refresh_filters()
	else:
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


func _on_start_level_pressed() -> void:
	if level_list.item_count == 0 or level_list.get_selected_items().is_empty():
		helper_label.text = "请先选择一个关卡。"
		return
	var selected_index: int = level_list.get_selected_items()[0]
	var level_id: String = str(level_list.get_item_metadata(selected_index))
	if not AppState.is_level_unlocked(level_id):
		helper_label.text = "该关卡暂未解锁，请先完成前置内容。"
		return
	start_session_requested.emit({"mode": "level", "level_id": level_id})


func _on_special_pressed() -> void:
	if knowledge_option.item_count == 0:
		helper_label.text = "当前模块暂无可抽题的内容。"
		return
	var knowledge_id: String = str(knowledge_option.get_item_metadata(knowledge_option.selected))
	start_session_requested.emit({"mode": "special_practice", "knowledge_point_id": knowledge_id})
