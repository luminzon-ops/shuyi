extends GdUnitTestSuite

# Smoke test for the test framework itself.
# If this passes, GdUnit4 is correctly installed and discoverable.
# Delete or replace once a real unit test exists in this directory.

func test_smoke_gdunit4_is_wired_up() -> void:
	# Arrange
	var sum := 0

	# Act
	sum = 1 + 1

	# Assert
	assert_int(sum).is_equal(2)
