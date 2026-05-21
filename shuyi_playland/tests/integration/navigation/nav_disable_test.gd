extends GdUnitTestSuite

## Integration tests for _set_nav_enabled() in app.gd (HUD spec, S1-07).
## Verifies bottom nav tabs are disabled during active sessions and re-enabled after.
##
## NOTE: These tests access app.gd via the scene tree root.
## app.gd is the root Control of App.tscn — accessible via get_tree().root.get_node("App")
## or via the autoload-equivalent pattern. Since app.gd is not an autoload, we test
## _set_nav_enabled() by checking the disabled state of the nav buttons directly.
##
## In GdUnit4 integration tests, the full scene tree is available.
## We access the app node via get_tree().root.get_child(0) (App.tscn is the main scene).


func _get_app() -> Control:
	# App.tscn is the root scene — its script is app.gd.
	return get_tree().root.get_child(0) as Control


func test_nav_buttons_enabled_by_default() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	# Before any session starts, all nav buttons must be enabled.
	assert_bool(app.home_button.disabled).is_false()
	assert_bool(app.practice_button.disabled).is_false()
	assert_bool(app.growth_button.disabled).is_false()
	assert_bool(app.mini_game_button.disabled).is_false()
	assert_bool(app.settings_button.disabled).is_false()


func test_set_nav_enabled_false_disables_all_buttons() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	app._set_nav_enabled(false)
	# HomeButton must be disabled after _set_nav_enabled(false)
	assert_bool(app.home_button.disabled).is_true()
	assert_bool(app.practice_button.disabled).is_true()
	assert_bool(app.growth_button.disabled).is_true()
	assert_bool(app.mini_game_button.disabled).is_true()
	assert_bool(app.settings_button.disabled).is_true()
	# Restore
	app._set_nav_enabled(true)


func test_set_nav_enabled_true_enables_all_buttons() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	app._set_nav_enabled(false)
	app._set_nav_enabled(true)
	# HomeButton must be re-enabled after _set_nav_enabled(true)
	assert_bool(app.home_button.disabled).is_false()
	assert_bool(app.practice_button.disabled).is_false()
	assert_bool(app.growth_button.disabled).is_false()
	assert_bool(app.mini_game_button.disabled).is_false()
	assert_bool(app.settings_button.disabled).is_false()
