extends Control

signal back_requested
signal start_wrong_retry_requested

@onready var wrong_list: ItemList = %WrongList
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var retry_button: Button = %RetryButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	wrong_list.item_selected.connect(_on_selected)
	retry_button.pressed.connect(func() -> void: start_wrong_retry_requested.emit())
	back_button.pressed.connect(func() -> void: back_requested.emit())
	AppState.state_changed.connect(func() -> void: refresh_view())
	refresh_view()


func refresh_view() -> void:
	wrong_list.clear()
	for entry in AppState.get_wrong_book_entries():
		var question: Dictionary = ContentService.get_question(entry.get("question_id", ""))
		wrong_list.add_item("%s ｜ 错 %d 次" % [question.get("stem", entry.get("question_id", "")), entry.get("wrong_count", 1)])
		wrong_list.set_item_metadata(wrong_list.item_count - 1, entry.get("question_id", ""))
	if wrong_list.item_count > 0:
		wrong_list.select(0)
		_on_selected(0)
	else:
		detail_label.text = "当前没有错题记录。"


func _on_selected(index: int) -> void:
	var question_id: String = str(wrong_list.get_item_metadata(index))
	var question: Dictionary = ContentService.get_question(question_id)
	var entry: Dictionary = AppState.save_data.get("wrong_book", {}).get(question_id, {})
	var kp: Dictionary = ContentService.get_knowledge_point(question.get("knowledge_point_id", ""))
	detail_label.text = "[b]%s[/b]\n知识点：%s\n最近作答：%s\n状态：%s" % [question.get("stem", question_id), kp.get("name", "未知知识点"), entry.get("last_answer", "-"), "已掌握" if entry.get("mastered", false) else "待重练"]
