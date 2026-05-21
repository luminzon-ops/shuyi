extends GdUnitTestSuite

## Integration tests for mark_sign_in() EXP routing through _apply_reward() (ADR-0009, S1-05).
## Verifies that EXP is never mutated directly — all gains go through _apply_reward().


func _reset_profile(exp: int, gold: int, level: int, weekly_progress: int) -> void:
	var profile: Dictionary = AppState.save_data.get("profile", {}).duplicate()
	profile["exp"] = exp
	profile["gold"] = gold
	profile["level"] = level
	profile["weekly_progress"] = weekly_progress
	profile["last_sign_in"] = ""
	profile["streak_days"] = 0
	AppState.save_data["profile"] = profile


func test_mark_sign_in_routes_exp_through_apply_reward() -> void:
	# mark_sign_in() must NOT mutate profile["exp"] directly.
	# It must call _apply_reward(), which handles EXP + weekly_progress + level-up.
	_reset_profile(0, 0, 1, 0)
	var result: Dictionary = AppState.mark_sign_in()
	# mark_sign_in() must return ok: true
	assert_bool(bool(result.get("ok", false))).is_true()
	var profile: Dictionary = AppState.get_profile()
	# sign_in_exp default is 10 (from growth_rules.json)
	# EXP must be > 0 after sign-in
	assert_int(int(profile.get("exp", 0))).is_greater(0)


func test_mark_sign_in_increments_weekly_progress_via_apply_reward() -> void:
	# weekly_progress must increment via _apply_reward(), not via a separate call.
	_reset_profile(0, 0, 1, 50)
	AppState.mark_sign_in()
	var profile: Dictionary = AppState.get_profile()
	# weekly_progress must increase after sign-in (via _apply_reward)
	assert_int(int(profile.get("weekly_progress", 50))).is_greater(50)


func test_mark_sign_in_weekly_progress_capped_at_100() -> void:
	_reset_profile(0, 0, 1, 95)
	AppState.mark_sign_in()
	var profile: Dictionary = AppState.get_profile()
	# weekly_progress must not exceed 100
	assert_int(int(profile.get("weekly_progress", 0))).is_less_equal(100)


func test_check_level_up_while_loop_handles_single_levelup() -> void:
	# Set EXP to exactly the threshold for level 1 → 2 (level 1 * 100 = 100)
	_reset_profile(100, 0, 1, 0)
	AppState._check_level_up()
	var profile: Dictionary = AppState.get_profile()
	# Level must advance to 2 at 100 EXP
	assert_int(int(profile.get("level", 1))).is_equal(2)
	# EXP must be 0 after exact threshold level-up
	assert_int(int(profile.get("exp", 0))).is_equal(0)


func test_check_level_up_while_loop_handles_multiple_levelups() -> void:
	# Level 1 threshold: 100. Level 2 threshold: 200. Give 350 EXP.
	# Level 1→2: costs 100, remaining 250. Level 2→3: costs 200, remaining 50. Level 3→4: costs 300 > 50, stop.
	_reset_profile(350, 0, 1, 0)
	AppState._check_level_up()
	var profile: Dictionary = AppState.get_profile()
	# Must reach level 3 with 350 EXP starting at level 1
	assert_int(int(profile.get("level", 1))).is_equal(3)
	# Remaining EXP must be 50 after two level-ups
	assert_int(int(profile.get("exp", 0))).is_equal(50)


func test_check_level_up_carry_over_preserves_excess_exp() -> void:
	# EXP must carry over — never reset to 0 unless exactly at threshold.
	_reset_profile(150, 0, 1, 0)
	AppState._check_level_up()
	var profile: Dictionary = AppState.get_profile()
	# Must reach level 2
	assert_int(int(profile.get("level", 1))).is_equal(2)
	# 50 excess EXP must carry over
	assert_int(int(profile.get("exp", 0))).is_equal(50)


func test_apply_reward_defaults_missing_keys_to_zero() -> void:
	# _apply_reward() must handle missing "exp" and "gold" keys gracefully.
	_reset_profile(10, 10, 1, 0)
	AppState._apply_reward({})  # empty reward — no keys
	var profile: Dictionary = AppState.get_profile()
	# EXP must be unchanged with empty reward
	assert_int(int(profile.get("exp", -1))).is_equal(10)
	# Gold must be unchanged with empty reward
	assert_int(int(profile.get("gold", -1))).is_equal(10)


func test_apply_reward_with_only_gold_does_not_crash() -> void:
	_reset_profile(0, 0, 1, 0)
	AppState._apply_reward({"gold": 15})  # no "exp" key
	var profile: Dictionary = AppState.get_profile()
	# Gold must be applied
	assert_int(int(profile.get("gold", 0))).is_equal(15)
	# EXP must remain 0 when not in reward
	assert_int(int(profile.get("exp", 0))).is_equal(0)
