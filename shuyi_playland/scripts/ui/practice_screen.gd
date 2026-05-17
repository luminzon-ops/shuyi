extends Control

const QuestionRendererClass = preload("res://scripts/question_types/question_renderer.gd")

signal back_requested
signal session_finished(summary: Dictionary)

@onready var level_label: Label = %LevelLabel
@onready var progress_label: Label = %ProgressLabel
@onready var question_label: RichTextLabel = %QuestionLabel
@onready var option_container: VBoxContainer = %OptionContainer
@onready var answer_input: LineEdit = %AnswerInput
@onready var feedback_label: RichTextLabel = %FeedbackLabel
@onready var submit_button: Button = %SubmitButton
@onready var next_button: Button = %NextButton
@onready var back_button: Button = %BackButton
@onready var mode_label: Label = %ModeLabel

var current_level_id: String = ""
var questions: Array = []
var question_index: int = 0
var correct_count: int = 0
var selected_option: String = ""
var current_answer_checked: bool = false
var session_mode: String = "level"
var last_config: Dictionary = {}
var current_question_type: String = "choice"
var question_renderer: RefCounted


func _ready() -> void:
	question_renderer = QuestionRendererClass.new()
	submit_button.pressed.connect(_on_submit_pressed)
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	next_button.disabled = true


func start_session(config: Dictionary) -> void:
	last_config = config.duplicate(true)
	session_mode = str(config.get("mode", "level"))
	current_level_id = str(config.get("level_id", ""))
	questions = _resolve_questions(config)
	question_index = 0
	correct_count = 0
	selected_option = ""
	current_answer_checked = false
	show_question()


func _resolve_questions(config: Dictionary) -> Array:
	match session_mode:
		"level":
			return ContentService.get_questions_for_level(current_level_id)
		"special_practice":
			return ContentService.get_questions_by_filters({"knowledge_point_id": config.get("knowledge_point_id", "")}, 10)
		"random_practice":
			return ContentService.get_random_questions(10)
		"mock_test":
			return ContentService.get_mock_test_questions(str(config.get("grade_id", "grade_1")), 10)
		"wrong_retry":
			return ContentService.get_wrong_retry_questions(config.get("question_ids", []), 10)
		_:
			return ContentService.get_random_questions(10)


func show_question() -> void:
	if question_index >= questions.size():
		_finish_session()
		return
	var title_text: String = current_level_id if not current_level_id.is_empty() else session_mode
	if not current_level_id.is_empty():
		var level_data: Dictionary = ContentService.get_level(current_level_id)
		title_text = level_data.get("name", current_level_id)
	level_label.text = title_text
	mode_label.text = _mode_label_text(session_mode)
	progress_label.text = "第 %d / %d 题" % [question_index + 1, questions.size()]
	var question: Dictionary = questions[question_index]
	question_label.text = "[b]%s[/b]" % question.get("stem", "")
	feedback_label.text = ""
	selected_option = ""
	current_answer_checked = false
	submit_button.disabled = false
	next_button.disabled = true
	current_question_type = question_renderer.render(question, option_container, answer_input, Callable(self, "_select_option"))


func _select_option(value: String) -> void:
	if current_question_type in ["matching", "drag_drop", "sorting", "shape_puzzle"]:
		if answer_input.text.is_empty():
			answer_input.text = value
		else:
			answer_input.text += ">" + value
		return
	selected_option = value
	for child in option_container.get_children():
		if child is Button:
			child.button_pressed = child.text == value


func _on_submit_pressed() -> void:
	if current_answer_checked:
		return
	var question: Dictionary = questions[question_index]
	var user_answer: String = question_renderer.build_user_answer(current_question_type, selected_option, answer_input)
	if user_answer.strip_edges().is_empty():
		feedback_label.text = "[color=yellow]请先完成作答。[/color]"
		return
	var is_correct: bool = ContentService.evaluate_answer(question, user_answer)
	AppState.record_answer(question.get("id", ""), is_correct, user_answer)
	if is_correct:
		correct_count += 1
		AppState.add_correct_answers(1)
		AppState.mark_wrong_question_mastered(question.get("id", ""))
		feedback_label.text = "[color=lime]回答正确！[/color]\n%s" % _build_explanation(question)
	else:
		feedback_label.text = "[color=orange_red]回答错误。正确答案：%s[/color]\n%s" % [question.get("answer", ""), _build_explanation(question)]
	current_answer_checked = true
	submit_button.disabled = true
	next_button.disabled = false


func _on_next_pressed() -> void:
	question_index += 1
	show_question()


func _build_explanation(question: Dictionary) -> String:
	var steps: Array = question.get("explanation_steps", [])
	if steps.is_empty():
		return "继续下一题，保持你的闯关节奏。"
	return "解析：\n- " + "\n- ".join(steps)


func _finish_session() -> void:
	var result: Dictionary = ContentService.calculate_result(session_mode, current_level_id, correct_count, questions.size())
	AppState.complete_session(session_mode, current_level_id, correct_count, questions.size(), result)
	result["correct_count"] = correct_count
	result["total_count"] = questions.size()
	result["retry_config"] = last_config
	session_finished.emit(result)


func _mode_label_text(mode: String) -> String:
	match mode:
		"special_practice":
			return "专项练习"
		"random_practice":
			return "随机练习"
		"mock_test":
			return "模拟测试"
		"wrong_retry":
			return "错题重练"
		_:
			return "关卡闯关"
