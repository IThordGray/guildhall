class_name Faces
extends RefCounted

## Each adventurer's face, made from a seed of their own rather than drawn by hand, so everyone who
## ever joins has one, the same on every device and after every reload. A face is the head and
## shoulders of their figure (Figures), so it is the same person and shows what they wear on their
## head.

## A face's size in pixels.
const SIZE_PX: Vector2i = Vector2i(20, 18)
## Where a face is in its figure.
const IN_FIGURE: Rect2i = Rect2i(Figures.ORIGIN + Vector2i(1, -3), SIZE_PX)


## The face made from `face_seed`, wearing `worn` ({slot: item id}, as Gear.worn keeps it): the same
## seed and items always give the same face. Drawn from a generator of its own, never the global one.
static func image(face_seed: int, worn: Dictionary = {}) -> Image:
	return Figures.image(face_seed, worn).get_region(IN_FIGURE)


## The seed of `adventurer`'s face, `who` as Adventurers.roster keeps them: the one they arrived
## with, or, for the starters and anyone saved before faces were made, their id's.
static func seed_of(adventurer: String, who: Dictionary) -> int:
	return who.get("face_seed", hash(adventurer))
