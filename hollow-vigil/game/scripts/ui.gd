class_name UI
extends CanvasLayer
## All 2D interface: HUD, notes, merchant, menus, cinematic text.

signal note_closed
signal choice_made(index: int)
signal menu_action(action: String)

var main: Node
var serif: SystemFont
var hud: Control
var hp_fill: ColorRect
var hp_back: ColorRect
var hp_label: Label
var ammo_label: Label
var weapon_label: Label
var coins_label: Label
var items_label: Label
var objective: Label
var subtitle_lbl: Label
var msg_lbl: Label
var prompt_lbl: Label
var hurt_rect: ColorRect
var fade_rect: ColorRect
var card_big: Label
var card_small: Label
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var bars: Array[ColorRect] = []
var big_lbl: Label
var modal: Control = null
var modal_name := ""
var _msg_tw: Tween
var _sub_tw: Tween
var _card_tw: Tween
var _ecg_t := 0.0
var ecg: Line2D


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "DejaVu Serif", "Georgia", "serif"])
	_build_hud()
	Game.changed.connect(refresh)
	Game.message.connect(message)
	refresh()


# ------------------------------------------------------------------ builders
func _label(parent: Control, size: int, color := Color(0.9, 0.88, 0.82), use_serif := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	if use_serif:
		l.add_theme_font_override("font", serif)
	parent.add_child(l)
	return l


func _rect(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_hud() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_full(root)

	hurt_rect = _rect(root, Color(0.55, 0.0, 0.0, 0.0))
	_full(hurt_rect)

	for i in 2:
		var b := _rect(root, Color.BLACK)
		b.anchor_left = 0
		b.anchor_right = 1
		b.anchor_top = 0 if i == 0 else 1
		b.anchor_bottom = 0 if i == 0 else 1
		b.offset_top = 0 if i == 0 else 0
		b.offset_bottom = 0
		bars.append(b)

	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_full(hud)

	var panel := _rect(hud, Color(0, 0, 0, 0.45))
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.offset_left = -300
	panel.offset_right = -20
	panel.offset_top = -150
	panel.offset_bottom = -20
	hp_back = _rect(panel, Color(0.15, 0.02, 0.02))
	hp_back.position = Vector2(14, 14)
	hp_back.size = Vector2(252, 34)
	hp_fill = _rect(panel, Color(0.1, 0.55, 0.2))
	hp_fill.position = Vector2(14, 14)
	hp_fill.size = Vector2(252, 34)
	ecg = Line2D.new()
	ecg.width = 2
	ecg.default_color = Color(0.8, 1, 0.8, 0.9)
	ecg.position = Vector2(14, 14)
	panel.add_child(ecg)
	hp_label = _label(panel, 14)
	hp_label.position = Vector2(18, 16)
	weapon_label = _label(panel, 16, Color(0.85, 0.8, 0.65))
	weapon_label.position = Vector2(14, 56)
	ammo_label = _label(panel, 30)
	ammo_label.position = Vector2(14, 74)
	coins_label = _label(panel, 16, Color(0.95, 0.8, 0.3))
	coins_label.position = Vector2(170, 56)
	items_label = _label(panel, 14, Color(0.6, 0.85, 0.6))
	items_label.position = Vector2(170, 84)

	objective = _label(hud, 18, Color(0.85, 0.82, 0.7), true)
	objective.position = Vector2(24, 18)

	msg_lbl = _label(root, 20, Color(0.95, 0.92, 0.8))
	msg_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.offset_left = -500
	msg_lbl.offset_right = 500
	msg_lbl.offset_top = -210
	msg_lbl.offset_bottom = -180
	msg_lbl.modulate.a = 0

	subtitle_lbl = _label(root, 24, Color(1, 0.95, 0.85), true)
	subtitle_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle_lbl.offset_left = -520
	subtitle_lbl.offset_right = 520
	subtitle_lbl.offset_top = -175
	subtitle_lbl.offset_bottom = -95
	subtitle_lbl.modulate.a = 0

	prompt_lbl = _label(root, 20, Color(1, 1, 1))
	prompt_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.offset_left = -300
	prompt_lbl.offset_right = 300
	prompt_lbl.offset_top = 80
	prompt_lbl.offset_bottom = 110

	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_box)
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_left = -300
	boss_box.offset_right = 300
	boss_box.offset_top = 20
	boss_box.offset_bottom = 70
	boss_name = _label(boss_box, 18, Color(0.9, 0.7, 0.6), true)
	boss_name.position = Vector2(0, 0)
	var bb := _rect(boss_box, Color(0.1, 0, 0, 0.7))
	bb.position = Vector2(0, 28)
	bb.size = Vector2(600, 12)
	boss_fill = _rect(boss_box, Color(0.6, 0.05, 0.05))
	boss_fill.position = Vector2(0, 28)
	boss_fill.size = Vector2(600, 12)
	boss_box.visible = false

	card_big = _label(root, 64, Color(0.85, 0.1, 0.08), true)
	card_big.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_big.offset_left = -640
	card_big.offset_right = 640
	card_big.offset_top = -80
	card_big.offset_bottom = 0
	card_big.modulate.a = 0
	card_small = _label(root, 22, Color(0.8, 0.78, 0.7), true)
	card_small.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_small.offset_left = -640
	card_small.offset_right = 640
	card_small.offset_top = 5
	card_small.offset_bottom = 40
	card_small.modulate.a = 0

	big_lbl = _label(root, 30, Color(0.9, 0.88, 0.8), true)
	_full(big_lbl)
	big_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	big_lbl.offset_left = 120
	big_lbl.offset_right = -120
	big_lbl.modulate.a = 0

	fade_rect = _rect(root, Color(0, 0, 0, 1))
	_full(fade_rect)
	fade_rect.move_to_front()
	big_lbl.move_to_front()


# ------------------------------------------------------------------ HUD
func refresh() -> void:
	if hp_fill == null:
		return
	var r := clampf(Game.hp / Game.max_hp, 0, 1)
	hp_fill.size.x = 252 * r
	hp_fill.color = Color(0.1, 0.55, 0.2) if r > 0.5 else (Color(0.75, 0.6, 0.1) if r > 0.25 else Color(0.8, 0.1, 0.05))
	hp_label.text = "FINE" if r > 0.5 else ("CAUTION" if r > 0.25 else "DANGER")
	var w := Game.weapon
	weapon_label.text = Game.WEAPONS[w].name
	ammo_label.text = "%d / %d" % [Game.mag[w], Game.reserve(w)]
	coins_label.text = "₵ %d" % Game.coins
	var t := "Herbs %d" % Game.herbs
	if Game.sprays > 0:
		t += "  Spray %d" % Game.sprays
	if Game.is_haunted():
		t += "\nShards %d/5" % Game.shards
	items_label.text = t


func _process(delta: float) -> void:
	hurt_rect.color.a = maxf(0.0, hurt_rect.color.a - delta * 0.8)
	if Game.hp > 0 and Game.hp < 30 and hud.visible:
		hurt_rect.color.a = maxf(hurt_rect.color.a, 0.12 + sin(Time.get_ticks_msec() * 0.006) * 0.06)
	_ecg_t += delta * (1.0 + (1.0 - Game.hp / Game.max_hp) * 1.5)
	var pts := PackedVector2Array()
	for i in 64:
		var x := i * 4.0
		var ph := fmod(_ecg_t * 1.2 - i / 64.0, 1.0)
		var y := 17.0
		if ph < 0.06:
			y = 17.0 - sin(ph / 0.06 * PI) * 14.0
		elif ph < 0.1:
			y = 17.0 + sin((ph - 0.06) / 0.04 * PI) * 6.0
		pts.append(Vector2(x, y))
	ecg.points = pts


func set_objective(t: String) -> void:
	objective.text = ("▸ " + t) if t != "" else ""


func show_hud(on: bool) -> void:
	hud.visible = on
	if not on:
		prompt_lbl.text = ""


func prompt(t: String) -> void:
	prompt_lbl.text = t


func prompt_hint(t: String) -> void:
	message(t, 3.0)


func message(t: String, secs := 3.0) -> void:
	msg_lbl.text = t
	msg_lbl.modulate.a = 1
	if _msg_tw:
		_msg_tw.kill()
	_msg_tw = create_tween()
	_msg_tw.tween_interval(secs)
	_msg_tw.tween_property(msg_lbl, "modulate:a", 0.0, 0.5)


func subtitle(t: String, secs := 3.5) -> void:
	subtitle_lbl.text = t
	subtitle_lbl.modulate.a = 1
	if _sub_tw:
		_sub_tw.kill()
	_sub_tw = create_tween()
	_sub_tw.tween_interval(secs)
	_sub_tw.tween_property(subtitle_lbl, "modulate:a", 0.0, 0.4)


func title_card(big: String, small := "", color := Color(0.85, 0.1, 0.08)) -> void:
	card_big.text = big
	card_small.text = small
	card_big.add_theme_color_override("font_color", color)
	if _card_tw:
		_card_tw.kill()
	_card_tw = create_tween()
	_card_tw.tween_property(card_big, "modulate:a", 1.0, 0.8)
	_card_tw.parallel().tween_property(card_small, "modulate:a", 1.0, 1.2)
	_card_tw.tween_interval(2.5)
	_card_tw.tween_property(card_big, "modulate:a", 0.0, 1.0)
	_card_tw.parallel().tween_property(card_small, "modulate:a", 0.0, 1.0)


func hide_card() -> void:
	if _card_tw:
		_card_tw.kill()
	card_big.modulate.a = 0
	card_small.modulate.a = 0


func hurt(amount: float) -> void:
	hurt_rect.color.a = clampf(0.25 + amount / 60.0, 0.0, 0.7)


func fade(to_alpha: float, secs := 1.0) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", to_alpha, secs)
	return tw


func cinema(on: bool, secs := 0.8) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(bars[0], "offset_bottom", 80.0 if on else 0.0, secs)
	tw.tween_property(bars[1], "offset_top", -80.0 if on else 0.0, secs)
	show_hud(not on and main.state != "title")


func big_text(t: String, hold := 3.0, color := Color(0.9, 0.88, 0.8)) -> Tween:
	big_lbl.text = t
	big_lbl.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(big_lbl, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(big_lbl, "modulate:a", 0.0, 0.8)
	return tw


func boss_bar(n: String, ratio: float) -> void:
	boss_box.visible = ratio >= 0.0
	boss_name.text = n
	boss_fill.size.x = 600 * clampf(ratio, 0, 1)


# ------------------------------------------------------------------ modal panels
func _panel(w := 720.0, h := 480.0, color := Color(0.06, 0.05, 0.045, 0.95)) -> PanelContainer:
	close_modal()
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.4, 0.3, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	pc.add_theme_stylebox_override("panel", sb)
	add_child(pc)
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pc.offset_left = -w / 2
	pc.offset_right = w / 2
	pc.offset_top = -h / 2
	pc.offset_bottom = h / 2
	modal = pc
	return pc


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_font_override("font", serif)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
	modal_name = ""


func show_note(title: String, body: String) -> void:
	var pc := _panel(760, 540, Color(0.78, 0.72, 0.6, 0.97))
	modal_name = "note"
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var t := _label(vb, 30, Color(0.25, 0.12, 0.08), true)
	t.add_theme_constant_override("outline_size", 0)
	t.text = title
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = false
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", Color(0.15, 0.1, 0.08))
	rt.add_theme_font_override("normal_font", serif)
	rt.add_theme_font_override("italics_font", serif)
	rt.add_theme_font_size_override("normal_font_size", 21)
	rt.add_theme_font_size_override("italics_font_size", 21)
	rt.text = body
	vb.add_child(rt)
	var hint := _label(vb, 14, Color(0.3, 0.2, 0.15))
	hint.add_theme_constant_override("outline_size", 0)
	hint.text = "[E] / [Esc] close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func show_choice(question: String, options: Array) -> void:
	var pc := _panel(640, 120 + options.size() * 56)
	modal_name = "choice"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var q := _label(vb, 24, Color(0.9, 0.85, 0.75), true)
	q.text = question
	q.autowrap_mode = TextServer.AUTOWRAP_WORD
	for i in options.size():
		var idx := i
		_button(vb, options[i], func(): close_modal(); choice_made.emit(idx))
	vb.get_child(1).grab_focus.call_deferred()


func show_merchant() -> void:
	var pc := _panel(760, 560, Color(0.04, 0.05, 0.08, 0.96))
	modal_name = "merchant"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	var t := _label(vb, 28, Color(0.6, 0.75, 1.0), true)
	t.text = "THE PEDDLER"
	var sub := _label(vb, 17, Color(0.7, 0.7, 0.75), true)
	sub.text = "\"Heh heh... crowns spend the same on both sides of the veil, pilgrim.\"      You have ₵ %d" % Game.coins
	var items := [
		["Handgun rounds x15", 350, func(): Game.add_ammo("handgun", 15)],
		["Green herb", 600, func(): Game.herbs += 1],
		["First aid spray", 1500, func(): Game.sprays += 1],
	]
	if not Game.weapons.has("shotgun"):
		items.append(["SHOTGUN (+6 shells)", 2000, func(): Game.give_weapon("shotgun"); Game.add_ammo("shells", 6); main.player.refresh_gun()])
	else:
		items.append(["Shotgun shells x6", 500, func(): Game.add_ammo("shells", 6)])
	if Game.weapons.has("magnum"):
		items.append(["Magnum rounds x4", 1200, func(): Game.add_ammo("magnum", 4)])
	if Game.dmg_mult.handgun < 1.6:
		items.append(["Tune handgun: firepower +30%", 2200, func(): Game.dmg_mult.handgun += 0.3])
	if Game.mag_bonus.handgun < 8:
		items.append(["Tune handgun: capacity +4", 1400, func(): Game.mag_bonus.handgun += 4])
	if Game.weapons.has("shotgun") and Game.dmg_mult.shotgun < 1.5:
		items.append(["Tune shotgun: firepower +25%", 3000, func(): Game.dmg_mult.shotgun += 0.25])
	if Game.max_hp < 150:
		items.append(["Strange yellow herb (max health +25)", 2600, func(): Game.max_hp += 25; Game.hp += 25])
	for it in items:
		var price: int = it[1]
		var cb: Callable = it[2]
		var b := _button(vb, "%s  —  ₵ %d" % [it[0], price], func():
			if Game.coins >= price:
				Game.coins -= price
				cb.call()
				Sfx.play("coins")
				Game.changed.emit()
				show_merchant()
			else:
				Sfx.play("empty")
				message("\"Not enough crowns, stranger.\"", 1.5))
		b.disabled = Game.coins < price
	_button(vb, "Leave", func(): main.close_modal())
	vb.get_child(2).grab_focus.call_deferred()


func show_pause() -> void:
	var pc := _panel(620, 520)
	modal_name = "pause"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var t := _label(vb, 34, Color(0.85, 0.1, 0.08), true)
	t.text = "PAUSED"
	var info := _label(vb, 17, Color(0.8, 0.78, 0.7))
	var ws := []
	for w in Game.weapons:
		ws.append("%s %d/%d" % [Game.WEAPONS[w].name, Game.mag[w], Game.reserve(w)])
	var k := []
	for key in Game.keys:
		k.append(key)
	info.text = "Loop %d    Time %s    Kills %d\nWeapons: %s\nHerbs %d   Sprays %d   Crowns %d%s\nKey items: %s" % [
		Game.loop, Game.format_time(Game.run_time), Game.kills, ", ".join(ws), Game.herbs, Game.sprays, Game.coins,
		("   Shards %d/5" % Game.shards) if Game.is_haunted() else "", ", ".join(k) if k.size() else "none"]
	_button(vb, "Resume", func(): main.close_modal())
	_button(vb, "Use healing item", func(): main.player.use_heal(); show_pause())
	_button(vb, "Controls", func(): show_note("CONTROLS", CONTROLS))
	_button(vb, "Quit to title", func(): main.close_modal(); main.to_title())
	vb.get_child(2).grab_focus.call_deferred()


const CONTROLS := "[b]WASD[/b] move    [b]Shift[/b] run    [b]Mouse[/b] look\n[b]Right mouse[/b] aim (you cannot walk while aiming)\n[b]Left mouse[/b] fire while aiming    [b]R[/b] reload\n[b]F[/b] knife (breaks crates)    [b]E[/b] interact / KICK staggered enemies\n[b]Q[/b] quick 180° turn    [b]1 2 3[/b] switch weapon\n[b]H[/b] heal    [b]L[/b] flashlight    [b]Esc / Tab[/b] pause\n\n[i]Headshots and leg shots make enemies stagger. Get close and press E to kick them — it hits everything around you.[/i]"


func show_death() -> void:
	var pc := _panel(560, 300, Color(0.08, 0.0, 0.0, 0.9))
	modal_name = "death"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)
	var t := _label(vb, 54, Color(0.8, 0.05, 0.05), true)
	t.text = "YOU ARE DEAD"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(vb, 18, Color(0.7, 0.6, 0.55), true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.text = ["The bell tolls for you.", "They will bury you with the others.", "Not yet. The Choir isn't finished with you.", "Somewhere, a tally mark is carved."][randi() % 4]
	_button(vb, "Continue from checkpoint", func(): menu_action.emit("retry"))
	_button(vb, "Quit to title", func(): menu_action.emit("title"))
	vb.get_child(2).grab_focus.call_deferred()


func show_title() -> void:
	close_modal()
	var root := Control.new()
	add_child(root)
	_full(root)
	modal = root
	modal_name = "title"
	var t := _label(root, 96, Color(0.75, 0.06, 0.05), true)
	t.text = "HOLLOW VIGIL"
	t.position = Vector2(80, 90)
	var sub := _label(root, 22, Color(0.75, 0.72, 0.65), true)
	sub.position = Vector2(86, 200)
	if Game.loop == 1:
		sub.text = "A mountain village. A missing research team. A bell that never stops ringing."
	else:
		sub.text = "The car is coming up the mountain road again.   —  LOOP %d  —" % Game.loop
	var vb := VBoxContainer.new()
	vb.position = Vector2(86, 280)
	vb.add_theme_constant_override("separation", 10)
	root.add_child(vb)
	var start := "Begin the Vigil" if Game.loop == 1 else "Continue the Vigil  (Loop %d)" % Game.loop
	_button(vb, start, func(): menu_action.emit("start"))
	_button(vb, "Controls", func(): show_note("CONTROLS", CONTROLS))
	if Game.loop > 1:
		_button(vb, "Erase all memory (reset loops)", func(): menu_action.emit("wipe"))
	_button(vb, "Quit", func(): menu_action.emit("quit"))
	var e := _label(root, 16, Color(0.6, 0.58, 0.5))
	e.position = Vector2(86, 560)
	var ends := []
	if Game.endings.has("loop"):
		ends.append("I. Welcome Home")
	if Game.endings.has("dawn"):
		ends.append("II. Dawn")
	e.text = "Endings found: %d/2  %s" % [ends.size(), ("— " + ", ".join(ends)) if ends.size() else ""]
	if Game.best_time > 0:
		e.text += "\nBest time: %s" % Game.format_time(Game.best_time)
	if Game.loop > 1 and not Game.endings.has("dawn"):
		var hint := _label(root, 16, Color(0.55, 0.8, 0.95), true)
		hint.position = Vector2(86, 610)
		hint.text = "\"Five pieces of the first bell. Find them all, and it can be broken.\"   — L."
	vb.get_child(0).grab_focus.call_deferred()
