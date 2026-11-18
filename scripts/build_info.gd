class_name BuildInfo
extends RefCounted

## Text for the build label: CI sets the version to the commit SHA; local runs leave it empty.
static func label(version: String) -> String:
	if version.is_empty():
		return "build dev"
	return "build " + version.left(7)
