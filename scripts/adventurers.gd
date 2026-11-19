class_name Adventurers
extends RefCounted

## The roster's growing state: each adventurer's stats, level, XP and level-ups. Who they are
## (name, class, rank) never changes: see Dispatch.ADVENTURERS.

## The stats every adventurer has, in the order they are shown, with their names for the player.
const STATS: Dictionary[String, String] = {"might": "Might", "agility": "Agility", "mind": "Mind", "grit": "Grit"}
## Each adventurer's stats on joining the guild.
const STARTING_STATS: Dictionary[String, Dictionary] = {
	"bram": {"might": 6, "agility": 3, "mind": 2, "grit": 7},
	"ilse": {"might": 2, "agility": 3, "mind": 8, "grit": 5},
	"tobin": {"might": 3, "agility": 7, "mind": 3, "grit": 3},
	"maren": {"might": 2, "agility": 3, "mind": 6, "grit": 5},
}
## Each adventurer's growth per stat, never shown to the player: a level-up gives a stat up to
## two points, each with this chance. Tobin's Agility grows far faster than the rest.
const GROWTH: Dictionary[String, Dictionary] = {
	"bram": {"might": 0.6, "agility": 0.3, "mind": 0.15, "grit": 0.55},
	"ilse": {"might": 0.15, "agility": 0.3, "mind": 0.7, "grit": 0.35},
	"tobin": {"might": 0.3, "agility": 0.9, "mind": 0.25, "grit": 0.3},
	"maren": {"might": 0.2, "agility": 0.3, "mind": 0.55, "grit": 0.5},
}
## XP to go from level L to L + 1 is this times L.
const XP_PER_LEVEL: int = 40
## A successful quest gives each member one XP per this many quest seconds; a failed one half that.
const QUEST_SECONDS_PER_XP: int = 15

var stats: Dictionary[String, Dictionary] = {}
var levels: Dictionary[String, int] = {}
## XP banked toward the next level. It keeps building past what the next level needs, so several
## level-ups can wait.
var xp: Dictionary[String, int] = {}
## Each adventurer's level-ups, oldest first. Each is {"level": the level reached, "gains":
## {stat: points it rose by}}.
var history: Dictionary[String, Array] = {}


func _init() -> void:
	for adventurer: String in STARTING_STATS:
		stats[adventurer] = STARTING_STATS[adventurer].duplicate()
		levels[adventurer] = 1
		xp[adventurer] = 0
		history[adventurer] = []


## The sum of `adventurer`'s stats ÷ 5, rounded.
func power(adventurer: String) -> int:
	var total := 0
	for stat: String in STATS:
		total += int(stats[adventurer][stat])
	return roundi(total / 5.0)


func party_power(party: PackedStringArray) -> int:
	var total := 0
	for adventurer: String in party:
		total += power(adventurer)
	return total


## The XP each member of a party gains from a quest of `quest_seconds` that ended in `success`.
static func quest_xp(quest_seconds: int, success: bool) -> int:
	var full := floori(quest_seconds / float(QUEST_SECONDS_PER_XP))
	return full if success else floori(full / 2.0)


func gain_xp(adventurer: String, amount: int) -> void:
	xp[adventurer] += amount


## The XP `adventurer` needs to reach the next level.
func xp_needed(adventurer: String) -> int:
	return XP_PER_LEVEL * levels[adventurer]


func level_up_ready(adventurer: String) -> bool:
	return xp[adventurer] >= xp_needed(adventurer)


## Raises `adventurer` one level, spending the XP it needs, and grows each stat by 0–2 by their own
## growth. Returns {stat: points it rose by}; empty, with nothing changed, when not ready.
func level_up(adventurer: String) -> Dictionary:
	if not level_up_ready(adventurer):
		return {}
	xp[adventurer] -= xp_needed(adventurer)
	levels[adventurer] += 1
	var gains := _gains(adventurer, levels[adventurer])
	for stat: String in gains:
		stats[adventurer][stat] += gains[stat]
	history[adventurer].append({"level": levels[adventurer], "gains": gains})
	return gains


# Seeded from the adventurer and the level reached, never the global generator, so the same
# level-up always grows the same.
func _gains(adventurer: String, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [adventurer, level])
	var gains := {}
	for stat: String in STATS:
		var gain := 0
		for point: int in 2:
			if rng.randf() < float(GROWTH[adventurer][stat]):
				gain += 1
		gains[stat] = gain
	return gains


## Puts the adventurers into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("adventurers", "stats", stats)
	file.set_value("adventurers", "levels", levels)
	file.set_value("adventurers", "xp", xp)
	file.set_value("adventurers", "history", history)


## The adventurers saved at `path`, or everyone at their starting stats, level 1 and no XP when the
## save has none.
static func load_or_start(path: String) -> Adventurers:
	var adventurers := Adventurers.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("adventurers"):
		return adventurers
	adventurers.stats.assign(file.get_value("adventurers", "stats"))
	adventurers.levels.assign(file.get_value("adventurers", "levels"))
	adventurers.xp.assign(file.get_value("adventurers", "xp"))
	adventurers.history.assign(file.get_value("adventurers", "history"))
	return adventurers
