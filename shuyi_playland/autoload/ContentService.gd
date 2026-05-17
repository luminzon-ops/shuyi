extends Node

const CONTENT_FILES := {
	"grades": "res://data/content/grades.json",
	"modules": "res://data/content/modules.json",
	"knowledge_points": "res://data/content/knowledge_points.json",
	"levels": "res://data/content/levels.json",
	"questions": "res://data/content/questions.json",
	"growth_rules": "res://data/content/growth_rules.json",
	"task_rules": "res://data/content/task_rules.json",
	"reward_rules": "res://data/content/reward_rules.json",
	"star_rules": "res://data/content/star_rules.json",
	"resource_map": "res://data/content/resource_map.json"
}

var content: Dictionary = {}


func _ready() -> void:
	reload_content()


func reload_content() -> void:
	for key in CONTENT_FILES.keys():
		content[key] = _load_json(CONTENT_FILES[key])


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else []


func get_grades() -> Array:
	return content.get("grades", [])


func get_grade(grade_id: String) -> Dictionary:
	for grade_data in get_grades():
		if grade_data.get("id", "") == grade_id:
			return grade_data
	return {}


func get_modules_for_grade(grade_id: String) -> Array:
	var result: Array = []
	for module_data in content.get("modules", []):
		if module_data.get("grade_id", "") == grade_id:
			result.append(module_data)
	return result


func get_module(module_id: String) -> Dictionary:
	for module_data in content.get("modules", []):
		if module_data.get("id", "") == module_id:
			return module_data
	return {}


func get_knowledge_points(module_id: String) -> Array:
	var result: Array = []
	for knowledge_point in content.get("knowledge_points", []):
		if knowledge_point.get("module_id", "") == module_id:
			result.append(knowledge_point)
	return result


func get_knowledge_point(knowledge_point_id: String) -> Dictionary:
	for knowledge_point in content.get("knowledge_points", []):
		if knowledge_point.get("id", "") == knowledge_point_id:
			return knowledge_point
	return {}


func get_levels(knowledge_point_id: String) -> Array:
	var result: Array = []
	for level_data in content.get("levels", []):
		if level_data.get("knowledge_point_id", "") == knowledge_point_id:
			result.append(level_data)
	return result


func get_all_levels() -> Array:
	return content.get("levels", [])


func get_level(level_id: String) -> Dictionary:
	for level_data in content.get("levels", []):
		if level_data.get("id", "") == level_id:
			return level_data
	return {}


func get_questions_for_level(level_id: String) -> Array:
	var result: Array = []
	for question in content.get("questions", []):
		if question.get("level_id", "") == level_id:
			result.append(question)
	return result


func get_question(question_id: String) -> Dictionary:
	for question in content.get("questions", []):
		if question.get("id", "") == question_id:
			return question
	return {}


func get_questions_by_filters(filters: Dictionary, limit: int = 10) -> Array:
	var result: Array = []
	for question in content.get("questions", []):
		if filters.has("grade_id") and question.get("grade_id", "") != filters.get("grade_id", ""):
			continue
		if filters.has("module_id") and question.get("module_id", "") != filters.get("module_id", ""):
			continue
		if filters.has("knowledge_point_id") and question.get("knowledge_point_id", "") != filters.get("knowledge_point_id", ""):
			continue
		if filters.has("type") and question.get("type", "") != filters.get("type", ""):
			continue
		result.append(question)
		if result.size() >= limit:
			break
	return result


func get_random_questions(limit: int = 10) -> Array:
	var questions: Array = content.get("questions", []).duplicate(true)
	questions.shuffle()
	return questions.slice(0, min(limit, questions.size()))


func get_mock_test_questions(grade_id: String, limit: int = 10) -> Array:
	var result: Array = []
	for question in content.get("questions", []):
		if question.get("grade_id", "") == grade_id:
			var kp: Dictionary = get_knowledge_point(question.get("knowledge_point_id", ""))
			if kp.get("include_in_mock_test", false):
				result.append(question)
	result.shuffle()
	return result.slice(0, min(limit, result.size()))


func get_wrong_retry_questions(question_ids: Array, limit: int = 10) -> Array:
	var result: Array = []
	for question_id in question_ids:
		var question: Dictionary = get_question(str(question_id))
		if not question.is_empty():
			result.append(question)
		if result.size() >= limit:
			break
	return result


func get_next_level_unlocks(level_id: String) -> Array:
	var current_level: Dictionary = get_level(level_id)
	if current_level.is_empty():
		return []
	return current_level.get("unlock_next", [])


func get_task_rules() -> Dictionary:
	return content.get("task_rules", {})


func get_growth_rules() -> Dictionary:
	return content.get("growth_rules", {})


func get_reward_rules() -> Dictionary:
	return content.get("reward_rules", {})


func get_achievement_definitions() -> Array:
	return [
		{"id": "ach_complete_3_levels", "title": "初级闯关家", "description": "完成 3 个关卡", "type": "levels_completed", "target": 3},
		{"id": "ach_sign_in_3_days", "title": "坚持签到星", "description": "连续签到 3 天", "type": "streak_days", "target": 3},
		{"id": "ach_correct_50_questions", "title": "答题小能手", "description": "累计答对 50 题", "type": "correct_answers", "target": 50}
	]


func evaluate_answer(question: Dictionary, user_answer: String) -> bool:
	var answer: String = str(question.get("answer", "")).strip_edges().to_lower()
	var normalized: String = user_answer.strip_edges().to_lower()
	var question_type: String = str(question.get("type", "choice"))
	if question_type in ["fill_blank", "mental_math"]:
		return _numeric_or_text_match(answer, normalized)
	if question_type in ["matching", "drag_drop", "sorting", "shape_puzzle", "application", "multi_step"]:
		return _normalize_complex_answer(answer) == _normalize_complex_answer(normalized)
	return answer == normalized


func _numeric_or_text_match(expected: String, actual: String) -> bool:
	if expected.is_valid_float() and actual.is_valid_float():
		return is_equal_approx(expected.to_float(), actual.to_float())
	return expected == actual


func _normalize_complex_answer(value: String) -> String:
	return value.replace(" ", "").replace("，", ",").replace("→", ">").replace("-", ">").replace("=", "").strip_edges().to_lower()


func calculate_result(mode: String, level_id: String, correct_count: int, total_count: int) -> Dictionary:
	var accuracy: float = float(correct_count) / max(1.0, float(total_count))
	var stars: int = 1
	for rule in content.get("star_rules", {}).get("rules", []):
		if accuracy >= float(rule.get("accuracy_gte", 0.0)):
			stars = int(rule.get("stars", 1))
	var reward: Dictionary = get_reward_rules().get("default_level_reward", {"exp": 25, "gold": 18}).duplicate(true)
	if mode == "mock_test":
		reward = get_reward_rules().get("mock_test_reward", reward)
	elif mode == "random_practice":
		reward = get_reward_rules().get("random_practice_reward", reward)
	elif mode == "mini_game":
		reward = get_reward_rules().get("mini_game_reward", reward)
	else:
		var level_data: Dictionary = get_level(level_id)
		reward = level_data.get("reward", reward)
	return {
		"accuracy": accuracy,
		"stars": stars,
		"reward": reward,
		"mode": mode,
		"level_id": level_id
	}


func get_resource_theme_hint() -> Dictionary:
	var resource_map: Dictionary = {}
	for entry in content.get("resource_map", []):
		resource_map[entry.get("id", "")] = entry
	return resource_map
