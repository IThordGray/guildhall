class_name Adventurers
extends RefCounted

## Who is in the guild, and each one's stats, growth, level, XP, level-ups and gear. All of it is
## saved: a new game starts with the starters, and `add` brings in anyone else.

## The stats every adventurer has, in the order they are shown, with their names for the player.
const STATS: Dictionary[String, String] = {"might": "Might", "agility": "Agility", "mind": "Mind", "grit": "Grit"}
## The adventurers a new game starts with, in roster order: who each one is, as `roster` keeps it.
const STARTERS: Dictionary[String, Dictionary] = {
	"bram": {"name": "Bram", "class": "Swordsman", "rank": "F", "face": "bram"},
	"ilse": {"name": "Ilse", "class": "Mage", "rank": "F", "face": "ilse"},
	"tobin": {"name": "Tobin", "class": "Scout", "rank": "F", "face": "tobin"},
	"maren": {"name": "Maren", "class": "Healer", "rank": "F", "face": "maren"},
}
## The starters' stats on joining the guild.
const STARTING_STATS: Dictionary[String, Dictionary] = {
	"bram": {"might": 6, "agility": 3, "mind": 2, "grit": 7},
	"ilse": {"might": 2, "agility": 3, "mind": 8, "grit": 5},
	"tobin": {"might": 3, "agility": 7, "mind": 3, "grit": 3},
	"maren": {"might": 2, "agility": 3, "mind": 6, "grit": 5},
}
## The starters' growth, as `growth` keeps it. Tobin's Agility grows far faster than the rest.
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
## Maximum health is this plus HEALTH_PER_GRIT per point of Grit (stand-ins).
const BASE_HEALTH: int = 10
const HEALTH_PER_GRIT: int = 2
## Each rank an adventurer can be promoted to, one rank at a time, with the level it needs and the
## gold it costs (stand-ins). No promotion reaches a rank missing here.
const PROMOTIONS: Dictionary[String, Dictionary] = {"E": {"level": 3, "gold": 150}, "D": {"level": 6, "gold": 400}}

## Who is in the guild, in roster order: each one's {"name", "class", "rank", "face"}, the face
## being the name of their art in assets/faces. The save refers to an adventurer by their id here.
var roster: Dictionary[String, Dictionary] = {}
## Each adventurer's growth per stat, never shown to the player: a level-up gives a stat up to two
## points, each with this chance.
var growth: Dictionary[String, Dictionary] = {}
## Each adventurer's own stats, without gear: see `stat_total` for what counts.
var stats: Dictionary[String, Dictionary] = {}
var levels: Dictionary[String, int] = {}
## XP banked toward the next level. It keeps building past what the next level needs, so several
## level-ups can wait.
var xp: Dictionary[String, int] = {}
## Each adventurer's level-ups, oldest first. Each is {"level": the level reached, "gains":
## {stat: points it rose by}}.
var history: Dictionary[String, Array] = {}
## What everyone wears and the guild's stash; worn items add to stats.
var gear: Gear = Gear.new()


func _init() -> void:
	for adventurer: String in STARTERS:
		add(adventurer, STARTERS[adventurer], STARTING_STATS[adventurer], GROWTH[adventurer])
	# The starters join in their starter gear.
	gear = Gear.new()


## Brings `adventurer` into the guild as `who` ({"name", "class", "rank", "face"}), with
## `starting_stats` and `grows` as their growth per stat, at level 1 with no XP and nothing worn.
func add(adventurer: String, who: Dictionary, starting_stats: Dictionary, grows: Dictionary) -> void:
	roster[adventurer] = who.duplicate()
	growth[adventurer] = grows.duplicate()
	stats[adventurer] = starting_stats.duplicate()
	levels[adventurer] = 1
	xp[adventurer] = 0
	history[adventurer] = []
	gear.worn[adventurer] = {}


## `adventurer`'s `stat` as it counts: their own plus what their gear adds.
func stat_total(adventurer: String, stat: String) -> int:
	return int(stats[adventurer][stat]) + gear.bonus(adventurer, stat)


## The sum of `adventurer`'s stats, gear included, ÷ 5, rounded.
func power(adventurer: String) -> int:
	var total := 0
	for stat: String in STATS:
		total += stat_total(adventurer, stat)
	return roundi(total / 5.0)


## Health `adventurer` heals up to, so a level-up or gear that raises Grit raises it.
func max_health(adventurer: String) -> int:
	return BASE_HEALTH + HEALTH_PER_GRIT * stat_total(adventurer, "grit")


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


## The rank `adventurer` can be promoted to next; "" at the highest rank PROMOTIONS has.
func next_rank(adventurer: String) -> String:
	var next := Challenges.RANKS.find(roster[adventurer]["rank"]) + 1
	if next < Challenges.RANKS.size() and PROMOTIONS.has(Challenges.RANKS[next]):
		return Challenges.RANKS[next]
	return ""


## Why `adventurer` can't be promoted with `gold`, `out_on_quest` or not, in words for the player;
## "" when they can. Promotion needs a minimum level, but nobody is ever promoted for reaching it.
func promotion_refusal(adventurer: String, gold: Gold, out_on_quest: bool) -> String:
	var next := next_rank(adventurer)
	if next.is_empty():
		return "Highest rank"
	if out_on_quest:
		return "Out on a quest"
	if levels[adventurer] < PROMOTIONS[next]["level"]:
		return "Needs level %d" % PROMOTIONS[next]["level"]
	if gold.amount < PROMOTIONS[next]["gold"]:
		return "Not enough gold"
	return ""


## Pays for and promotes `adventurer` to `next_rank`; false, with nothing paid or changed, when
## `promotion_refusal` gives a reason. A new rank changes which quests the board draws, so whoever
## calls this brings the board up to date first.
func promote(adventurer: String, gold: Gold, out_on_quest: bool) -> bool:
	if not promotion_refusal(adventurer, gold, out_on_quest).is_empty():
		return false
	var next := next_rank(adventurer)
	gold.spend(PROMOTIONS[next]["gold"])
	roster[adventurer]["rank"] = next
	return true


# Seeded from the adventurer and the level reached, never the global generator, so the same
# level-up always grows the same.
func _gains(adventurer: String, level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [adventurer, level])
	var gains := {}
	for stat: String in STATS:
		var gain := 0
		for point: int in 2:
			if rng.randf() < float(growth[adventurer][stat]):
				gain += 1
		gains[stat] = gain
	return gains


## Puts the adventurers into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	# A dictionary is saved with its keys sorted, so the roster order is saved on its own.
	file.set_value("adventurers", "order", PackedStringArray(roster.keys()))
	file.set_value("adventurers", "roster", roster)
	file.set_value("adventurers", "growth", growth)
	file.set_value("adventurers", "stats", stats)
	file.set_value("adventurers", "levels", levels)
	file.set_value("adventurers", "xp", xp)
	file.set_value("adventurers", "history", history)
	gear.write(file)


## The adventurers saved at `path`, or the starters at their starting stats, level 1 and no XP when
## the save has none; their gear as Gear.load_or_start finds it.
static func load_or_start(path: String) -> Adventurers:
	var adventurers := Adventurers.new()
	adventurers.gear = Gear.load_or_start(path)
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("adventurers"):
		return adventurers
	# A save from before the roster was saved holds the starters, as a new game has them.
	if file.has_section_key("adventurers", "roster"):
		var saved: Dictionary = file.get_value("adventurers", "roster")
		adventurers.roster.clear()
		for adventurer: String in file.get_value("adventurers", "order"):
			adventurers.roster[adventurer] = saved[adventurer]
	adventurers.growth.assign(file.get_value("adventurers", "growth", adventurers.growth))
	adventurers.stats.assign(file.get_value("adventurers", "stats"))
	adventurers.levels.assign(file.get_value("adventurers", "levels"))
	adventurers.xp.assign(file.get_value("adventurers", "xp"))
	adventurers.history.assign(file.get_value("adventurers", "history"))
	return adventurers
