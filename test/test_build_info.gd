extends GutTest


func test_a_commit_sha_shows_as_its_first_seven_characters() -> void:
	assert_eq(BuildInfo.label("a13da4feb0c2d9e8f7a6b5c4d3e2f1a0b9c8d7e6"), "build a13da4f")


func test_an_empty_version_shows_as_dev() -> void:
	assert_eq(BuildInfo.label(""), "build dev")
