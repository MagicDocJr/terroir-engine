# PROTOTYPE — design tokens, fonts, theme and small widget helpers ("Mosel slate & chalk").
# Palette: slate surfaces, chalk ink, Riesling gold used ONLY for primary actions and selection.
# Block colours = validated categorical slots 1–5 (dataviz reference, dark mode, surface #222B33: CVD ΔE 8.4, contrast ≥ 3:1).
extends RefCounted

const BG := Color("1c232a")        # slate
const SURFACE := Color("222b33")   # panel / chart surface (palette validated against this)
const RAISED := Color("2b3640")
const SUNKEN := Color("182026")
const LINE := Color("36434f")
const INK := Color("ece6d8")       # chalk
const INK2 := Color("aeb5b9")
const MUTED := Color("75818a")
const GOLD := Color("d9b24c")      # Riesling gold: actions + selection only
const GOLD_INK := Color("1d1708")
const BLOCK := {"A": Color("3987e5"), "B": Color("d95926"), "C": Color("199e70"), "D": Color("c98500"), "E": Color("d55181")}
const GOOD := Color("0ca30c")
const WARN := Color("fab219")
const SERIOUS := Color("ec835a")
const CRIT := Color("d03b3b")
const SEQ := Color("3987e5")       # sequential single hue (blue) for magnitude tints

static var f_body: FontVariation
static var f_body_b: FontVariation
static var f_num: FontFile
static var f_head: FontFile
static var f_reg: FontFile

static func init_fonts() -> void:
	if f_body: return
	var inter: FontFile = load("res://fonts/Inter-Variable.ttf")
	f_body = FontVariation.new(); f_body.base_font = inter
	f_body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 420}
	f_body_b = FontVariation.new(); f_body_b.base_font = inter
	f_body_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 620}
	f_num = load("res://fonts/BarlowSemiCondensed-Medium.ttf")
	f_head = load("res://fonts/BarlowSemiCondensed-SemiBold.ttf")
	f_reg = load("res://fonts/BarlowSemiCondensed-Regular.ttf")
	for f in [inter, f_num, f_head, f_reg]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO

static func sb(col: Color, radius := 6, border := Color(0, 0, 0, 0), bw := 0, pad := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad; s.content_margin_right = pad
	s.content_margin_top = pad * 0.6; s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s

static func make_theme() -> Theme:
	init_fonts()
	var t := Theme.new()
	t.default_font = f_body
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", sb(SURFACE, 6, LINE, 1, 16))
	t.set_stylebox("normal", "Button", sb(RAISED, 4, LINE, 1, 12))
	t.set_stylebox("hover", "Button", sb(RAISED.lightened(0.07), 4, GOLD.darkened(0.35), 1, 12))
	t.set_stylebox("pressed", "Button", sb(GOLD.darkened(0.6), 4, GOLD, 1, 12))
	t.set_stylebox("disabled", "Button", sb(SUNKEN, 4, LINE, 1, 12))
	t.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), 4, GOLD, 2, 12))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font("font", "Button", f_body_b)
	t.set_font_size("font_size", "Button", 15)
	t.set_stylebox("panel", "TooltipPanel", sb(Color("11171c"), 5, GOLD.darkened(0.3), 1, 12))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", f_body)
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_stylebox("normal", "LineEdit", sb(SUNKEN, 4, LINE, 1, 12))
	t.set_stylebox("focus", "LineEdit", sb(SUNKEN, 4, GOLD, 1, 12))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("normal", "OptionButton", sb(RAISED, 4, LINE, 1, 12))
	t.set_stylebox("hover", "OptionButton", sb(RAISED.lightened(0.07), 4, GOLD.darkened(0.35), 1, 12))
	t.set_stylebox("pressed", "OptionButton", sb(RAISED, 4, GOLD, 1, 12))
	t.set_stylebox("focus", "OptionButton", sb(Color(0, 0, 0, 0), 4, GOLD, 2, 12))
	t.set_font("font", "OptionButton", f_body)
	t.set_font_size("font_size", "OptionButton", 15)
	t.set_stylebox("panel", "PopupMenu", sb(Color("11171c"), 5, LINE, 1, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("hover", "PopupMenu", sb(GOLD.darkened(0.6), 3, Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("scroll", "VScrollBar", sb(SUNKEN, 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber", "VScrollBar", sb(LINE, 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb(MUTED, 4, Color(0, 0, 0, 0), 0, 3))
	t.set_stylebox("background", "ProgressBar", sb(SUNKEN, 3, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", sb(GOOD, 3, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("slider", "HSlider", sb(SUNKEN, 3, Color(0, 0, 0, 0), 0, 3))
	return t

# ------------------------------------------------------------------ builders
static func label(text: String, size := 16, col := INK, f: Font = null, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f: l.add_theme_font_override("font", f)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func num(text: String, size := 18, col := INK) -> Label:
	init_fonts()
	return label(text, size, col, f_num)

static func head(text: String, size := 20, col := INK) -> Label:
	init_fonts()
	return label(text, size, col, f_head)

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v

## A row that wraps onto the next line when it runs out of width (children keep their minimum size; expanding
## children share each line's spare width).
static func flow(hsep := 12, vsep := 12) -> HFlowContainer:
	var f := HFlowContainer.new(); f.add_theme_constant_override("h_separation", hsep); f.add_theme_constant_override("v_separation", vsep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

static func spacer(expand_h := true, fixed := 0) -> Control:
	var c := Control.new()
	if fixed > 0:
		c.custom_minimum_size = Vector2(fixed, fixed)
	elif expand_h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## Panel with a sentence-case title and an optional right-aligned hint. Returns [panel, body VBox].
static func panel(title: String, hint := "", sep := 12) -> Array:
	var p := PanelContainer.new()
	var v := vbox(sep)
	p.add_child(v)
	if title != "":
		var h := hbox(12)
		h.add_child(head(title, 19, INK))
		if hint != "":
			h.add_child(spacer())
			var hl := label(hint, 14, MUTED)
			hl.size_flags_vertical = Control.SIZE_SHRINK_END
			h.add_child(hl)
		v.add_child(h)
	return [p, v]

static func button(text: String, primary := false, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.add_theme_stylebox_override("normal", sb(GOLD, 4, GOLD.lightened(0.2), 1, 16))
		b.add_theme_stylebox_override("hover", sb(GOLD.lightened(0.1), 4, GOLD.lightened(0.35), 1, 16))
		b.add_theme_stylebox_override("pressed", sb(GOLD.darkened(0.1), 4, GOLD.lightened(0.35), 1, 16))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, GOLD_INK)
	return b

static func chip(text: String, col: Color, size := 14, filled := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(col.darkened(0.55) if filled else Color(col, 0.14), 11, Color(col, 0.7), 1, 10))
	p.add_child(label(text, size, col.lightened(0.35)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p

## Block identity marker: letter on its categorical colour (identity never relies on colour alone: the letter is shown).
static func block_tag(id: String, size := 16) -> PanelContainer:
	init_fonts()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(BLOCK[id], 4, Color(0, 0, 0, 0), 0, 7))
	var l := label(id, size, Color("0f1418"), f_head)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.custom_minimum_size = Vector2(size + 12, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## Status marker: icon + word + colour (never colour alone).
static func status(kind: String, text := "") -> HBoxContainer:
	var map := {"good": [GOOD, "●", "Good"], "warn": [WARN, "▲", "Watch"], "serious": [SERIOUS, "▲", "Serious"], "crit": [CRIT, "◆", "Critical"], "idle": [MUTED, "○", "Idle"]}
	var m: Array = map.get(kind, map["idle"])
	var h := hbox(6)
	h.add_child(label(m[1], 13, m[0]))
	h.add_child(label(text if text != "" else m[2], 15, INK2))
	return h

static func risk_kind(v: float) -> String:
	return "good" if v < 20 else ("warn" if v < 35 else "serious")

static func risk_col(v: float) -> Color:
	return GOOD if v < 20 else (WARN if v < 35 else SERIOUS)

## FM-style 1–20 attribute rating colour.
static func rating_col(v: int) -> Color:
	if v >= 16: return Color("7ed36f")
	if v >= 13: return Color("c3d45b")
	if v >= 10: return Color("e2c04e")
	if v >= 7: return Color("e08e45")
	return Color("d9594a")

static func thousands(n: int) -> String:
	var neg := n < 0
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return ("−" if neg else "") + out

static func euro(n: int) -> String:
	return ("−€" if n < 0 else "€") + thousands(absi(n))

static func table_cell(text: String, w: float, fg := INK, bg := Color(0, 0, 0, 0), tip := "", f: Font = null, size := 17, h := 40.0) -> PanelContainer:
	init_fonts()
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", sb(bg, 3, Color(0, 0, 0, 0), 0, 9))
	var l := label(text, size, fg, f if f else f_num)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	p.add_child(l)
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p

## Screen title (large condensed) with a plain-language subtitle and optional controls on the right.
static func page_header(title: String, sub: String, right: Array = []) -> HBoxContainer:
	var h := hbox(16)
	var v := vbox(2); h.add_child(v)
	v.add_child(head(title, 32, INK))
	if sub != "": v.add_child(label(sub, 15, INK2))
	h.add_child(spacer())
	for n in right:
		(n as Control).size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(n)
	return h

## Segmented control: one button per option, the chosen one highlighted. on_pick(option) is called on click.
static func segmented(options: Array, chosen: String, on_pick: Callable, min_w := 0.0) -> HBoxContainer:
	var h := hbox(4)
	for o in options:
		var b := button(String(o), false, 15)
		if min_w > 0: b.custom_minimum_size = Vector2(min_w, 36)
		if String(o) == chosen:
			b.add_theme_stylebox_override("normal", sb(GOLD.darkened(0.62), 4, GOLD, 1, 12))
			b.add_theme_color_override("font_color", GOLD.lightened(0.35))
		b.pressed.connect(on_pick.bind(String(o)))
		h.add_child(b)
	return h

static func divider() -> ColorRect:
	var r := ColorRect.new(); r.color = LINE; r.custom_minimum_size = Vector2(0, 1); return r

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

## Dropdown: items are [value, text] pairs (or plain strings). on_pick(value) is called on change.
static func option(items: Array, chosen: String, on_pick: Callable, min_w := 160.0) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(min_w, 36)
	o.add_theme_font_size_override("font_size", 15)
	var values := []
	for it in items:
		var v: String = String(it[0]) if it is Array else String(it)
		var t: String = String(it[1]) if it is Array else String(it)
		o.add_item(t)
		values.append(v)
		if v == chosen: o.select(values.size() - 1)
	o.item_selected.connect(func(i): on_pick.call(values[i]))
	return o

static func line_edit(text: String, on_change: Callable, min_w := 260.0) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.custom_minimum_size = Vector2(min_w, 38)
	e.add_theme_font_size_override("font_size", 16)
	e.text_changed.connect(on_change)
	return e

## Clickable card: a panel that calls on_click when pressed. selected draws the gold edge.
static func card(selected := false, pad := 16.0) -> PanelContainer:
	var p := PanelContainer.new()
	var st := sb(RAISED if selected else SURFACE, 6, GOLD if selected else LINE, 2 if selected else 1, pad)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return p

static func on_click(c: Control, f: Callable) -> void:
	c.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: f.call())

## Key/value row for detail panels.
static func kv(k: String, v: String, tip := "", vcol := INK) -> HBoxContainer:
	var h := hbox(8)
	var kl := label(k, 15, INK2); kl.custom_minimum_size = Vector2(170, 0); h.add_child(kl)
	var vl := label(v, 15, vcol, null, true); vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(vl)
	if tip != "": h.tooltip_text = tip; h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h

## Big number tile: caption above, value below, optional sub-line.
static func tile(caption: String, value: String, sub := "", col := INK) -> PanelContainer:
	var p := PanelContainer.new()
	var v := vbox(2); p.add_child(v)
	v.add_child(label(caption, 14, INK2))
	v.add_child(num(value, 28, col))
	if sub != "": v.add_child(label(sub, 13, MUTED, null, true))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p

static func fmt(v, d := 1) -> String:
	if v == null: return "—"
	return ("%." + str(d) + "f") % float(v)
