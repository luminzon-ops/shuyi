extends Control

signal back_requested
signal game_finished(summary: Dictionary)

@onready var title_label: Label = %TitleLabel
@onready var score_label: Label = %ScoreLabel
@onready var prompt_label: Label = %PromptLabel
@onready var answer_a: Button = %AnswerA
@onready var answer_b: Button = %AnswerB
@onready var answer_c: Button = %AnswerC
@onready var feedback_label: Label = %FeedbackLabel
@onready var back_button: Button = %BackButton
@onready var mode_button: Button = %ModeButton
@onready var hero_visual: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/VisualRow/HeroVisual
@onready var coin_visual: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/VisualRow/CoinVisual
@onready var chest_visual: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/VisualRow/ChestVisual
@onready var door_visual: TextureRect = $Margin/ScrollContainer/ContentMargin/VBox/VisualRow/DoorVisual

var round_index: int = 0
var score: int = 0
var current_correct: String = ""
var questions: Array = []
var game_modes: Array = ["coin_quiz", "monster_quiz", "door_quiz"]
var current_mode_index: int = 0


func _ready() -> void:
	answer_a.pressed.connect(func() -> void: _pick(answer_a.text))
	answer_b.pressed.connect(func() -> void: _pick(answer_b.text))
	answer_c.pressed.connect(func() -> void: _pick(answer_c.text))
	back_button.pressed.connect(func() -> void: back_requested.emit())
	mode_button.pressed.connect(_cycle_mode)


func start_game() -> void:
	round_index = 0
	score = 0
	questions = _build_questions(game_modes[current_mode_index])
	feedback_label.text = "答对越多，奖励越高。当前模式：%s" % _mode_name(game_modes[current_mode_index])
	mode_button.text = "切换模式：%s" % _mode_name(game_modes[current_mode_index])
	_play_scene_motion()
	_show_round()


func _cycle_mode() -> void:
	current_mode_index = (current_mode_index + 1) % game_modes.size()
	start_game()


func _build_questions(mode: String) -> Array:
	match mode:
		"monster_quiz":
			return [
				{"prompt": "打怪答题：小怪兽血量 12，受击 5 点，还剩？", "options": ["5", "6", "7"], "answer": "7"},
				{"prompt": "BOSS 护甲题：8 + 8 = ?", "options": ["14", "15", "16"], "answer": "16"},
				{"prompt": "怪物连击：15 - 9 = ?", "options": ["5", "6", "7"], "answer": "6"},
				{"prompt": "勇者升级：7 + 6 = ?", "options": ["12", "13", "14"], "answer": "13"},
				{"prompt": "终结一击：18 - 9 = ?", "options": ["8", "9", "10"], "answer": "9"}
			]
		"door_quiz":
			return [
				{"prompt": "选门答题：哪扇门能通关？3 + 9 = ?", "options": ["11", "12", "13"], "answer": "12"},
				{"prompt": "第二扇门：14 - 8 = ?", "options": ["5", "6", "7"], "answer": "6"},
				{"prompt": "第三扇门：5 + 8 = ?", "options": ["12", "13", "14"], "answer": "13"},
				{"prompt": "隐藏门：11 - 4 = ?", "options": ["6", "7", "8"], "answer": "7"},
				{"prompt": "终点门：9 + 7 = ?", "options": ["15", "16", "17"], "answer": "16"}
			]
		_:
			return [
				{"prompt": "金币门开启！7 + 5 = ?", "options": ["12", "11", "13"], "answer": "12"},
				{"prompt": "宝箱守卫：14 - 6 = ?", "options": ["9", "8", "7"], "answer": "8"},
				{"prompt": "桥梁谜题：9 + 8 = ?", "options": ["17", "18", "16"], "answer": "17"},
				{"prompt": "地牢机关：15 - 7 = ?", "options": ["7", "8", "9"], "answer": "8"},
				{"prompt": "终点冲刺：6 + 9 = ?", "options": ["14", "15", "16"], "answer": "15"}
			]


func _show_round() -> void:
	if round_index >= questions.size():
		_finish_game()
		return
	var current: Dictionary = questions[round_index]
	title_label.text = "%s 第 %d / %d 轮" % [_mode_name(game_modes[current_mode_index]), round_index + 1, questions.size()]
	score_label.text = "当前得分：%d" % score
	prompt_label.text = current.get("prompt", "")
	current_correct = current.get("answer", "")
	answer_a.text = current.get("options", ["", "", ""])[0]
	answer_b.text = current.get("options", ["", "", ""])[1]
	answer_c.text = current.get("options", ["", "", ""])[2]


func _pick(answer: String) -> void:
	if answer == current_correct:
		score += 1
		feedback_label.text = "回答正确，成功收集一枚金币！✨"
		_bounce_reward_visual(coin_visual)
		_bounce_reward_visual(chest_visual)
	else:
		feedback_label.text = "回答错误，正确答案是 %s。" % current_correct
		_bounce_reward_visual(door_visual)
	round_index += 1
	_show_round()


func _finish_game() -> void:
	var result: Dictionary = ContentService.calculate_result("mini_game", "", score, questions.size())
	result["correct_count"] = score
	result["total_count"] = questions.size()
	result["retry_config"] = {"mode": "mini_game", "mini_game_mode": game_modes[current_mode_index]}
	AppState.complete_session("mini_game", "", score, questions.size(), result)
	game_finished.emit(result)


func _mode_name(mode: String) -> String:
	match mode:
		"monster_quiz": return "打怪答题"
		"door_quiz": return "选门答题"
		_: return "金币收集答题"


func _play_scene_motion() -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	hero_visual.scale = Vector2(0.86, 0.86)
	coin_visual.scale = Vector2(0.86, 0.86)
	chest_visual.scale = Vector2(0.86, 0.86)
	door_visual.scale = Vector2(0.86, 0.86)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hero_visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin_visual, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chest_visual, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_visual, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bounce_reward_visual(node: TextureRect) -> void:
	if not AppState.get_settings().get("animation_enabled", true):
		return
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
