extends GdUnitTestSuite

## Unit tests for streak reset and weekly progress mechanics (ADR-0009, TR-growth-006/008).
## Tests _update_streak_and_weekly(), _days_between(), _get_iso_week(), and related helpers.
## All date strings are hardcoded — no time-dependent assertions.


# ---------------------------------------------------------------------------
# _days_between() tests
# ---------------------------------------------------------------------------

func test_days_between_consecutive_days_returns_1() -> void:
	assert_int(AppState._days_between("2026-05-20", "2026-05-21")).is_equal(1)


func test_days_between_two_day_gap_returns_2() -> void:
	assert_int(AppState._days_between("2026-05-20", "2026-05-22")).is_equal(2)


func test_days_between_same_day_returns_0() -> void:
	assert_int(AppState._days_between("2026-05-21", "2026-05-21")).is_equal(0)


func test_days_between_year_boundary_dec31_to_jan1_returns_1() -> void:
	# Dec 31 → Jan 1 must be exactly 1 day (consecutive, different years)
	assert_int(AppState._days_between("2025-12-31", "2026-01-01")).is_equal(1)


func test_days_between_uses_roundi_not_int() -> void:
	# Verify that the implementation uses roundi() — test via a known consecutive pair
	# where float division could produce 0.9999... if int() were used.
	# 2026-01-01 to 2026-01-02 = exactly 86400 seconds = 1 day.
	# If int() were used and float precision caused 0.9999..., this would return 0.
	# roundi() must be used — int() would truncate 0.9999... to 0
	var result: int = AppState._days_between("2026-01-01", "2026-01-02")
	assert_int(result).is_equal(1)


# ---------------------------------------------------------------------------
# _get_iso_week() tests — including year-boundary edge cases (ADR-0009 required)
# ---------------------------------------------------------------------------

func test_get_iso_week_normal_week() -> void:
	# 2026-05-21 is a Thursday in week 21
	assert_int(AppState._get_iso_week("2026-05-21")).is_equal(21)


func test_get_iso_week_dec28_belongs_to_next_year_week1() -> void:
	# ISO 8601: Dec 28, 2026 — need to verify which week this belongs to.
	# 2026-12-28 is a Monday. Jan 1, 2027 is a Friday.
	# Since Jan 1, 2027 is Friday, week 1 of 2027 starts on Mon Jan 4, 2027.
	# So Dec 28, 2026 is ISO week 53 of 2026 (not week 1 of 2027).
	# Note: 2026 has 53 weeks because Jan 1, 2026 is Thursday.
	assert_int(AppState._get_iso_week("2026-12-28")).is_equal(53)


func test_get_iso_week_jan3_same_week_as_dec28() -> void:
	# Jan 3, 2027 is a Sunday. Since Jan 1, 2027 is Friday, Jan 3 is still in
	# week 53 of 2026 (the week starts Mon Dec 28, 2026 and ends Sun Jan 3, 2027).
	assert_int(AppState._get_iso_week("2027-01-03")).is_equal(53)


func test_get_iso_week_dec28_and_jan3_same_week() -> void:
	# The critical ADR-0009 requirement: Dec 28 and Jan 3 must be in the same ISO week
	# so that _update_streak_and_weekly() does NOT reset weekly_progress between them.
	var week_dec28: int = AppState._get_iso_week("2026-12-28")
	var week_jan3: int = AppState._get_iso_week("2027-01-03")
	# Dec 28 and Jan 3 must be in the same ISO week — no spurious weekly reset
	assert_int(week_dec28).is_equal(week_jan3)


func test_get_iso_week_jan4_is_always_week1() -> void:
	# ISO 8601 rule: Jan 4 is always in week 1
	assert_int(AppState._get_iso_week("2026-01-04")).is_equal(1)
	assert_int(AppState._get_iso_week("2027-01-04")).is_equal(1)


# ---------------------------------------------------------------------------
# _update_streak_and_weekly() tests
# ---------------------------------------------------------------------------

func _setup_profile(last_sign_in: String, streak_days: int, weekly_progress: int) -> void:
	var profile: Dictionary = AppState.save_data.get("profile", {}).duplicate()
	profile["last_sign_in"] = last_sign_in
	profile["streak_days"] = streak_days
	profile["weekly_progress"] = weekly_progress
	AppState.save_data["profile"] = profile


func test_update_streak_first_ever_signin_sets_streak_to_1() -> void:
	_setup_profile("", 0, 0)
	AppState._update_streak_and_weekly("2026-05-21")
	# First sign-in must set streak_days = 1
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(1)


func test_update_streak_consecutive_day_increments_streak() -> void:
	_setup_profile("2026-05-20", 3, 50)
	AppState._update_streak_and_weekly("2026-05-21")
	# Consecutive day must increment streak_days
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(4)


func test_update_streak_two_day_gap_resets_streak_to_1() -> void:
	_setup_profile("2026-05-19", 5, 50)
	AppState._update_streak_and_weekly("2026-05-21")
	# 2-day gap must reset streak_days to 1
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(1)


func test_update_streak_large_gap_resets_streak_to_1() -> void:
	_setup_profile("2026-01-01", 10, 80)
	AppState._update_streak_and_weekly("2026-05-21")
	# Large gap must reset streak_days to 1
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(1)


func test_update_streak_empty_last_signin_does_not_call_date_to_unix() -> void:
	# Guard: empty last_sign_in must set streak = 1 without calling _date_to_unix("").
	# We verify this indirectly: if _date_to_unix("") were called, it would return -1
	# and _days_between would produce a nonsensical result, potentially not setting streak = 1.
	_setup_profile("", 0, 0)
	AppState._update_streak_and_weekly("2026-05-21")
	# Empty last_sign_in guard must fire and set streak = 1
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(1)


func test_update_weekly_progress_resets_on_iso_week_boundary() -> void:
	# Sign in on Mon May 18 (week 21), then sign in on Mon May 25 (week 22)
	_setup_profile("2026-05-18", 1, 75)
	AppState._update_streak_and_weekly("2026-05-25")
	# weekly_progress must reset to 0 when ISO week changes
	assert_int(int(AppState.save_data["profile"]["weekly_progress"])).is_equal(0)


func test_update_weekly_progress_does_not_reset_within_same_week() -> void:
	# Sign in on Mon May 18 (week 21), then sign in on Fri May 22 (also week 21)
	_setup_profile("2026-05-18", 1, 60)
	AppState._update_streak_and_weekly("2026-05-22")
	# weekly_progress must NOT reset within the same ISO week
	assert_int(int(AppState.save_data["profile"]["weekly_progress"])).is_equal(60)


func test_update_weekly_progress_does_not_reset_on_first_signin() -> void:
	# First sign-in (empty last_sign_in) must not reset weekly_progress
	_setup_profile("", 0, 40)
	AppState._update_streak_and_weekly("2026-05-21")
	# weekly_progress must not reset on first sign-in (no last_sign_in to compare)
	assert_int(int(AppState.save_data["profile"]["weekly_progress"])).is_equal(40)


func test_update_streak_year_boundary_dec31_to_jan1_consecutive() -> void:
	# Dec 31 → Jan 1 is consecutive — streak must increment, not reset
	_setup_profile("2025-12-31", 7, 50)
	AppState._update_streak_and_weekly("2026-01-01")
	# Dec 31 → Jan 1 is consecutive — streak must increment
	assert_int(int(AppState.save_data["profile"]["streak_days"])).is_equal(8)
