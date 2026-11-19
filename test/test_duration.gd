extends GutTest


func test_durations_show_as_minutes_and_two_digit_seconds() -> void:
	assert_eq(Duration.label(60), "1:00")
	assert_eq(Duration.label(600), "10:00")
	assert_eq(Duration.label(59), "0:59")
	assert_eq(Duration.label(125), "2:05")
