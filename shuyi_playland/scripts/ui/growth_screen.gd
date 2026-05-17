extends Control

signal back_requested
signal open_sign_in_requested
signal open_achievements_requested

@onready var summary_label: Label = %SummaryLabel
@onready var daily_tasks_label: RichTextLabel = %DailyTasksLabel
@onready var weekly_tasks_label: RichTextLabel = %WeeklyTasksLabel
@onready var claim_daily_button: Button = %ClaimDailyButton
@onready var claim_weekly_button: Button = %ClaimWeeklyButton
@onready var sign_in_button: Button = %SignInButton
@onready var achievements_button: Button = %AchievementsButton
@onready var back_button: Button = %BackButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var header_visuals: HBoxContainer = $Margin/ScrollContainer/ContentMargin/VBox/HeaderVisuals


func _ready() -> void:
	claim_daily_button.pressed.connect(_claim_available_daily)
	claim_weekly_button.pressed.connect(_claim_available_weekly)
	sign_in_button.pressed.connect(func() -> void: open_sign_in_requested.emit())
	achievements_button.pressed.connect(func() -> void: open_achievements_requested.emit())
	back_button.pressed.connect(func() -> void: back_requested.emit())
	AppState.state_changed.connect(func() -> void: refresh_view())
	refresh_view()
	_play_intro_motion()


func refresh_view() -> void:
	var profile: Dictionary = AppState.get_profile()
	summary_label.text = "等级 Lv.%d｜EXP %d｜金币 %d｜连续签到 %d 天" % [profile.get("level", 1), profile.get("exp", 0), profile.get("gold", 0), profile.get("streak_days", 0)]
	daily_tasks_label.text = "[b]每日任务[/b]\n" + _task_block("daily")
	weekly_tasks_label.text = "[b]每周任务[/b]\n" + _task_block("weekly")
	feedback_label.text = "这里集中展示你的成长、任务进度和可领取奖励。"


func _task_block(group_name: String) -> String:
	var lines: Array = []
	for task_id in AppState.get_task_summary().get(group_name, {}).keys():
		var task: Dictionary = AppState.get_task_summary().get(group_name, {})[task_id]
		var status: String = "已领取" if task.get("claimed", false) else ("可领取" if int(task.get("progress", 0)) >= int(task.get("target", 0)) else "进行中")
		lines.append("• %s：%d/%d（%s）" % [task.get("label", task_id), task.get("progress", 0), task.get("target", 0), status])
	return "\n".join(lines)


func _claim_available_daily() -> void:
	feedback_label.text = _claim_first_available("daily")


func _claim_available_weekly() -> void:
	feedback_label.text = _claim_first_available("weekly")


func _claim_first_available(group_name: String) -> String:
	for task_id in AppState.get_task_summary().get(group_name, {}).keys():
		var task: Dictionary = AppState.get_task_summary().get(group_name, {})[task_id]
		if not task.get("claimed", false) and int(task.get("progress", 0)) >= int(task.get("target", 0)):
			var result: Dictionary = AppState.claim_task(group_name, task_id)
			return result.get("message", "奖励领取完成。")
	return "暂时没有可领取的任务奖励。"


func _play_intro_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	header_visuals.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(header_visuals, "modulate:a", 1.0, 0.35)
