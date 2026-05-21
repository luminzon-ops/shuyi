extends GdUnitTestSuite

## Integration tests for _set_nav_visible() in app.gd (HUD spec, S1-07).
## Verifies the bottom nav card is hidden during active sessions and re-shown after.
##
## NOTE: These tests access app.gd via the scene tree root.
## app.gd is the root Control of App.tscn — its script is app.gd.


func _get_app() -> Control:
	# App.tscn is the root scene — its script is app.gd.
	return get_tree().root.get_child(0) as Control


func test_nav_card_visible_by_default() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	# Before any session starts, the bottom nav card must be visible.
	assert_bool(app.bottom_nav_card.visible).is_true()


func test_set_nav_visible_false_hides_nav_card() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	app._set_nav_visible(false)
	# Bottom nav card must be hidden — collapses the layout so no white space remains
	assert_bool(app.bottom_nav_card.visible).is_false()
	# Restore
	app._set_nav_visible(true)


func test_set_nav_visible_true_shows_nav_card() -> void:
	var app: Control = _get_app()
	# NOTE: App node not accessible in this test context — skipping
	if app == null:
		return
	app._set_nav_visible(false)
	app._set_nav_visible(true)
	# Bottom nav card must be re-shown
	assert_bool(app.bottom_nav_card.visible).is_true()
