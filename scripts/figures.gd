class_name Figures
extends RefCounted

## Each adventurer as a whole pixel figure wearing their gear, in three-quarter view facing right,
## made at runtime so every item shows on whoever wears it. A figure is a stack of layers drawn
## back to front: back, body, clothes, armour, belt, hair, head, neck, cloak front, weapon,
## off-hand, then one ink outline around it all. Each item is a shape painted in a material, so the
## same shape in another material is another item. Who they are (skin, hair, face) comes from their
## face seed, so their face token, the figure's head, is the same person.

## A figure's size in pixels.
const SIZE_PX: Vector2i = Vector2i(32, 44)
## Where a shape's (0, 0) is in the figure: shapes are 24 wide, row 0 the top of the head's box,
## row 27 the feet; a hat or staff reaches above it.
const ORIGIN: Vector2i = Vector2i(4, 8)
const INK: Color = Color("#1a1423")

## Each material's tones, darkest first. A shape paints 1–4 in its item's material and A, a, b, B
## (trim) in the 1st–4th tones of its trim.
const MATERIALS: Dictionary[String, Array] = {
	"iron": [Color("#4a4458"), Color("#7a7288"), Color("#a59cb0"), Color("#e2dcea")],
	"steel": [Color("#33465e"), Color("#5f7c9c"), Color("#9fbad3"), Color("#e6f2fb")],
	"bronze": [Color("#463a1a"), Color("#76662c"), Color("#a89a4a"), Color("#dcd28a")],
	"leather": [Color("#3a2216"), Color("#6b4226"), Color("#946038"), Color("#c08a52")],
	"darkleather": [Color("#24161c"), Color("#3e2a2e"), Color("#5e4246"), Color("#86686a")],
	"wood": [Color("#4a2c18"), Color("#7a4a26"), Color("#a8703c"), Color("#d4a666")],
	"gold": [Color("#8a5a12"), Color("#d49a2a"), Color("#f5cc4a"), Color("#fff1a0")],
	"red": [Color("#5e1a24"), Color("#a02e36"), Color("#d0524a"), Color("#f08a6a")],
	"purple": [Color("#2a1c4c"), Color("#4a3282"), Color("#7254b4"), Color("#a688e0")],
	"green": [Color("#1c3a24"), Color("#2d6638"), Color("#4c9044"), Color("#7dbb52")],
	"blue": [Color("#1c3152"), Color("#2d5486"), Color("#4c82b6"), Color("#8cc5e6")],
	"teal": [Color("#143c42"), Color("#20666a"), Color("#389894"), Color("#7ccfbf")],
	"cream": [Color("#9a845e"), Color("#c6ae84"), Color("#e8d6b0"), Color("#fbf3dc")],
	"bone": [Color("#7a6a4a"), Color("#bcae88"), Color("#e4dabc"), Color("#fffaf0")],
	"brown": [Color("#2e1c14"), Color("#4e3222"), Color("#70503a"), Color("#987458")],
	"gemblue": [Color("#2d5486"), Color("#4c82b6"), Color("#8cc5e6"), Color("#ffffff")],
	"gemgreen": [Color("#20664a"), Color("#3aa070"), Color("#8fe0b0"), Color("#ffffff")],
}
## How each item of Gear.ITEMS looks: [its shape, its material, its trim]. It is drawn in the layer
## of its slot; a cloak also hangs in front of the shoulders.
const LOOKS: Dictionary[String, Array] = {
	"iron_cap": ["iron_helm", "iron", "leather"],
	"goblin_bone_helm": ["horned_helm", "bronze", "bone"],
	"scouts_hood": ["hood", "green", "cream"],
	"moss_hood": ["hood", "teal", "gold"],
	"pointed_hat": ["wizard_hat", "purple", "gold"],
	"silver_circlet": ["circlet", "iron", "gemgreen"],
	"red_tunic": ["tunic", "red", "gold"],
	"leather_jerkin": ["tunic", "leather", "darkleather"],
	"apprentice_robe": ["robe", "purple", "gold"],
	"moonweave_robe": ["robe", "teal", "gold"],
	"healers_robe": ["robe", "cream", "green"],
	"leather_vest": ["vest", "leather", "bone"],
	"rangers_vest": ["vest", "darkleather", "bone"],
	"chain_shirt": ["chainmail", "iron", "iron"],
	"chapel_plate": ["plate", "steel", "gold"],
	"round_shield": ["round_shield", "wood", "iron"],
	"goblin_shield": ["round_shield", "bronze", "bone"],
	"chapel_shield": ["round_shield", "cream", "gold"],
	"short_sword": ["short_sword", "iron", "leather"],
	"goblin_slayer_blade": ["long_sword", "steel", "gold"],
	"oak_staff": ["staff", "wood", "gemblue"],
	"moonherb_staff": ["staff", "wood", "gemgreen"],
	"hunting_bow": ["bow", "wood", "cream"],
	"bell_mace": ["mace", "iron", "wood"],
	"red_cloak": ["cloak", "red", "gold"],
	"night_cloak": ["cloak", "purple", "gold"],
	"forest_cloak": ["cloak", "green", "bone"],
	"pilgrim_cloak": ["cloak", "cream", "gold"],
	"quiver": ["quiver", "leather", "red"],
	"belt": ["belt", "leather", "gold"],
	"sash": ["sash", "gold", "gold"],
	"green_sash": ["sash", "green", "green"],
	"moonstone_amulet": ["amulet", "gold", "gemblue"],
}

## Each skin tone: [skin, its shade].
const SKINS: Array[Array] = [
	[Color("#f6d4b4"), Color("#dca684")],
	[Color("#f0c39a"), Color("#c98a62")],
	[Color("#e0a87c"), Color("#b5745a")],
	[Color("#c98a5a"), Color("#a0643c")],
	[Color("#a0643c"), Color("#7a4628")],
	[Color("#7a4a26"), Color("#5a3218")],
]
## Each hair colour: [hair, highlight, shadow]. The shadow also colours brows.
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
## Each hair style a seed can draw; some come up more often than others.
const STYLES: PackedStringArray = ["bald", "short", "short", "long", "spiky", "bun", "spiky", "short", "short"]
## The materials of trousers and of boots a seed draws from.
const TROUSERS: PackedStringArray = ["brown", "purple", "green", "cream", "iron", "leather", "blue"]
const BOOTS: PackedStringArray = ["leather", "brown", "darkleather"]
## The undershirt anyone wears under their clothes: [cloth, shade].
const UNDERSHIRT: Array[Color] = [Color("#d8ccb4"), Color("#a8987c")]
const EYE_WHITE: Color = Color("#e2dcea")
const IRISES: Array[Color] = [Color("#4c82b6"), Color("#4c9044"), Color("#84532c")]
const LIPS: Color = Color("#a02e36")
const SCAR: Color = Color("#d0524a")
## Where the eyes sit, looking right: the back eye's column, the front eye's, and their lower row.
const EYE_BACK_X: int = 12
const EYE_FRONT_X: int = 15
const EYE_Y: int = 9
const MOUTH_Y: int = 11

# Shapes: each row is [row, first column, text], in shape coordinates (see ORIGIN). In the text,
# '.' leaves what is underneath. The body paints s/S skin and its shade, u/U the undershirt,
# p/P trousers, b/B boots; hair paints h hair, H its shadow, g its highlight.
const BODY: Array = [
	[2, 9, "ssssss"], [3, 7, "ssssssssss"],
	[4, 6, "ssssssssssss"], [5, 6, "ssssssssssss"], [6, 6, "ssssssssssss"], [7, 6, "ssssssssssss"],
	# The eyes and the mouth are drawn on after, by kind.
	[8, 6, "ssSsssssssss"], [9, 6, "ssSsssssssss"],
	[10, 7, "sssssssssss"], [11, 8, "ssssssssS"], [12, 10, "ssssS"],
	[13, 7, "uuuSSSuuuu"],
	[14, 4, "UUUuuuuuuuuuuUU"], [15, 4, "UUUuuuuuuuuuuUU"],
	[16, 4, "sssuuuuuuuuuuSS"], [17, 4, "sssuuuuuuuuuuSS"], [18, 4, "sssuuuuuuuuuuSS"],
	[19, 4, "sssuuuuuuuuuuSS"], [20, 4, "sssuuuuuuuuuuSS"],
	[21, 7, "pppppppppp"],
	[22, 7, "pppp.PPPP"], [23, 7, "pppp.PPPP"], [24, 7, "pppp.PPPP"],
	[25, 7, "pppp.BBBBB"], [26, 6, "bbbbbbBBBBB"], [27, 6, "bbbbbb"],
]
const HAIR_SHORT: Array = [
	[1, 9, "hhhhhh"], [2, 7, "hhhgghhhhh"], [3, 6, "hhhgghhhhhhh"], [4, 5, "Hhhhhhhhhhhhh"],
	[5, 5, "HHhhhhhhh.h.h"], [6, 5, "HHhh"], [7, 5, "HHh"], [8, 5, "H"], [9, 5, "H"],
]
const HAIR_SPIKY: Array = HAIR_SHORT + [[0, 8, "h.h.h.h"], [1, 7, "hh"], [1, 15, "hh"]]
const HAIR_LONG: Array = HAIR_SHORT + [[5, 18, "h"], [6, 18, "h"], [7, 18, "H"], [8, 18, "H"], [9, 18, "H"], [10, 18, "H"]]
## Long hair also falls down the back, behind the body.
const HAIR_LONG_BACK: Array = [
	[5, 3, "HHH"], [6, 3, "HHHH"], [7, 3, "HHHH"], [8, 3, "HHHH"], [9, 3, "HHHH"],
	[10, 3, "HHHH"], [11, 3, "HHHH"], [12, 3, "HHHH"], [13, 3, "HH"], [14, 3, "H"],
	[15, 3, "H"], [16, 3, "H"], [17, 3, "H"],
]
const HAIR_BUN: Array = HAIR_SHORT + [[0, 4, "hhh"], [1, 3, "hghhh"], [2, 3, "hhhhH"], [3, 4, "HHH"]]
const HAIR_SHAPES: Dictionary[String, Array] = {
	"bald": [], "short": HAIR_SHORT, "spiky": HAIR_SPIKY, "long": HAIR_LONG, "bun": HAIR_BUN,
}

const IRON_HELM: Array = [
	[1, 9, "223322"], [2, 7, "2233332222"], [3, 6, "223333222221"],
	[4, 5, "2222222222221"], [5, 5, "aaaaaaaaaaaaa"], [6, 5, "1221"], [7, 5, "121"],
	[8, 5, "11"], [6, 14, "3"], [7, 14, "3"], [8, 14, "2"], [0, 11, "44"],
]
const HORNS: Array = [
	[0, 3, "b"], [1, 3, "bb"], [2, 3, "Bb"], [3, 4, "bb"], [0, 19, "b"], [1, 19, "bb"],
	[2, 18, "bB"], [3, 17, "b"],
]
const HOOD: Array = [
	[0, 9, "22222"], [1, 7, "2222222"], [2, 5, "222333222"], [3, 4, "222333222221"],
	[4, 3, "22222222222221"], [5, 3, "122222222aaaa"], [6, 3, "122222"], [7, 4, "12222"],
	[8, 4, "12222"], [9, 4, "12222"], [10, 4, "122222"], [11, 4, "1222222"],
	[12, 5, "12222"], [13, 4, "122222"], [14, 4, "1222"],
]
const WIZARD_HAT: Array = [
	[-6, 17, "2"], [-5, 15, "22"], [-4, 14, "232"], [-3, 13, "2322"], [-2, 12, "23222"],
	[-1, 11, "232221"], [0, 10, "2322221"], [1, 10, "23222221"],
	[2, 9, "aaaaaaaaa"], [3, 3, "3222222222222222221"], [4, 4, "11111111111111111"],
]
const CIRCLET: Array = [[5, 6, "aaaaaaab.aaa"], [5, 13, "B"]]
const TUNIC: Array = [
	[13, 7, "322"], [13, 13, "2221"],
	[14, 4, "222322222221111"], [15, 4, "222322222221111"],
	[16, 7, "3222222211"], [17, 7, "3222222211"], [18, 7, "3222222211"],
	[19, 7, "3222222211"], [20, 7, "3222222211"], [21, 6, "a2222222221a"], [22, 6, "a........1"],
]
const ROBE: Array = [
	[13, 7, "322"], [13, 13, "2221"],
	[14, 4, "222322222221111"], [15, 4, "222322222221111"],
	[16, 4, "2223222222221111"], [17, 4, "2223222222221111"],
	[18, 4, "2223222222221111"], [19, 4, "aaa32222222211aa"],
	[20, 7, "3222222211"],
	[21, 6, "322222222211"], [22, 6, "322222222211"], [23, 5, "3222222222211"],
	[24, 5, "3222222222211"], [25, 5, "3222222222211"], [26, 5, "aaaaaaaaaaaaa"],
]
const VEST: Array = [
	[13, 8, "22"], [13, 13, "22"], [14, 8, "322.2211"], [15, 8, "322a2211"], [16, 8, "322.2211"],
	[17, 8, "322a2211"], [18, 8, "322.2211"], [19, 8, "322a2211"],
]
const PLATE: Array = [
	[13, 3, "2333"], [14, 3, "23332"], [15, 4, "111"], [13, 16, "221"], [14, 17, "21"],
	[14, 7, "3433322211"], [15, 7, "3433322211"], [16, 7, "3433322211"],
	[17, 7, "3433322211"], [18, 7, "3333222211"], [19, 7, "1111111111"],
	[20, 7, "2222222211"], [21, 6, "aaaaaaaaaaaa"],
]
const BELT: Array = [[20, 7, "1111aA1111"]]
const SASH: Array = [[20, 7, "aaaaaaaaaa"], [21, 9, "A"], [22, 9, "a"]]
const AMULET: Array = [[13, 10, "A.A"], [14, 11, "B"], [15, 11, "b"]]
## A cloak hangs behind the body, and its collar in front of the shoulders.
const CLOAK_BACK: Array = [
	[13, 2, "22"], [14, 1, "322"], [15, 1, "322"], [16, 1, "32"], [17, 1, "32"],
	[18, 1, "32"], [19, 1, "32"], [20, 1, "32"], [21, 1, "322"], [22, 2, "2222"],
	[23, 2, "22222"], [24, 3, "1111"], [15, 19, "1"], [16, 19, "1"], [17, 19, "1"],
	[18, 19, "1"], [19, 19, "1"], [20, 19, "11"], [21, 18, "111"],
]
const CLOAK_FRONT: Array = [[13, 5, "22a"], [13, 15, "a22"], [12, 7, "2"], [12, 16, "2"]]
const QUIVER: Array = [
	[5, 2, "bB"], [6, 1, "bBb"], [7, 2, "a"], [8, 1, "222"], [9, 1, "232"], [10, 1, "232"],
	[11, 1, "232"], [12, 1, "232"], [13, 1, "232"], [14, 1, "221"], [15, 1, "221"],
	[16, 2, "11"],
]
const SHORT_SWORD: Array = [
	[9, 3, "4"], [10, 3, "42"], [11, 3, "42"], [12, 3, "42"], [13, 3, "42"],
	[14, 3, "42"], [15, 3, "42"], [16, 3, "42"], [17, 3, "42"], [18, 3, "42"],
	[19, 2, "aaaaa"], [21, 4, "b"],
]
const MACE: Array = [
	[10, 4, "4.4"], [11, 3, "43334"], [12, 3, ".322."], [13, 3, "41114"], [14, 4, ".a."],
	[15, 5, "a"], [16, 5, "A"], [17, 5, "a"], [18, 5, "A"], [19, 5, "a"], [21, 5, "b"],
]


## The figure made from `face_seed` wearing `worn`, {slot: item id} as Gear.worn keeps it. The same
## seed and items always give the same figure. Drawn from a generator of its own, never the global
## one.
static func image(face_seed: int, worn: Dictionary) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = face_seed
	# The draws keep the order and ranges faces had before figures, so a seed keeps its skin, hair
	# colour and features. The first picked a head shape; every figure shares the one head now.
	rng.randi_range(0, 4)
	var skin: Array = SKINS[rng.randi_range(0, SKINS.size() - 1)]
	var hair: Array = HAIRS[rng.randi_range(0, HAIRS.size() - 1)]
	var style := STYLES[rng.randi_range(0, STYLES.size() - 1)]
	var trousers: Array = MATERIALS[TROUSERS[rng.randi_range(0, TROUSERS.size() - 1)]]
	var boots: Array = MATERIALS[BOOTS[rng.randi_range(0, BOOTS.size() - 1)]]
	var eyes := rng.randi_range(0, 4)
	var iris := IRISES[rng.randi_range(0, IRISES.size() - 1)]
	var brows := rng.randi_range(0, 3)
	var mouth := rng.randi_range(0, 4)
	var beard := rng.randi_range(0, 5)
	var scar := rng.randf() < 0.15
	var freckles := rng.randf() < 0.2

	var hair_colours := {"h": hair[0], "H": hair[2], "g": hair[1]}
	# A hood covers all the hair.
	var hooded := _shape_of(worn, "head") == "hood"
	var figure := Image.create_empty(SIZE_PX.x, SIZE_PX.y, false, Image.FORMAT_RGBA8)
	if style == "long" and not hooded:
		_paint(figure, HAIR_LONG_BACK, hair_colours)
	_wear(figure, worn, "back")
	_paint(figure, BODY, {
		"s": skin[0], "S": skin[1], "u": UNDERSHIRT[0], "U": UNDERSHIRT[1],
		"p": trousers[1], "P": trousers[0], "b": boots[2], "B": boots[1],
	})
	_draw_eyes(figure, eyes, iris)
	# Brows, in the hair's shadow.
	var brow_pixels: Array = [
		[Vector2i(12, 7), Vector2i(15, 7)],
		[Vector2i(11, 7), Vector2i(12, 7), Vector2i(15, 7), Vector2i(16, 7)],
		[Vector2i(11, 6), Vector2i(12, 7), Vector2i(15, 7), Vector2i(16, 6)],
		[Vector2i(11, 7), Vector2i(12, 6), Vector2i(15, 6), Vector2i(16, 7)],
	][brows]
	for at: Vector2i in brow_pixels:
		_dot(figure, at, hair[2])
	if freckles:
		for at: Vector2i in [Vector2i(11, 10), Vector2i(13, 10), Vector2i(16, 10), Vector2i(10, 9)]:
			_dot(figure, at, skin[1])
	# Half have no facial hair; then a moustache, a full beard or a chin beard, each beard with a
	# moustache.
	if beard >= 4:
		for y: int in range(10 if beard == 4 else 11, 13):
			for x: int in range(6 if beard == 4 else 11, 19):
				var at := ORIGIN + Vector2i(x, y)
				if figure.get_pixelv(at).to_rgba32() in [skin[0].to_rgba32(), skin[1].to_rgba32()]:
					figure.set_pixelv(at, hair[0])
		_dot(figure, Vector2i(11, 13), hair[2])
		_dot(figure, Vector2i(12, 13), hair[2])
	if beard >= 3:
		for x: int in range(13, 17):
			_dot(figure, Vector2i(x, 10), hair[0])
	_draw_mouth(figure, mouth, skin)
	if scar:
		for at: Vector2i in [Vector2i(16, 6), Vector2i(16, 7), Vector2i(15, 8), Vector2i(15, 10)]:
			_dot(figure, at, SCAR)
	for slot: String in ["clothes", "armour", "belt"]:
		_wear(figure, worn, slot)
	if not hooded:
		_paint(figure, HAIR_SHAPES[style], hair_colours)
	_wear(figure, worn, "head")
	_wear(figure, worn, "neck")
	if _shape_of(worn, "back") == "cloak":
		_paint_item(figure, worn["back"], CLOAK_FRONT)
	_wear(figure, worn, "weapon")
	_wear(figure, worn, "off_hand")
	_outline(figure)
	return figure


# The shape the item worn in `slot` is drawn with, or "" for none.
static func _shape_of(worn: Dictionary, slot: String) -> String:
	var item: String = worn.get(slot, "")
	return "" if item.is_empty() else LOOKS[item][0]


# Paints the item worn in `slot`, if any; of a cloak, the part behind the body.
static func _wear(figure: Image, worn: Dictionary, slot: String) -> void:
	var item: String = worn.get(slot, "")
	if not item.is_empty():
		_paint_item(figure, item, _shape(LOOKS[item][0]))


# Paints `shape` in `item`'s material and trim.
static func _paint_item(figure: Image, item: String, shape: Array) -> void:
	var material: Array = MATERIALS[LOOKS[item][1]]
	var trim: Array = MATERIALS[LOOKS[item][2]]
	_paint(figure, shape, {
		"1": material[0], "2": material[1], "3": material[2], "4": material[3],
		"A": trim[0], "a": trim[1], "b": trim[2], "B": trim[3],
	})


# The rows of the item shape called `shape_name`; the patterned ones are worked out here.
static func _shape(shape_name: String) -> Array:
	match shape_name:
		"iron_helm":
			return IRON_HELM
		"horned_helm":
			return IRON_HELM + HORNS
		"hood":
			return HOOD
		"cloak":
			return CLOAK_BACK
		"wizard_hat":
			return WIZARD_HAT
		"circlet":
			return CIRCLET
		"tunic":
			return TUNIC
		"robe":
			return ROBE
		"vest":
			return VEST
		"chainmail":
			return _chainmail()
		"plate":
			return PLATE
		"belt":
			return BELT
		"sash":
			return SASH
		"amulet":
			return AMULET
		"quiver":
			return QUIVER
		"short_sword":
			return SHORT_SWORD
		"long_sword":
			var long_sword: Array = [[3, 3, "4"], [4, 3, "42"]]
			for y: int in range(5, 19):
				long_sword.append([y, 3, "42"])
			return long_sword + [[19, 1, "Aaaaaab"], [21, 4, "B"], [11, 3, "3"]]
		"staff":
			var staff: Array = [[-5, 2, "aa"], [-4, 1, "abBa"], [-3, 1, "aBba"], [-2, 2, "aa"]]
			for y: int in range(-1, 20):
				staff.append([y, 3, "2" if y % 3 == 0 else "3"])
			return staff + [[21, 3, "2"], [22, 3, "2"], [23, 3, "1"]]
		"bow":
			var bow: Array = [
				[10, 3, "a"], [11, 2, "2"], [12, 2, "2"], [13, 1, "2"], [14, 1, "3"], [15, 0, "3"],
				[16, 0, "3"], [17, 0, "2"], [18, 0, "2"], [19, 0, "2"], [20, 0, "2"], [21, 0, "2"],
				[22, 1, "2"], [23, 1, "1"], [24, 2, "1"], [25, 2, "1"], [26, 3, "a"],
			]
			for y: int in range(11, 26):
				bow.append([y, 3, "b"])
			return bow
		"mace":
			return MACE
		"round_shield":
			return _round_shield()
	push_error("No shape called " + shape_name)
	return []


# Rings in a checker over the chest, arms and shoulders, darker on the far side.
static func _chainmail() -> Array:
	var rows: Array = []
	for y: int in range(13, 21):
		var columns: Array = [7, 8, 9, 13, 14, 15, 16] if y == 13 else range(7, 17)
		for x: int in columns:
			var near := (x + y) % 2 == 0
			if x >= 15:
				rows.append([y, x, "2" if near else "1"])
			else:
				rows.append([y, x, "3" if near else "2"])
	for y: int in [14, 15, 16]:
		for x: int in [4, 5, 6]:
			rows.append([y, x, "3" if (x + y) % 2 == 0 else "2"])
		for x: int in [17, 18]:
			rows.append([y, x, "2" if (x + y) % 2 == 0 else "1"])
	rows.append([21, 6, "111111111111"])
	return rows


# An oval shield on the near arm: lit top left, shaded bottom right, a trim rim and a boss.
static func _round_shield() -> Array:
	var rows: Array = []
	var centre := Vector2(18.0, 17.0)
	var radius := Vector2(4.6, 5.6)
	for y: int in range(10, 25):
		for x: int in range(12, 25):
			var off := Vector2(x, y) - centre
			var reach := (off.x / radius.x) ** 2 + (off.y / radius.y) ** 2
			if reach > 1.0:
				continue
			var tone := "2"
			if reach > 0.62:
				tone = "a" if off.x + off.y < 2.0 else "A"
			elif off.x + off.y < -2.5:
				tone = "3"
			elif off.x + off.y > 2.5:
				tone = "1"
			rows.append([y, x, tone])
	return rows + [[16, 18, "b"], [17, 17, "bB"], [18, 18, "B"]]


# Paints `shape` with each letter's colour in `colours`; '.' and anything off the figure are left.
static func _paint(figure: Image, shape: Array, colours: Dictionary) -> void:
	for row: Array in shape:
		var text: String = row[2]
		for i: int in text.length():
			if text[i] == ".":
				continue
			_dot(figure, Vector2i(row[1] + i, row[0]), colours[text[i]])


# `colour` at `at` in shape coordinates, when that is on the figure.
static func _dot(figure: Image, at: Vector2i, colour: Color) -> void:
	var on := ORIGIN + at
	if Rect2i(Vector2i.ZERO, SIZE_PX).has_point(on):
		figure.set_pixelv(on, colour)


# One of the eye kinds, looking right, `iris` for the kind that shows one.
static func _draw_eyes(figure: Image, kind: int, iris: Color) -> void:
	for x: int in [EYE_BACK_X, EYE_FRONT_X]:
		match kind:
			0:
				_dot(figure, Vector2i(x, EYE_Y - 1), INK)
				_dot(figure, Vector2i(x, EYE_Y), INK)
			1:
				_dot(figure, Vector2i(x, EYE_Y), INK)
			2:
				_dot(figure, Vector2i(x - 1, EYE_Y), EYE_WHITE)
				_dot(figure, Vector2i(x, EYE_Y), INK)
			3:
				_dot(figure, Vector2i(x - 1, EYE_Y), INK)
				_dot(figure, Vector2i(x, EYE_Y), INK)
			4:
				_dot(figure, Vector2i(x, EYE_Y - 1), INK)
				_dot(figure, Vector2i(x, EYE_Y), iris)


# One of the mouth kinds, over whatever beard there is.
static func _draw_mouth(figure: Image, kind: int, skin: Array) -> void:
	var line := skin[1].darkened(0.3) as Color
	match kind:
		0:
			_dot(figure, Vector2i(14, MOUTH_Y), line)
		1:
			_dot(figure, Vector2i(13, MOUTH_Y), line)
			_dot(figure, Vector2i(14, MOUTH_Y), line)
		2:
			_dot(figure, Vector2i(12, MOUTH_Y - 1), line)
			_dot(figure, Vector2i(13, MOUTH_Y), line)
			_dot(figure, Vector2i(14, MOUTH_Y), line)
			_dot(figure, Vector2i(15, MOUTH_Y - 1), line)
		3:
			_dot(figure, Vector2i(13, MOUTH_Y), line)
			_dot(figure, Vector2i(14, MOUTH_Y), line)
			_dot(figure, Vector2i(15, MOUTH_Y - 1), line)
		4:
			_dot(figure, Vector2i(14, MOUTH_Y), LIPS)
			_dot(figure, Vector2i(13, MOUTH_Y), line)


# The one ink outline around the whole figure: every empty pixel beside a drawn one.
static func _outline(figure: Image) -> void:
	var edge: Array[Vector2i] = []
	for y: int in SIZE_PX.y:
		for x: int in SIZE_PX.x:
			if figure.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var near := Vector2i(x, y) + step
				if Rect2i(Vector2i.ZERO, SIZE_PX).has_point(near) and figure.get_pixelv(near).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for at: Vector2i in edge:
		figure.set_pixelv(at, INK)
