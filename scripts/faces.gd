class_name Faces
extends RefCounted

## Each adventurer's face, made from a seed of their own rather than drawn by hand, so everyone who
## ever joins has one, the same on every device and after every reload. A face is pixel art in
## three-quarter view, facing right, outlined, over shoulders in clothes.

## A face's size in pixels.
const SIZE_PX: Vector2i = Vector2i(20, 18)
const OUTLINE: Color = Color("#1a1423")
## Each head shape: the [left, right] pixels it fills on each row from HEAD_TOP down to the chin.
const HEAD_TOP: int = 4
const HEADS: Array[Array] = [
	[[8, 13], [6, 15], [5, 16], [4, 16], [4, 16], [4, 16], [4, 16], [4, 16], [4, 16], [5, 16], [7, 15], [9, 13]],
	[[8, 13], [7, 14], [6, 15], [5, 15], [5, 15], [5, 15], [5, 15], [5, 15], [5, 15], [6, 15], [7, 14], [9, 13]],
	[[7, 14], [5, 16], [4, 17], [4, 17], [3, 17], [3, 17], [3, 17], [3, 17], [4, 17], [5, 16], [6, 15], [8, 14]],
	[[8, 13], [6, 15], [5, 16], [4, 16], [4, 16], [4, 16], [4, 16], [4, 16], [4, 16], [5, 16], [6, 16], [7, 15]],
	[[8, 13], [6, 15], [5, 16], [4, 16], [4, 16], [4, 16], [4, 16], [4, 16], [5, 16], [6, 15], [8, 14], [10, 12]],
]
## Each skin tone: [skin, its shade].
const SKINS: Array[Array] = [
	[Color("#f6d4b4"), Color("#dca684")],
	[Color("#f0c39a"), Color("#c98a62")],
	[Color("#e0a87c"), Color("#b5745a")],
	[Color("#c98a5a"), Color("#a0643c")],
	[Color("#a0643c"), Color("#7a4628")],
	[Color("#7a4a26"), Color("#5a3218")],
]
## Each hair colour: [hair, highlight, shadow]. The shadow also colours brows and stubble.
const HAIRS: Array[Array] = [
	[Color("#2a2030"), Color("#4a4058"), Color("#16131b")],
	[Color("#5c3820"), Color("#84532c"), Color("#3a2216")],
	[Color("#84532c"), Color("#ad7a43"), Color("#5c3820")],
	[Color("#b0482c"), Color("#d87048"), Color("#7a2c1c")],
	[Color("#e8c050"), Color("#f6e08a"), Color("#b88a24")],
	[Color("#d0a060"), Color("#e8c890"), Color("#9a6a30")],
	[Color("#a59cb0"), Color("#e2dcea"), Color("#7a7288")],
	[Color("#e2dcea"), Color("#ffffff"), Color("#a59cb0")],
]
## Each hair style, by name for the code that draws it.
const STYLES: PackedStringArray = ["bald", "crop", "swept", "long", "spiky", "topknot", "mohawk", "fringe", "hood"]
## Each clothes colour, also a hood's: [cloth, shade, deep shade].
const CLOTHES: Array[Array] = [
	[Color("#d0524a"), Color("#a02e36"), Color("#5e1a24")],
	[Color("#7254b4"), Color("#4a3282"), Color("#2a1c4c")],
	[Color("#4c9044"), Color("#2d6638"), Color("#1c3a24")],
	[Color("#e8d6b0"), Color("#c6ae84"), Color("#9a845e")],
	[Color("#a59cb0"), Color("#7a7288"), Color("#4a4458")],
	[Color("#a0643c"), Color("#7a4a26"), Color("#3a2216")],
	[Color("#4c82b6"), Color("#2e5a8a"), Color("#1c3656")],
]
const EYE_WHITE: Color = Color("#e2dcea")
const IRISES: Array[Color] = [Color("#4c82b6"), Color("#4c9044"), Color("#84532c")]
const LIPS: Color = Color("#a02e36")
const SCAR: Color = Color("#d0524a")
## Where the eyes sit, looking right: the back eye's column, the front eye's, and their lower row.
const EYE_BACK_X: int = 11
const EYE_FRONT_X: int = 14
const EYE_Y: int = 12
const MOUTH_Y: int = 14


## The face made from `face_seed`: the same seed always gives the same face. Drawn from a generator of
## its own, never the global one.
static func image(face_seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = face_seed
	var head: Array = HEADS[rng.randi_range(0, HEADS.size() - 1)]
	var skin: Array = SKINS[rng.randi_range(0, SKINS.size() - 1)]
	var hair: Array = HAIRS[rng.randi_range(0, HAIRS.size() - 1)]
	var style := STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var clothes: Array = CLOTHES[rng.randi_range(0, CLOTHES.size() - 1)]
	var hood: Array = CLOTHES[rng.randi_range(0, CLOTHES.size() - 1)]
	var eyes := rng.randi_range(0, 4)
	var iris := IRISES[rng.randi_range(0, IRISES.size() - 1)]
	var brows := rng.randi_range(0, 3)
	var mouth := rng.randi_range(0, 4)
	var beard := rng.randi_range(0, 5)
	var scar := rng.randf() < 0.15
	var freckles := rng.randf() < 0.2

	var face := Image.create_empty(SIZE_PX.x, SIZE_PX.y, false, Image.FORMAT_RGBA8)
	# Shoulders and neck.
	for x: int in range(5, 17):
		face.set_pixel(x, 16, clothes[1] if x < 7 or x > 13 else clothes[0])
	for x: int in range(1, 19):
		face.set_pixel(x, 17, clothes[2] if x < 3 or x > 15 else clothes[1] if x < 6 or x > 13 else clothes[0])
	for x: int in range(9, 13):
		face.set_pixel(x, 16, skin[1])
	# The head, shaded on the back cheek and under the chin.
	for row: int in head.size():
		for x: int in range(head[row][0], head[row][1] + 1):
			face.set_pixel(x, HEAD_TOP + row, skin[0])
	for at: Vector2i in [Vector2i(7, 11), Vector2i(7, 12), Vector2i(13, 15), Vector2i(15, 14)]:
		_shade(face, at, skin[1])
	_draw_hair(face, head, style, hair, hood, skin)
	_draw_eyes(face, eyes, iris)
	# Brows, in the hair's shadow.
	var brow_pixels: Array = [
		[Vector2i(11, 10), Vector2i(14, 10)],
		[Vector2i(10, 10), Vector2i(11, 10), Vector2i(14, 10), Vector2i(15, 10)],
		[Vector2i(10, 9), Vector2i(11, 10), Vector2i(14, 10), Vector2i(15, 9)],
		[Vector2i(10, 10), Vector2i(11, 9), Vector2i(14, 9), Vector2i(15, 10)],
	][brows]
	for at: Vector2i in brow_pixels:
		face.set_pixelv(at, hair[2])
	if freckles:
		for at: Vector2i in [Vector2i(10, 13), Vector2i(12, 13), Vector2i(15, 13), Vector2i(9, 12)]:
			_shade(face, at, skin[1])
	# Half have no facial hair; then a moustache, a full beard or a chin beard, each beard with a
	# moustache.
	if beard >= 4:
		for y: int in range(13 if beard == 4 else 14, 16):
			for x: int in range(5 if beard == 4 else 10, 18):
				if face.get_pixel(x, y).to_rgba32() in [skin[0].to_rgba32(), skin[1].to_rgba32()]:
					face.set_pixel(x, y, hair[0])
		face.set_pixel(10, 16, hair[2])
		face.set_pixel(11, 16, hair[2])
	if beard >= 3:
		for x: int in range(12, 16):
			face.set_pixel(x, 13, hair[0])
	_draw_mouth(face, mouth, skin)
	if scar:
		for at: Vector2i in [Vector2i(15, 9), Vector2i(15, 10), Vector2i(14, 11), Vector2i(14, 13)]:
			face.set_pixelv(at, SCAR)
	_outline(face)
	return face


## The seed of `adventurer`'s face, `who` as Adventurers.roster keeps them: the one they arrived
## with, or, for the starters and anyone saved before faces were made, their id's.
static func seed_of(adventurer: String, who: Dictionary) -> int:
	return who.get("face_seed", hash(adventurer))


# Hair over the head's top and back in `style`, or a hood of `hood` cloth.
static func _draw_hair(face: Image, head: Array, style: String, hair: Array, hood: Array, skin: Array) -> void:
	var left: int = head[3][0]
	var right: int = head[3][1]
	if style == "bald":
		# An ear on the back of the head.
		face.set_pixel(left + 2, 11, skin[1])
		face.set_pixel(left + 2, 12, skin[1])
		return
	if style == "mohawk":
		for y: int in range(1, 9):
			for x: int in range(8, 11):
				face.set_pixel(x, y, hair[1] if x == 9 and y < 5 else hair[0])
		return
	var colours := hood if style == "hood" else hair
	var hairline := {"crop": 7, "swept": 8, "long": 7, "spiky": 7, "topknot": 7, "fringe": 9, "hood": 8}[style] as int
	# The cap: every head pixel above the hairline.
	for row: int in hairline - HEAD_TOP + 1:
		for x: int in range(head[row][0], head[row][1] + 1):
			face.set_pixel(x, HEAD_TOP + row, colours[0])
	if style == "swept":
		# Swept aside, showing the forehead between locks.
		face.set_pixel(13, hairline, skin[0])
		face.set_pixel(15, hairline, skin[0])
	# The back of the head, darker, down to the ear or, for long hair and hoods, the shoulders.
	var back_to := 17 if style == "long" or style == "hood" else 13
	for y: int in range(hairline, back_to + 1):
		for x: int in range(left - 1 if style == "long" or style == "hood" else left, left + 3):
			face.set_pixel(x, y, colours[2] if x == left + 1 and y > hairline else colours[0])
	if style == "hood":
		# Its front edge frames the face and hangs to the shoulders.
		for y: int in range(HEAD_TOP - 1, 18):
			face.set_pixel(right + 1, y, colours[1])
		for x: int in range(left, right + 2):
			face.set_pixel(x, HEAD_TOP - 1, colours[0])
			face.set_pixel(x, hairline, colours[1])
		return
	# A highlight where the light falls.
	face.set_pixel(9, HEAD_TOP + 1, colours[1])
	face.set_pixel(10, HEAD_TOP + 1, colours[1])
	face.set_pixel(10, HEAD_TOP + 2, colours[1])
	if style == "spiky":
		for x: int in range(head[0][0], head[0][1] + 1, 2):
			face.set_pixel(x, HEAD_TOP - 1, colours[0])
	elif style == "topknot":
		for y: int in range(1, HEAD_TOP):
			for x: int in range(9, 12):
				face.set_pixel(x, y, colours[1] if y == 1 or x == 9 else colours[0])
	elif style == "long":
		for y: int in range(9, 15):
			face.set_pixel(right, y, colours[0])
			face.set_pixel(right + 1, y, colours[2])


# One of the eye kinds, looking right, `iris` for the kind that shows one.
static func _draw_eyes(face: Image, kind: int, iris: Color) -> void:
	for x: int in [EYE_BACK_X, EYE_FRONT_X]:
		match kind:
			0:
				face.set_pixel(x, EYE_Y - 1, OUTLINE)
				face.set_pixel(x, EYE_Y, OUTLINE)
			1:
				face.set_pixel(x, EYE_Y, OUTLINE)
			2:
				face.set_pixel(x - 1, EYE_Y, EYE_WHITE)
				face.set_pixel(x, EYE_Y, OUTLINE)
			3:
				face.set_pixel(x - 1, EYE_Y, OUTLINE)
				face.set_pixel(x, EYE_Y, OUTLINE)
			4:
				face.set_pixel(x, EYE_Y - 1, OUTLINE)
				face.set_pixel(x, EYE_Y, iris)


# One of the mouth kinds, over whatever beard there is.
static func _draw_mouth(face: Image, kind: int, skin: Array) -> void:
	var line := skin[1].darkened(0.3) as Color
	match kind:
		0:
			face.set_pixel(13, MOUTH_Y, line)
		1:
			face.set_pixel(12, MOUTH_Y, line)
			face.set_pixel(13, MOUTH_Y, line)
		2:
			face.set_pixel(11, MOUTH_Y - 1, line)
			face.set_pixel(12, MOUTH_Y, line)
			face.set_pixel(13, MOUTH_Y, line)
			face.set_pixel(14, MOUTH_Y - 1, line)
		3:
			face.set_pixel(12, MOUTH_Y, line)
			face.set_pixel(13, MOUTH_Y, line)
			face.set_pixel(14, MOUTH_Y - 1, line)
		4:
			face.set_pixel(13, MOUTH_Y, LIPS)
			face.set_pixel(12, MOUTH_Y, line)


# `colour` at `at` only where there is already face to shade.
static func _shade(face: Image, at: Vector2i, colour: Color) -> void:
	if face.get_pixelv(at).a > 0.0:
		face.set_pixelv(at, colour)


# The outline around everything drawn: every empty pixel beside a drawn one.
static func _outline(face: Image) -> void:
	var edge: Array[Vector2i] = []
	for y: int in SIZE_PX.y:
		for x: int in SIZE_PX.x:
			if face.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near := Vector2i(x, y) + step
				if Rect2i(Vector2i.ZERO, SIZE_PX).has_point(near) and face.get_pixelv(near).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for at: Vector2i in edge:
		face.set_pixelv(at, OUTLINE)
