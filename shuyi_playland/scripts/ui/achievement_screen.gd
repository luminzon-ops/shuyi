extends Control

signal back_requested

@onready var achievement_list: ItemList = %AchievementList
@onready var claim_button: Button = %ClaimButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	claim_button.pressed.connect(_claim_selected)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	AppState.state_changed.connect(func() -> void: refresh_view())
	refresh_view()


func refresh_view() -> void:
	achievement_list.clear()
	for achievement_id in AppState.get_achievements().keys():
		var entry: Dictionary = AppState.get_achievements()[achievement_id]
		var text: String = "%s ｜ %s ｜ %s" % [entry.get("title", achievement_id), entry.get("description", ""), "可领取" if entry.get("unlocked", false) and not entry.get("claimed", false) else ("已领取" if entry.get("claimed", false) else "未解锁")]
		achievement_list.add_item(text)
		achievement_list.set_item_metadata(achievement_list.item_count - 1, achievement_id)
	if achievement_list.item_count > 0:
		achievement_list.select(0)
	feedback_label.text = "完成更多学习目标即可解锁成就。"


func _claim_selected() -> void:
	if achievement_list.get_selected_items().is_empty():
		feedback_label.text = "请先选择一个成就。"
		return
	var idx: int = achievement_list.get_selected_items()[0]
	var achievement_id: String = str(achievement_list.get_item_metadata(idx))
	var result: Dictionary = AppState.claim_achievement(achievement_id)
	feedback_label.text = result.get("message", "操作完成。")
