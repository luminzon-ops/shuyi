extends Control

signal back_home_requested
signal retry_requested

@onready var result_label: RichTextLabel = %ResultLabel
@onready var reward_label: Label = %RewardLabel
@onready var back_button: Button = %BackButton
@onready var retry_button: Button = %RetryButton
@onready var card: PanelContainer = $Margin/ScrollContainer/ContentMargin/VBox/Card
@onready var chest_texture: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/Card/CardMargin/CardVBox/RewardVisuals/ChestTexture
@onready var mascot_texture: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/Card/CardMargin/CardVBox/RewardVisuals/MascotTexture

var retry_config: Dictionary = {}


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_home_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	_play_intro_motion()


func apply_summary(summary: Dictionary) -> void:
	retry_config = summary.get("retry_config", {})
	result_label.text = "[b]本次完成：%s[/b]\n正确率：%d%%\n星级：%s\n答对 %d / %d 题" % [_mode_name(summary.get("mode", "level")), int(float(summary.get("accuracy", 0.0)) * 100.0), "★".repeat(int(summary.get("stars", 1))), int(summary.get("correct_count", 0)), int(summary.get("total_count", 0))]
	reward_label.text = "获得奖励：%d EXP / %d 金币，继续保持就能解锁更多内容。" % [summary.get("reward", {}).get("exp", 0), summary.get("reward", {}).get("gold", 0)]


func get_retry_config() -> Dictionary:
	return retry_config


func _mode_name(mode: String) -> String:
	match mode:
		"special_practice": return "专项练习"
		"random_practice": return "随机练习"
		"mock_test": return "模拟测试"
		"wrong_retry": return "错题重练"
		"mini_game": return "数学小游戏"
		_: return "关卡闯关"


func _play_intro_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	card.modulate.a = 0.0
	chest_texture.scale = Vector2(0.86, 0.86)
	mascot_texture.scale = Vector2(0.9, 0.9)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 1.0, 0.4)
	tween.tween_property(chest_texture, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mascot_texture, "scale", Vector2.ONE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
