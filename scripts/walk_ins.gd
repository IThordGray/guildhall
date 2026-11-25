class_name WalkIns
extends RefCounted

## Adventurers who come to the guild unasked, wanting to join, one at a time. Each waits until the
## next one arrives, then leaves for good. Accepting one is free; when to expect the next is never
## shown.

## The shortest and longest wait for a game's first walk-in, about 5 minutes on average, so a new
## guild sees one early.
const MIN_FIRST_GAP_SECONDS: int = 180
const MAX_FIRST_GAP_SECONDS: int = 420
## The shortest and longest gap from one walk-in's arrival to the next's, about a day on average, so
## each later walk-in is an event rather than a flood.
const MIN_GAP_SECONDS: int = 20 * 3600
const MAX_GAP_SECONDS: int = 28 * 3600
## The same once the guild has reached rank E, about 14 hours on average: a better-known guild draws
## them sooner.
const MIN_GAP_SECONDS_E: int = 12 * 3600
const MAX_GAP_SECONDS_E: int = 16 * 3600
## How likely a walk-in arrives at each level, in whole percent: mostly 1, now and then someone
## strong. They are always rank F.
const LEVEL_PERCENT: Dictionary[int, int] = {1: 75, 2: 18, 3: 7}
## The slot Recruits.candidate_for draws a walk-in for: none of the candidates', so a walk-in is
## never a candidate arriving at the same moment.
const SLOT: int = -1

## Who waits to join, as Recruits.candidates keeps a candidate, "level" included; {} for nobody.
var walk_in: Dictionary = {}
## Unix seconds the latest walk-in arrived at; -1 before the first.
var arrived_at: int = -1
## Unix seconds the next walk-in arrives at; -1 until the first `refill` sets it.
var next_at: int = -1
## Latest unix seconds the walk-ins have been brought up to.
var checked_at: int = 0


## The name of whoever waits to join; "" for nobody.
func waiting_name() -> String:
	return "" if walk_in.is_empty() else walk_in["who"]["name"]


## Brings the walk-ins up to `now`. The first arrives one `first_gap` after the first refill, which
## is when the game started or a save from before walk-ins first loaded; each later one an
## `arrival_gap` after the one before, so a save holding the next arrival keeps it. Whoever arrives
## replaces whoever waited. Each walk-in and each gap is drawn from its arrival time alone, never
## the global generator, so refilling once after an absence gives the same walk-in as refilling
## every second through it; their name is none in `adventurers` or among `recruits`' candidates.
## `rank_e_at` is as for `arrival_gap`. Time is read as no earlier than the walk-ins last saw, so a
## clock set back never undoes an arrival.
func refill(adventurers: Adventurers, recruits: Recruits, now: int, rank_e_at: int = -1) -> void:
	var at := maxi(now, checked_at)
	if next_at < 0:
		next_at = at + first_gap(at)
	var arriving := -1
	while next_at <= at:
		arriving = next_at
		next_at = arriving + arrival_gap(arriving, rank_e_at)
	# Only the latest arrival is drawn: everyone before them has already left.
	if arriving >= 0:
		arrived_at = arriving
		walk_in = walk_in_for(arriving, recruits.names_taken(adventurers, SLOT))
	checked_at = at


## The wait from `started_at`, when the walk-ins were first refilled, until the first walk-in,
## MIN_FIRST_GAP_SECONDS to MAX_FIRST_GAP_SECONDS, drawn from that time alone.
static func first_gap(started_at: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["walk-in gap", started_at])
	return rng.randi_range(MIN_FIRST_GAP_SECONDS, MAX_FIRST_GAP_SECONDS)


## The gap from a walk-in arriving at `arrived_at` until the next one, drawn from that time alone:
## MIN_GAP_SECONDS_E to MAX_GAP_SECONDS_E when they arrive at or after `rank_e_at`, the moment the
## guild reached rank E (-1 for not yet), MIN_GAP_SECONDS to MAX_GAP_SECONDS before it. A gap is
## drawn once, when its walk-in arrives, so one already running when the guild ranks up keeps its
## length. The one place the gap between walk-ins is decided.
static func arrival_gap(arrived_at: int, rank_e_at: int = -1) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["walk-in gap", arrived_at])
	if rank_e_at >= 0 and arrived_at >= rank_e_at:
		return rng.randi_range(MIN_GAP_SECONDS_E, MAX_GAP_SECONDS_E)
	return rng.randi_range(MIN_GAP_SECONDS, MAX_GAP_SECONDS)


## The walk-in who arrives at `arrived_at`, drawn as a rank-F candidate (Recruits.candidate_for)
## named other than `taken`, at a level drawn by LEVEL_PERCENT, their stats grown by a level-up's
## gains for each level past the first.
static func walk_in_for(arrived_at: int, taken: PackedStringArray) -> Dictionary:
	var walk_in := Recruits.candidate_for(SLOT, arrived_at, taken)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["walk-in level", arrived_at])
	var roll := rng.randi_range(1, 100)
	var level := 1
	for each: int in LEVEL_PERCENT:
		level = each
		roll -= LEVEL_PERCENT[each]
		if roll <= 0:
			break
	Recruits.arrive_at_level(walk_in, level, rng)
	return walk_in


## Brings the walk-in into `adventurers`, free, wearing what they came in; false, with nothing
## changed, when nobody waits or no bed of `beds` is free (Recruits.bed_refusal). Whoever calls this
## brings the walk-ins up to date first.
func accept(adventurers: Adventurers, beds: int) -> bool:
	if walk_in.is_empty() or not Recruits.bed_refusal(adventurers, beds).is_empty():
		return false
	# An arrival time belongs to one walk-in only.
	Recruits.join(adventurers, "walk_in_%d" % arrived_at, walk_in)
	walk_in = {}
	return true


## Sends the walk-in away for good; the next still arrives at its own time.
func turn_away() -> void:
	walk_in = {}


## Dismisses `adventurer` from `dispatch` (Dispatch.dismiss) to make room for the walk-in, who then
## joins as `accept` brings them in; false, with nothing changed, when nobody waits, `adventurer`
## can't be dismissed, or no bed of `beds` would be free even then. As `accept`, and as
## Dispatch.dismiss for the board.
func swap(adventurer: String, dispatch: Dispatch, beds: int) -> bool:
	if walk_in.is_empty() or not dispatch.dismiss_refusal(adventurer).is_empty() or dispatch.adventurers.roster.size() - 1 >= beds:
		return false
	dispatch.dismiss(adventurer)
	return accept(dispatch.adventurers, beds)


## Puts the walk-ins into `file`, which other state shares, so one save holds the whole game.
func write(file: ConfigFile) -> void:
	file.set_value("walk_ins", "walk_in", walk_in)
	file.set_value("walk_ins", "arrived_at", arrived_at)
	file.set_value("walk_ins", "next_at", next_at)
	file.set_value("walk_ins", "checked_at", checked_at)


## The walk-ins saved at `path`, or nobody waiting and nobody due yet, which the first `refill`
## sets one `first_gap` away, when the save has none.
static func load_or_start(path: String) -> WalkIns:
	var walk_ins := WalkIns.new()
	var file := ConfigFile.new()
	if file.load(path) != OK or not file.has_section("walk_ins"):
		return walk_ins
	walk_ins.walk_in = file.get_value("walk_ins", "walk_in")
	walk_ins.arrived_at = file.get_value("walk_ins", "arrived_at")
	walk_ins.next_at = file.get_value("walk_ins", "next_at")
	walk_ins.checked_at = file.get_value("walk_ins", "checked_at")
	return walk_ins
