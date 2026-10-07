# The Shop (docs/superpowers/specs/2026-10-07-equipment-shop-design.md): the Estate's cash buys looks for the winery
# (cosmetic) and vineyard & cellar equipment (changes the simulation). Every item card shows a picture, the price and a
# line about it; owned looks switch freely; "Preview" shows a look in the 3D winery without buying. Everything comes from
# the snapshot's "shop" (the sim decides what is owned and what it costs); the UI sends `buy` and `decor` commands.
extends RefCounted

const UI := preload("res://src/ui/ui.gd")
const THUMBS := "res://shop_thumbs/%s_%s.jpg"      # rendered by scripts/shop_thumbs.sh, committed
const INTERIOR := ["walls", "floor", "ceiling", "lights", "corner", "plants"]

static func build(D: Dictionary, shell) -> Control:
	var shop: Dictionary = D.get("shop", {})
	var v := UI.vbox(16)
	var cash := int(shop.get("cash", 0))
	v.add_child(UI.page_header("Shop", "Make the winery yours with the money your wine earns. Looks change nothing in the wine; equipment does, and each card says how.",
		[UI.num("Cash %s" % UI.euro(cash), 22, UI.INK if cash >= 0 else UI.CRIT)]))
	var flags := {}
	for x in D.get("flags", []): flags[String(x)] = true
	if not flags.has("intro_shop"):
		v.add_child(_intro(shell))
	var tab := String(shell.state.get("shop_tab", "Winery looks"))
	var seg := UI.segmented(["Winery looks", "Vineyard & cellar"], tab, func(x): shell.state["shop_tab"] = x; shell.refresh())
	v.add_child(seg)
	if shop.is_empty():
		v.add_child(UI.label("The Shop opens once a game is running.", 15, UI.MUTED))
	elif tab == "Vineyard & cellar":
		_equipment(v, shop, shell)
	else:
		_looks(v, shop, shell)
	return UI.scroll(v)


## The item's picture, read from the JPEG at run time (no import step needed); cached for the session.
static var _thumbs := {}
static func _thumb(key: String, value: String) -> Texture2D:
	var path := THUMBS % [key, value]
	if not _thumbs.has(path):
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_thumbs[path] = ImageTexture.create_from_image(img) if img else null
	return _thumbs[path]


static func _intro(shell) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(Color("1f2a24"), 6, UI.GOOD.darkened(0.2), 1, 14))
	var h := UI.hbox(14); p.add_child(h)
	var iv := UI.vbox(2); iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(iv)
	iv.add_child(UI.label("NEW HERE? · THE SHOP", 11, UI.GOOD.lightened(0.3), UI.f_body_b))
	iv.add_child(UI.label("Your Estate's cash buys paint, lights, furniture and more for the winery, and equipment for the vineyard and cellar. Try \"Preview\" to see a look in 3D first. Looks you own switch freely, at no cost.", 15, UI.INK, null, true))
	var ok := UI.button("Got it", true, 14); ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): shell.command("flag", "intro_shop"))
	h.add_child(ok)
	return p


static func _looks(v: VBoxContainer, shop: Dictionary, shell) -> void:
	for sec in shop.get("look", []):
		var key := String(sec["key"])
		var p: Array = UI.panel(String(sec["label"]), "cosmetic")
		var g := GridContainer.new(); g.columns = 4
		g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 12)
		p[1].add_child(g)
		for o in sec["options"]:
			g.add_child(_look_card(key, String(sec["label"]), o, shop, shell))
		v.add_child(p[0])
	v.add_child(UI.label("Prices are design values, roughly what the work would cost a small winery (UNVERIFIED). Looks are cosmetic: the simulation never reads them.", 13, UI.MUTED, null, true))


static func _look_card(key: String, section: String, o: Dictionary, shop: Dictionary, shell) -> Control:
	var value := String(o["value"])
	var owned := bool(o["owned"])
	var in_use := bool(o["inUse"])
	var c := UI.card(in_use, 10)
	c.custom_minimum_size = Vector2(250, 0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cv := UI.vbox(6); c.add_child(cv)
	var tex := _thumb(key, value)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(0, 120)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cv.add_child(tr)
	cv.add_child(UI.label(String(o["label"]), 16, UI.INK, UI.f_body_b))
	var bl := UI.label(String(o["blurb"]), 13, UI.INK2, null, true)
	bl.custom_minimum_size = Vector2(220, 0)
	cv.add_child(bl)
	var row := UI.hbox(8)
	if in_use:
		row.add_child(UI.label("✓ Owned · in use", 14, UI.GOLD, UI.f_body_b))
	elif owned:
		row.add_child(UI.label("Owned", 14, UI.GOOD))
		row.add_child(UI.spacer())
		var use := UI.button("Use", true, 14)
		use.pressed.connect(func():
			shell.command("decor", key, value)
			shell.notify("%s: %s is in use." % [section, o["label"]], true))
		row.add_child(use)
	else:
		row.add_child(UI.num(UI.euro(int(o["price"])), 16, UI.INK))
		row.add_child(UI.spacer())
		var pv := UI.button("Preview", false, 14)
		pv.tooltip_text = "See it on your winery in 3D. Nothing is bought; Tab or Esc comes back."
		pv.pressed.connect(func(): _preview(key, value, shell))
		row.add_child(pv)
		row.add_child(_buy_button(key, value, String(o["label"]), int(o["price"]), int(o.get("gap", 0)), int(shop.get("cash", 0)), shell))
	cv.add_child(row)
	return c


static func _buy_button(section: String, value: String, label: String, price: int, gap: int, cash: int, shell) -> Button:
	var b := UI.button("Buy", gap <= 0, 14)
	if gap > 0:
		b.disabled = true
		b.text = "%s short" % UI.euro(gap)
		b.tooltip_text = "You need %s more cash. Selling a Vintage's wine brings it in." % UI.euro(gap)
	else:
		b.tooltip_text = "Cash after: %s" % UI.euro(cash - price)
		b.pressed.connect(func():
			shell.command("buy", section, value)
			var why := String(Sim.ShopRefusal())
			if why != "": shell.notify(why)
			else: shell.notify("Bought: %s. Cash now %s." % [label, UI.euro(cash - price)], true))
	return b


## Shows the look in the 3D winery over the one in use, from a camera that sees it.
static func _preview(key: String, value: String, shell) -> void:
	if key == "cellar":
		shell.preview_3d({key: value}, "cellar", "cellar")
	elif key in INTERIOR:
		shell.preview_3d({key: value}, "hall", "hall")
	else:
		shell.preview_3d({key: value}, "vineyard", "yard")


static func _equipment(v: VBoxContainer, shop: Dictionary, shell) -> void:
	var p: Array = UI.panel("Vineyard & cellar", "changes the simulation")
	for e in shop.get("equipment", []):
		var owned := bool(e["owned"])
		var c := UI.card(owned, 14)
		var h := UI.hbox(16); c.add_child(h)
		var tex := _thumb("equipment", String(e["id"]))
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(180, 110)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			h.add_child(tr)
		var cv := UI.vbox(4); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(cv)
		cv.add_child(UI.label(String(e["label"]), 17, UI.INK, UI.f_body_b))
		cv.add_child(UI.label(String(e["blurb"]), 14, UI.INK2, null, true))
		cv.add_child(UI.label("In the game: " + String(e["what"]), 14, UI.INK, null, true))
		cv.add_child(UI.label("Where you'll notice it: " + String(e["when"]), 13, UI.MUTED, null, true))
		var right := UI.vbox(6); right.custom_minimum_size = Vector2(170, 0); h.add_child(right)
		var unavailable := String(e.get("unavailable", ""))
		if owned:
			right.add_child(UI.label("✓ Owned", 15, UI.GOLD, UI.f_body_b))
			if e.get("workingFrom") != null:
				right.add_child(UI.label("Being installed: works from %s" % e["workingFrom"], 13, UI.MUTED, null, true))
		elif unavailable != "":
			right.add_child(UI.label(unavailable, 13, UI.MUTED, null, true))
		else:
			right.add_child(UI.num(UI.euro(int(e["price"])), 18, UI.INK))
			right.add_child(_buy_button("equipment", String(e["id"]), String(e["label"]), int(e["price"]), int(e.get("gap", 0)), int(shop.get("cash", 0)), shell))
		p[1].add_child(c)
	v.add_child(p[0])
	v.add_child(UI.label("Equipment numbers are cited in docs/science/economy.md and phenology.md §6; values without a source are marked UNVERIFIED there.", 13, UI.MUTED, null, true))
