extends Control

signal back_requested

@onready var streak_label: Label = %StreakLabel
@onready var reward_label: Label = %RewardLabel
@onready var sign_in_button: Button = %SignInButton
@onready var back_button: Button = %BackButton
@onready var visuals: HBoxContainer = $Margin/ScrollContainer/ContentMargin/VBox/Visuals
@onready var sign_in_badge: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/SignInBadge


func _ready() -> void:
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	AppState.state_changed.connect(func() -> void: refresh_view())
	refresh_view()
	_play_intro_motion()


func refresh_view() -> void:
	var profile: Dictionary = AppState.get_profile()
	streak_label.text = "当前连续签到：%d 天" % profile.get("streak_days", 0)
	reward_label.text = "今日签到奖励：10 EXP + 15 金币，完成后会自动累积成长值。"


func _on_sign_in_pressed() -> void:
	var result: Dictionary = AppState.mark_sign_in()
	reward_label.text = result.get("message", "签到完成。")
	if result.get("ok", false):
		_pulse_signin_feedback()


func _play_intro_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	visuals.modulate.a = 0.0
	sign_in_badge.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visuals, "modulate:a", 1.0, 0.35)
	tween.tween_property(sign_in_badge, "modulate:a", 1.0, 0.28)


func _pulse_signin_feedback() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	var tween: Tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
