extends Control

const QuestionRendererClass = preload("res://scripts/question_types/question_renderer.gd")

signal back_requested
signal session_finished(summary: Dictionary)
signal session_error(reason: String)
signal answer_result(is_correct: bool)  ## ADR-0011: emitted after each answer evaluation; consumed by app.gd to drive correct/wrong SFX

enum SessionState {
	IDLE,       ## No session active; screen is at rest
	LOADING,    ## Resolving questions — synchronous, transient guard state
	ACTIVE,     ## Displaying a question; waiting for user input
	EVALUATING, ## Answer submitted; evaluating and recording result
	FINISHED    ## All questions answered; session_finished emitted
}

var _state: SessionState = SessionState.IDLE

## Read-only state getter for tests and external observers (ADR-0006).
var state: SessionState:
	get: return _state

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
var session_mode: String = "level"
var last_config: Dictionary = {}
var current_question_type: String = "choice"
var question_renderer: RefCounted


func _ready() -> void:
	question_renderer = QuestionRendererClass.new()
	submit_button.pressed.connect(_on_submit_pressed)
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	next_button.disabled = true


func _transition(new_state: SessionState) -> void:
	_state = new_state


func _on_back_pressed() -> void:
	## ADR-0006: pressing back mid-session abandons it. State MUST reset to IDLE
	## so the next start_session() call can proceed (its IDLE guard would otherwise
	## silently ignore the call, leaving stale state from the abandoned session).
	_transition(SessionState.IDLE)
	back_requested.emit()


func start_session(config: Dictionary) -> void:
	if _state != SessionState.IDLE:
		push_warning("PracticeScreen.start_session called while not IDLE (state=%d). Ignoring. This usually means an exit path forgot to reset state." % _state)
		return
	_transition(SessionState.LOADING)
	last_config = config.duplicate(true)
	session_mode = str(config.get("mode", "level"))
	current_level_id = str(config.get("level_id", ""))
	questions = _resolve_questions(config)
	if questions.is_empty():
		_transition(SessionState.IDLE)
		session_error.emit("no_wrong_questions")
		return
	question_index = 0
	correct_count = 0
	selected_option = ""
	_transition(SessionState.ACTIVE)
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
	# Called only when question_index < questions.size() — caller is responsible for bounds check.
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
	submit_button.disabled = false
	next_button.disabled = true
	current_question_type = question_renderer.render(question, option_container, answer_input, Callable(self, "_select_option"))
	# Apply the unselected style to all option buttons so the initial state is uniform.
	# This implements the P-03 baseline look (selected style is applied on tap by _select_option).
	_paint_option_buttons("")


func _paint_option_buttons(selected_value: String) -> void:
	## P-03 Option Button Select: highlight the chosen option, dim the others.
	## Called with an empty selected_value to render the initial unselected state.
	var selected_style := _build_option_style(true)
	var unselected_style := _build_option_style(false)
	for child in option_container.get_children():
		if child is Button:
			var is_selected: bool = (selected_value != "") and (child.text == selected_value)
			child.button_pressed = is_selected
			var style: StyleBoxFlat = selected_style if is_selected else unselected_style
			child.add_theme_stylebox_override("normal", style)
			child.add_theme_stylebox_override("hover", style)
			child.add_theme_stylebox_override("pressed", style)
			child.add_theme_stylebox_override("focus", style)
			child.add_theme_color_override("font_color", Color(0.20, 0.10, 0.0, 1.0) if is_selected else Color(0.12, 0.11, 0.29, 1.0))
			child.modulate = Color.WHITE


func _build_option_style(is_selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.99, 0.78, 0.30, 1.0)  # warm gold
		style.border_color = Color(0.85, 0.55, 0.10, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	else:
		style.bg_color = Color(0.96, 0.97, 1.0, 1.0)  # light card
		style.border_color = Color(0.78, 0.82, 0.92, 1.0)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _select_option(value: String) -> void:
	if current_question_type in ["matching", "drag_drop", "sorting", "shape_puzzle"]:
		if answer_input.text.is_empty():
			answer_input.text = value
		else:
			answer_input.text += ">" + value
		return
	selected_option = value
	_paint_option_buttons(value)


func _on_submit_pressed() -> void:
	if _state != SessionState.ACTIVE:
		return
	_transition(SessionState.EVALUATING)
	var question: Dictionary = questions[question_index]
	var user_answer: String = question_renderer.build_user_answer(current_question_type, selected_option, answer_input)
	if user_answer.strip_edges().is_empty():
		feedback_label.text = "[color=yellow]请先完成作答。[/color]"
		_transition(SessionState.ACTIVE)
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
	submit_button.disabled = true
	next_button.disabled = false
	# Emit after UI state has settled — handlers (e.g. SFX, EXP float-up) run on the
	# already-updated screen.
	answer_result.emit(is_correct)


func _on_next_pressed() -> void:
	if _state != SessionState.EVALUATING:
		return
	question_index += 1
	if question_index >= questions.size():
		_finish_session()
	else:
		_transition(SessionState.ACTIVE)
		show_question()


func _build_explanation(question: Dictionary) -> String:
	var steps: Array = question.get("explanation_steps", [])
	if steps.is_empty():
		return "继续下一题，保持你的闯关节奏。"
	return "解析：\n- " + "\n- ".join(steps)


func _finish_session() -> void:
	if _state != SessionState.EVALUATING:
		return
	var result: Dictionary = ContentService.calculate_result(session_mode, current_level_id, correct_count, questions.size())
	AppState.complete_session(session_mode, current_level_id, correct_count, questions.size(), result)
	result["correct_count"] = correct_count
	result["total_count"] = questions.size()
	result["retry_config"] = last_config
	# ADR-0006: reset state to IDLE BEFORE emitting session_finished,
	# so app.gd's handler can call start_session() synchronously if needed.
	_transition(SessionState.IDLE)
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
