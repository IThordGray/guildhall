class_name Duration
extends RefCounted

## Seconds as minutes and seconds for the player, such as "1:00" or "10:00".
static func label(seconds: int) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
