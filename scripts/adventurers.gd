class_name Adventurers
extends RefCounted

## Who is in the guild, and each one's stats, growth, level, XP, level-ups and gear. All of it is
## saved: a new game starts with the starters, and `add` brings in anyone else.

## The stats every adventurer has, in the order they are shown, with their names for the player.
## Anyone can be anything: what an adventurer is good at is their stats alone. Spirit and Luck work
## for the whole party (see Dispatch); Luck is never tested by a challenge.
const STATS: Dictionary[String, String] = {
	"strength": "Strength", "agility": "Agility", "perception": "Perception", "mind": "Mind",
	"spirit": "Spirit", "defence": "Defence", "endurance": "Endurance", "presence": "Presence",
	"luck": "Luck",
}
## An adventurer's title when their two highest stats, gear included, are one of these pairs, in
## STATS order.
const PAIR_TITLES: Dictionary[String, Array] = {
	"Fighter": ["strength", "defence"],
	"Scout": ["agility", "perception"],
	"Mystic": ["mind", "spirit"],
	"Cleric": ["spirit", "presence"],
	"Ranger": ["perception", "endurance"],
	"Envoy": ["mind", "presence"],
	"Paladin": ["spirit", "defence"],
	"Duellist": ["strength", "agility"],
	"Cartographer": ["perception", "mind"],
}
## An adventurer's title by their highest stat when their two highest are no pair in PAIR_TITLES.
const STAT_TITLES: Dictionary[String, String] = {
	"strength": "Brawler", "agility": "Rogue", "perception": "Tracker", "mind": "Scholar",
	"spirit": "Acolyte", "defence": "Guard", "endurance": "Wanderer", "presence": "Herald",
	"luck": "Gambler",
}
## The starters, in roster order: who each one is, as `roster` keeps it. A guild saved before guild
## ranks started with all of them. Their faces come from their ids (Faces.seed_of).
const STARTERS: Dictionary[String, Dictionary] = {
	"bram": {"name": "Bram", "rank": "F"},
	"ilse": {"name": "Ilse", "rank": "F"},
	"tobin": {"name": "Tobin", "rank": "F"},
	"maren": {"name": "Maren", "rank": "F"},
}
## The starters a new game has, in roster order: Bram for strength, Tobin for keen eyes.
const NEW_GAME_STARTERS: PackedStringArray = ["bram", "tobin"]
## The starters' stats on joining the guild: Bram leans Strength and Defence with some Endurance,
## Tobin Agility and Perception with some Luck, Ilse Mind and Presence, Maren Spirit and Mind.
const STARTING_STATS: Dictionary[String, Dictionary] = {
	"bram": {"strength": 6, "agility": 3, "perception": 3, "mind": 2, "spirit": 3, "defence": 7, "endurance": 5, "presence": 3, "luck": 1},
	"ilse": {"strength": 2, "agility": 3, "perception": 3, "mind": 8, "spirit": 3, "defence": 5, "endurance": 3, "presence": 6, "luck": 1},
	"tobin": {"strength": 3, "agility": 7, "perception": 6, "mind": 3, "spirit": 3, "defence": 3, "endurance": 3, "presence": 3, "luck": 4},
	"maren": {"strength": 2, "agility": 3, "perception": 3, "mind": 6, "spirit": 7, "defence": 5, "endurance": 3, "presence": 3, "luck": 1},
}
## The starters' growth, as `growth` keeps it. Tobin's Agility grows far faster than the rest.
const GROWTH: Dictionary[String, Dictionary] = {
	"bram": {"strength": 0.6, "agility": 0.3, "perception": 0.15, "mind": 0.15, "spirit": 0.15, "defence": 0.55, "endurance": 0.4, "presence": 0.15, "luck": 0.1},
	"ilse": {"strength": 0.15, "agility": 0.3, "perception": 0.25, "mind": 0.7, "spirit": 0.3, "defence": 0.35, "endurance": 0.2, "presence": 0.5, "luck": 0.1},
	"tobin": {"strength": 0.3, "agility": 0.9, "perception": 0.6, "mind": 0.25, "spirit": 0.15, "defence": 0.3, "endurance": 0.3, "presence": 0.2, "luck": 0.3},
	"maren": {"strength": 0.2, "agility": 0.3, "perception": 0.2, "mind": 0.55, "spirit": 0.65, "defence": 0.5, "endurance": 0.3, "presence": 0.3, "luck": 0.1},
}
## Saves from before the nine stats kept four: Might is Strength now and Grit is Defence.
const RENAMED_STATS: Dictionary[String, String] = {"might": "strength", "grit": "defence"}
## What an adventurer saved with four stats gets for the five new ones, stats and growth, by the
## class they had then (a starter gets their own starting ones), and the weapon a candidate of
## that class is given.
const OLD_CLASSES: Dictionary[String, Dictionary] = {
	"Swordsman": {"weapon": "short_sword", "stats": {"perception": 3, "spirit": 3, "endurance": 5, "presence": 3, "luck": 1}, "growth": {"perception": 0.15, "spirit": 0.15, "endurance": 0.4, "presence": 0.15, "luck": 0.1}},
	"Mage": {"weapon": "oak_staff", "stats": {"perception": 3, "spirit": 3, "endurance": 3, "presence": 5, "luck": 1}, "growth": {"perception": 0.25, "spirit": 0.3, "endurance": 0.2, "presence": 0.45, "luck": 0.1}},
	"Scout": {"weapon": "hunting_bow", "stats": {"perception": 6, "spirit": 3, "endurance": 3, "presence": 3, "luck": 2}, "growth": {"perception": 0.6, "spirit": 0.15, "endurance": 0.3, "presence": 0.2, "luck": 0.2}},
	"Healer": {"weapon": "bell_mace", "stats": {"perception": 3, "spirit": 7, "endurance": 3, "presence": 3, "luck": 1}, "growth": {"perception": 0.2, "spirit": 0.65, "endurance": 0.3, "presence": 0.3, "luck": 0.1}},
	"Shield bearer": {"weapon": "short_sword", "stats": {"perception": 3, "spirit": 3, "endurance": 6, "presence": 3, "luck": 1}, "growth": {"perception": 0.2, "spirit": 0.2, "endurance": 0.6, "presence": 0.2, "luck": 0.1}},
}
## A stat's growth chance rises by this for each point worn items add to it, up to
## MOST_GEAR_GROWTH, so an adventurer grows toward what they wear.
const GROWTH_PER_GEAR_POINT: float = 0.05
const MOST_GEAR_GROWTH: float = 0.9
## XP to go from level L to L + 1 is this times L.
const XP_PER_LEVEL: int = 40
## Maximum health is this plus HEALTH_PER_DEFENCE per point of Defence and HEALTH_PER_LEVEL per
## level past the first (stand-ins), so a member failing a quest of the rank their level reaches is
## injured about half to three quarters of the time, not almost always.
const BASE_HEALTH: int = 10
const HEALTH_PER_DEFENCE: int = 2
const HEALTH_PER_LEVEL: int = 3
## Each rank an adventurer can be promoted to, one rank at a time, with the level it needs and the
## gold it costs (stand-ins). No promotion reaches a rank missing here.
const PROMOTIONS: Dictionary[String, Dictionary] = {"E": {"level": 3, "gold": 150}, "D": {"level": 6, "gold": 400}}

## Who is in the guild, in roster order: each one's {"name", "rank"} and, for a recruit,
## "face_seed", their face's (Faces.seed_of). The save refers to an adventurer by their id here.
var roster: Dictionary[String, Dictionary] = {}
## Each adventurer's own growth per stat, their talent, never shown to the player: a level-up gives
## a stat up to two points, each with this chance raised by gear (see `growth_chance`).
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


## A guild of `starters`, keys of STARTERS, each in their starter gear.
func _init(starters: PackedStringArray = NEW_GAME_STARTERS) -> void:
	for adventurer: String in starters:
		add(adventurer, STARTERS[adventurer], STARTING_STATS[adventurer], GROWTH[adventurer])
		gear.worn[adventurer] = Gear.STARTER_GEAR[adventurer].duplicate()


## Brings `adventurer` into the guild as `who` (as `roster` keeps them), with
## `starting_stats` and `grows` as their growth per stat, at `level` with no XP and nothing worn.
func add(adventurer: String, who: Dictionary, starting_stats: Dictionary, grows: Dictionary, level: int = 1) -> void:
	roster[adventurer] = who.duplicate()
	growth[adventurer] = grows.duplicate()
	stats[adventurer] = starting_stats.duplicate()
	levels[adventurer] = level
	xp[adventurer] = 0
	history[adventurer] = []
	gear.worn[adventurer] = {}


## Takes `adventurer` out of the guild for good, forgetting everything about them; their gear goes
## into the stash as Gear.strip puts it. Whether they may leave is Dispatch's rule.
func remove(adventurer: String) -> void:
	gear.strip(adventurer)
	roster.erase(adventurer)
	growth.erase(adventurer)
	stats.erase(adventurer)
	levels.erase(adventurer)
	xp.erase(adventurer)
	history.erase(adventurer)


## `adventurer`'s `stat` as it counts: their own plus what their gear adds.
func stat_total(adventurer: String, stat: String) -> int:
	return int(stats[adventurer][stat]) + gear.bonus(adventurer, stat)


## Health `adventurer` heals up to, so every level-up, and gear that raises Defence, raises it.
func max_health(adventurer: String) -> int:
	return BASE_HEALTH + HEALTH_PER_DEFENCE * stat_total(adventurer, "defence") + HEALTH_PER_LEVEL * (levels[adventurer] - 1)


## `adventurer`'s title, from their two highest stats, gear included: see `title_of`.
func title(adventurer: String) -> String:
	var totals := {}
	for stat: String in STATS:
		totals[stat] = stat_total(adventurer, stat)
	return title_of(totals)


## The title of someone with `totals`, {stat: points}: their two highest stats' pair in
## PAIR_TITLES, or else their highest stat's own in STAT_TITLES. A tie goes to the stat earlier in
## STATS.
static func title_of(totals: Dictionary) -> String:
	var top := ""
	var second := ""
	for stat: String in STATS:
		if top.is_empty() or totals[stat] > totals[top]:
			second = top
			top = stat
		elif second.is_empty() or totals[stat] > totals[second]:
			second = stat
	for pair_title: String in PAIR_TITLES:
		if top in PAIR_TITLES[pair_title] and second in PAIR_TITLES[pair_title]:
			return pair_title
	return STAT_TITLES[top]


## The chance each point of a level-up in `stat` comes to `adventurer`: their own growth, plus
## GROWTH_PER_GEAR_POINT per point their worn items add to it, at most MOST_GEAR_GROWTH; gear never
## lowers a talent already above that.
func growth_chance(adventurer: String, stat: String) -> float:
	var talent := float(growth[adventurer][stat])
	return maxf(talent, minf(MOST_GEAR_GROWTH, talent + GROWTH_PER_GEAR_POINT * gear.bonus(adventurer, stat)))


## The XP a party gains in all from a quest whose success gives `full` (Dispatch.QUESTS "xp") that
## ended in `success`: on a failure a quarter of that, rounded down, but at least 1, so even a
## failure teaches something. Each member gains an equal part (see Dispatch).
static func quest_xp(full: int, success: bool) -> int:
	return full if success else maxi(1, floori(full / 4.0))


func gain_xp(adventurer: String, amount: int) -> void:
	xp[adventurer] += amount


## The XP `adventurer` needs to reach the next level.
func xp_needed(adventurer: String) -> int:
	return XP_PER_LEVEL * levels[adventurer]


func level_up_ready(adventurer: String) -> bool:
	return xp[adventurer] >= xp_needed(adventurer)


## Raises `adventurer` one level, spending the XP it needs, and grows each stat by 0–2 by their
## `growth_chance`. Returns {stat: points it rose by}; empty, with nothing changed, when not ready.
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


## True when `adventurer`'s level is at least what their next rank needs; false at the highest rank.
func reached_promotion_level(adventurer: String) -> bool:
	var next := next_rank(adventurer)
	return not next.is_empty() and levels[adventurer] >= PROMOTIONS[next]["level"]


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
	var grows := {}
	for stat: String in STATS:
		grows[stat] = growth_chance(adventurer, stat)
	return gains_from(rng, grows)


## One level-up's gains drawn from `rng` by `grows`, growth per stat: {stat: 0–2 points}, each
## point with that stat's growth as its chance.
static func gains_from(rng: RandomNumberGenerator, grows: Dictionary) -> Dictionary:
	var gains := {}
	for stat: String in STATS:
		var gain := 0
		for point: int in 2:
			if rng.randf() < float(grows[stat]):
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


## The adventurers saved at `path`, or a new game's starters at their starting stats, level 1 and
## no XP, in their starter gear, when there is no save. A save from before guild ranks that lacks
## any of that holds every starter as they started; their gear as Gear.load_or_start finds it.
static func load_or_start(path: String) -> Adventurers:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return Adventurers.new()
	var adventurers := Adventurers.new(PackedStringArray(STARTERS.keys()))
	if file.has_section("gear"):
		adventurers.gear = Gear.load_or_start(path)
	if not file.has_section("adventurers"):
		return adventurers
	# A save from before the roster was saved holds every starter.
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
	for adventurer: String in adventurers.roster:
		if adventurers.stats[adventurer].has("might"):
			adventurers._to_nine_stats(adventurer)
	return adventurers


## `values`, {stat: value} as saved with the four old stats, with Might and Grit renamed
## (RENAMED_STATS) and the stats it lacks taken from `fill`.
static func nine_stats(values: Dictionary, fill: Dictionary) -> Dictionary:
	var nine := {}
	for stat: String in values:
		nine[RENAMED_STATS.get(stat, stat)] = values[stat]
	nine.merge(fill)
	return nine


# Brings `adventurer`, saved with the four old stats, up to the nine, nothing lost: their stats and
# growth renamed and filled by their old class (a starter's by their own starting ones), and the
# gains in their history renamed, so it reads as before. Their class is not kept: their stats say
# what they are.
func _to_nine_stats(adventurer: String) -> void:
	var who := roster[adventurer]
	var old_class: String = who.get("class", "")
	who.erase("class")
	var stats_fill: Dictionary = STARTING_STATS[adventurer] if STARTING_STATS.has(adventurer) else OLD_CLASSES[old_class]["stats"]
	var growth_fill: Dictionary = GROWTH[adventurer] if GROWTH.has(adventurer) else OLD_CLASSES[old_class]["growth"]
	stats[adventurer] = nine_stats(stats[adventurer], stats_fill)
	# A save from before growth was kept has the starters' growth already.
	if growth[adventurer].has("might"):
		growth[adventurer] = nine_stats(growth[adventurer], growth_fill)
	for entry: Dictionary in history[adventurer]:
		entry["gains"] = nine_stats(entry["gains"], {})
