class_name GameClock
extends RefCounted

## Game time in unix seconds, which play-testing can run faster than real time: real time plus a
## saved offset, plus, while the app is open, (speed − 1) extra seconds for every real second.
## Time while the app is closed or left counts at ×1. At speed 1 it adds nothing new.

## How many game seconds pass for each real second while the app is open.
var speed: int = 1
## Game seconds gained on real time by earlier speed-ups. It only grows.
var _offset_seconds: float
## Real unix time the current speed counts from.
var _since_seconds: float = 0.0
## Whether the app is open, so the speed counts.
var _open: bool = false
## The latest game time given out, so a real clock set back never turns game time back.
var _latest_seconds: int = 0


func _init(offset_seconds: float) -> void:
	_offset_seconds = offset_seconds


## Game time at real unix time `real`, in whole seconds; never earlier than a time it gave before.
func now(real: float) -> int:
	_latest_seconds = maxi(_latest_seconds, int(real + _offset_seconds + _gain(real)))
	return _latest_seconds


## From real time `real` on, game time runs `new_speed` times as fast while the app is open.
func set_speed(new_speed: int, real: float) -> void:
	_fold(real)
	speed = new_speed


## The app is left at real time `real`: game time counts at ×1 until `arrive`.
func leave(real: float) -> void:
	_fold(real)
	_open = false


## The app is open again at real time `real`: the speed counts from here.
func arrive(real: float) -> void:
	_since_seconds = real
	_open = true


## Puts the offset, with the gain up to real time `real`, into `file`, which other state shares.
## The speed is not saved: each launch starts at ×1.
func write(file: ConfigFile, real: float) -> void:
	file.set_value("clock", "offset", _offset_seconds + _gain(real))


## The clock saved at `path`, or a new game's clock on real time when there is none.
static func load_or_start(path: String) -> GameClock:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return GameClock.new(0.0)
	return GameClock.new(float(file.get_value("clock", "offset", 0.0)))


# Moves the gain so far into the offset, so the speed counts afresh from `real`.
func _fold(real: float) -> void:
	_offset_seconds += _gain(real)
	_since_seconds = real


# Extra game seconds the speed has added since it started counting: none while the app is left,
# and none for a real clock set back.
func _gain(real: float) -> float:
	if not _open:
		return 0.0
	return (speed - 1) * maxf(0.0, real - _since_seconds)
