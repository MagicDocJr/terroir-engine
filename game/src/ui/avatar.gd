# Staff and Mentor portraits for the Inbox: a small drawn bust. The person's name seeds the face, and the role
# sets the backdrop colour and an accessory (vineyard cap + leaf badge, cellar apron + glass badge, Mentor grey hair + glasses).
extends Control

const UI := preload("res://src/ui/ui.gd")
const ROLE_BG := {"vineyard": Color("3f7d4e"), "cellar": Color("8a3345"), "mentor": Color("a07d2a"), "weather": Color("35698f")}
const SKIN := [Color("f3d9c1"), Color("e6bf9c"), Color("d2a07a"), Color("a8744e"), Color("7b5236")]
const LONG_HAIR_NAMES := ["Anja", "Marie", "Ursula", "Claire", "Léa", "Sylvie", "Hélène", "Kate", "Priya", "Linda"]
const HAIR := [Color("2b2019"), Color("4f341f"), Color("7d5230"), Color("c49a5c"), Color("171719"), Color("8e3a22")]

var person := ""
var role := "vineyard"
static var _fill_cache := {}   # clipped polygons are the expensive part; they only depend on person, role, size and order
var _fill_idx := 0

func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

static func make(name: String, role_: String, px := 44) -> Control:
	var a = load("res://src/ui/avatar.gd").new()
	a.person = name; a.role = role_
	a.custom_minimum_size = Vector2(px, px)
	a.tooltip_text = name
	return a

func _ellipse(c: Vector2, rx: float, ry: float, n := 32, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p

## Draw a polygon clipped to the round frame.
func _fill(poly: PackedVector2Array, disc: PackedVector2Array, col: Color) -> void:
	var key := "%s|%s|%d|%d" % [person, role, int(size.x), _fill_idx]
	_fill_idx += 1
	var pieces: Array = _fill_cache.get(key, [])
	if not _fill_cache.has(key):
		pieces = Geometry2D.intersect_polygons(poly, disc)
		_fill_cache[key] = pieces
	for piece in pieces:
		if piece.size() >= 3: draw_colored_polygon(piece, col)

func _draw() -> void:
	_fill_idx = 0
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var r := s / 2.0 - 0.5
	var h: int = abs(hash(person))
	var bg: Color = ROLE_BG.get(role, UI.RAISED)
	var disc := _ellipse(c, r, r, 48)
	draw_colored_polygon(disc, bg)
	draw_colored_polygon(_ellipse(c + Vector2(0, -r * 0.35), r * 0.9, r * 0.6, 32), bg.lightened(0.08))
	if role == "weather":
		var cc := Color("e4eaee")
		draw_circle(c + Vector2(-r * .3, r * .08), r * .26, cc); draw_circle(c + Vector2(r * .02, -r * .12), r * .34, cc); draw_circle(c + Vector2(r * .34, r * .1), r * .22, cc)
		draw_rect(Rect2(c.x - r * .3, c.y + r * .08, r * .64, r * .24), cc)
		return
	var skin: Color = SKIN[h % SKIN.size()]
	var hair: Color = HAIR[(h >> 4) % HAIR.size()]
	var long_hair := person.get_slice(" ", 0) in LONG_HAIR_NAMES and ((h >> 9) & 3) != 0
	if role == "mentor": hair = Color("d3d0c9"); long_hair = false
	var head_c := c + Vector2(0, -r * 0.12)
	var hr := r * 0.36
	# hair behind the head (long hair falls to the shoulders)
	if long_hair:
		_fill(_ellipse(head_c + Vector2(0, hr * 0.45), hr * 1.18, hr * 1.35, 32), disc, hair)
	# shoulders / clothing
	var shirt := Color("e9e3d6") if role == "cellar" else (Color("5b6f7d") if role == "mentor" else Color("d9d3bf").lerp(bg, 0.25))
	_fill(_ellipse(c + Vector2(0, r * 0.98), r * 0.82, r * 0.55, 40), disc, shirt)
	if role == "cellar":   # dark apron with a strap
		_fill(PackedVector2Array([c + Vector2(-r * .3, r * .5), c + Vector2(r * .3, r * .5), c + Vector2(r * .34, r * 1.1), c + Vector2(-r * .34, r * 1.1)]), disc, Color("4a2129"))
	if role == "mentor":   # collar
		_fill(PackedVector2Array([c + Vector2(-r * .16, r * .44), c + Vector2(0, r * .62), c + Vector2(r * .16, r * .44)]), disc, Color("f0ece2"))
	# neck and head
	draw_rect(Rect2(c.x - r * .11, head_c.y + hr * 0.6, r * .22, r * .3), skin.darkened(0.12))
	draw_colored_polygon(_ellipse(head_c, hr * 0.9, hr, 28), skin)
	# ears
	draw_circle(head_c + Vector2(-hr * 0.9, hr * 0.05), hr * 0.16, skin.darkened(0.06))
	draw_circle(head_c + Vector2(hr * 0.9, hr * 0.05), hr * 0.16, skin.darkened(0.06))
	# hair on top, or a cap for the Vineyard manager
	if role == "vineyard":
		var cap := Color("d9b24c") if ((h >> 6) & 1) == 0 else Color("e9e4d4")
		draw_colored_polygon(_ellipse(head_c + Vector2(0, -hr * 0.25), hr * 0.98, hr * 0.8, 20, PI, TAU), cap)
		draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.2, -hr * 0.3), head_c + Vector2(hr * 1.45, -hr * 0.22), head_c + Vector2(hr * 1.4, -hr * 0.08), head_c + Vector2(-hr * 0.2, -hr * 0.12)]), cap.darkened(0.18))
	else:
		draw_colored_polygon(_ellipse(head_c + Vector2(0, -hr * 0.28), hr * 0.98, hr * 0.78, 20, PI, TAU), hair)
		# a side parting fringe
		draw_colored_polygon(PackedVector2Array([head_c + Vector2(-hr * 0.9, -hr * 0.3), head_c + Vector2(hr * 0.3, -hr * 0.55), head_c + Vector2(-hr * 0.2, -hr * 0.05), head_c + Vector2(-hr * 0.88, hr * 0.1)]), hair)
	# face
	var ink := Color("2b2622")
	var lw := maxf(1.0, r * 0.045)
	draw_circle(head_c + Vector2(-hr * 0.34, hr * 0.08), maxf(1.2, hr * 0.1), ink)
	draw_circle(head_c + Vector2(hr * 0.34, hr * 0.08), maxf(1.2, hr * 0.1), ink)
	draw_arc(head_c + Vector2(0, hr * 0.3), hr * 0.32, 0.5, PI - 0.5, 10, ink, lw, true)
	if role == "mentor":   # glasses
		draw_arc(head_c + Vector2(-hr * 0.34, hr * 0.08), hr * 0.24, 0, TAU, 16, ink, lw, true)
		draw_arc(head_c + Vector2(hr * 0.34, hr * 0.08), hr * 0.24, 0, TAU, 16, ink, lw, true)
		draw_line(head_c + Vector2(-hr * 0.1, hr * 0.06), head_c + Vector2(hr * 0.1, hr * 0.06), ink, lw)
	# role badge, bottom right
	if role in ["vineyard", "cellar"]:
		var bc := c + Vector2(r * 0.66, r * 0.66)
		var br := r * 0.3
		draw_circle(bc, br, Color("f4f0e4"))
		draw_arc(bc, br, 0, TAU, 20, bg.darkened(0.2), maxf(1.0, r * 0.05), true)
		if role == "vineyard":   # grape leaf
			draw_colored_polygon(PackedVector2Array([bc + Vector2(0, -br * .7), bc + Vector2(br * .3, -br * .3), bc + Vector2(br * .65, -br * .35), bc + Vector2(br * .45, br * .05), bc + Vector2(br * .55, br * .4), bc + Vector2(0, br * .6), bc + Vector2(-br * .55, br * .4), bc + Vector2(-br * .45, br * .05), bc + Vector2(-br * .65, -br * .35), bc + Vector2(-br * .3, -br * .3)]), Color("3d8b4a"))
		else:   # a glass of red
			draw_colored_polygon(_ellipse(bc + Vector2(0, -br * 0.22), br * 0.42, br * 0.36, 12, 0, PI), Color("8e1f33"))
			draw_line(bc + Vector2(-br * 0.42, -br * 0.22), bc + Vector2(br * 0.42, -br * 0.22), Color("8e1f33"), maxf(1.0, r * 0.04))
			draw_line(bc + Vector2(0, br * 0.14), bc + Vector2(0, br * 0.5), Color("6f6f6f"), maxf(1.0, r * 0.05))
			draw_line(bc + Vector2(-br * 0.25, br * 0.52), bc + Vector2(br * 0.25, br * 0.52), Color("6f6f6f"), maxf(1.0, r * 0.05))
	draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.3), 1.0, true)
