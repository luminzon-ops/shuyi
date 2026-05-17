extends RefCounted

class_name QuestionRenderer


func render(question: Dictionary, option_container: VBoxContainer, answer_input: LineEdit, select_callback: Callable) -> String:
	_clear_options(option_container)
	answer_input.visible = false
	answer_input.text = ""
	var question_type: String = str(question.get("type", "choice"))
	match question_type:
		"choice", "true_false":
			_render_option_buttons(question.get("options", []), option_container, select_callback)
		"fill_blank", "mental_math":
			answer_input.visible = true
			answer_input.placeholder_text = "请输入答案"
		"matching", "drag_drop", "sorting", "shape_puzzle":
			answer_input.visible = true
			answer_input.placeholder_text = "点击下方选项依次填入答案，可手动修改"
			_add_hint_label(option_container, _hint_for_type(question_type))
			_render_option_buttons(question.get("options", []), option_container, select_callback)
		"application", "multi_step":
			answer_input.visible = true
			answer_input.placeholder_text = "请输入最终答案"
			_add_hint_label(option_container, _hint_for_type(question_type))
		_:
			answer_input.visible = true
			answer_input.placeholder_text = "该题型为扩展位，先用输入框作答"
	return question_type


func build_user_answer(question_type: String, selected_option: String, answer_input: LineEdit) -> String:
	if question_type in ["choice", "true_false"]:
		return selected_option
	return answer_input.text


func supported_types() -> Array:
	return ["choice", "true_false", "fill_blank", "mental_math", "matching", "drag_drop", "sorting", "shape_puzzle", "application", "multi_step"]


func reserved_types() -> Array:
	return []


func _render_option_buttons(options: Array, option_container: VBoxContainer, select_callback: Callable) -> void:
	for option in options:
		var button: Button = Button.new()
		button.text = str(option)
		button.custom_minimum_size = Vector2(0, 72)
		button.modulate = Color(0.92, 0.97, 1.0, 1.0)
		button.pressed.connect(func() -> void: select_callback.call(button.text))
		option_container.add_child(button)


func _clear_options(option_container: VBoxContainer) -> void:
	for child in option_container.get_children():
		child.queue_free()


func _add_hint_label(option_container: VBoxContainer, text: String) -> void:
	var hint: Label = Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.73, 0.87, 1.0, 1.0)
	option_container.add_child(hint)


func _hint_for_type(question_type: String) -> String:
	match question_type:
		"matching":
			return "连线题：按配对顺序点击选项，结果会填入输入框。"
		"drag_drop":
			return "拖拽题：按目标顺序点击内容，模拟拖拽排序。"
		"sorting":
			return "排序题：按正确顺序点击数字或项目。"
		"shape_puzzle":
			return "图形拼接题：选择或组合最合适的图形答案。"
		"application":
			return "应用题：阅读题意后填写最终结果。"
		"multi_step":
			return "多步计算题：按步骤思考，填写最终答案。"
		_:
			return ""
