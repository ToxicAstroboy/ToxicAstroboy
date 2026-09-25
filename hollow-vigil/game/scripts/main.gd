extends Node
## Root controller: pixelated render pipeline, game flow, modals, cutscenes and endings.

var view: SubViewport
var container: SubViewportContainer
var world: World
var player: Player
var ui: UI
var state := "title"
var _after_note: Callable
var _title_t := 0.0
var autotest := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 3
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = SubViewport.new()
	view.audio_listener_enable_3d = true
	view.msaa_3d = Viewport.MSAA_DISABLED
	container.add_child(view)
	ui = UI.new()
	ui.main = self
	add_child(ui)
	ui.menu_action.connect(_on_menu)
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if "--shots" in OS.get_cmdline_user_args():
		_run_shots()
	elif autotest:
		_run_autotest()
	else:
		to_title()


func _setup_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN], "move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "reload": [KEY_R], "interact": [KEY_E], "knife": [KEY_F], "quickturn": [KEY_Q],
		"weapon1": [KEY_1], "weapon2": [KEY_2], "weapon3": [KEY_3], "heal": [KEY_H], "flashlight": [KEY_L],
		"pause": [KEY_ESCAPE, KEY_TAB],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for pair in [["aim", MOUSE_BUTTON_RIGHT], ["fire", MOUSE_BUTTON_LEFT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
	for pair in [["aim", JOY_AXIS_TRIGGER_LEFT], ["fire", JOY_AXIS_TRIGGER_RIGHT]]:
		var ja := InputEventJoypadMotion.new()
		ja.axis = pair[1]
		ja.axis_value = 1.0
		InputMap.action_add_event(pair[0], ja)


# ------------------------------------------------------------------ world lifecycle
func load_world(area: String) -> void:
	if world:
		view.remove_child(world)
		world.queue_free()
	for c in get_tree().get_nodes_in_group("interact"):
		c.remove_from_group("interact")
	world = World.new()
	view.add_child(world)
	world.build(self, area)
	player = world.player
	player.died.connect(_on_player_died)


func to_title() -> void:
	get_tree().paused = false
	state = "title"
	Sfx.stop_all()
	load_world("A")
	player.set_controls(false)
	player.visible = false
	ui.show_hud(false)
	ui.cinema(false, 0.01)
	ui.hide_card()
	ui.set_objective("")
	ui.boss_bar("", -1)
	world.cine.make_current()
	_title_t = 0.0
	ui.show_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.music("musicbox" if Game.loop == 1 else "musicbox_rev", -8)
	Sfx.ambience("amb_wind", -12)
	ui.fade(0.0, 2.0)


func start_game() -> void:
	ui.close_modal()
	state = "intro"
	Game.new_run()
	await ui.fade(1.0, 1.0).finished
	Sfx.music("")
	load_world("A")
	player.set_controls(false)
	ui.show_hud(false)
	var lines: Array
	if Game.loop == 1:
		lines = ["October.\nThe mountain pass above Grauwald.", "The car died two miles back.\nThe radio only plays bells."]
	elif Game.loop == 2:
		lines = ["October.\nThe mountain pass above Grauwald.", "...Again?", "You don't remember driving here.\nThe engine is still running."]
	else:
		lines = ["October.", "Loop %d." % Game.loop, "Your hand aches. You don't look at it."]
	for l in lines:
		if not autotest:
			await ui.big_text(l, 2.2).finished
	state = "play"
	ui.fade(0.0, 2.0)
	ui.show_hud(true)
	player.set_controls(true)
	player.cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.message("Read the orders on the car.  [E]", 5)
	if Game.loop >= 2:
		ui.subtitle("Something glints faintly in the dark. Shards: 0/5", 4)


func teleport(area: String) -> void:
	player.set_controls(false)
	await ui.fade(1.0, 0.8).finished
	player.global_position = world.SPAWNS[area]
	player.velocity = Vector3.ZERO
	player.face(0.0)
	world._enter_area(area)
	await get_tree().create_timer(0.3).timeout
	player.set_controls(true)
	ui.fade(0.0, 0.8)


func _on_player_died() -> void:
	state = "dead"
	Sfx.music("")
	Sfx.play("bell", 0, 0.8)
	await get_tree().create_timer(2.5).timeout
	if state != "dead":
		return
	ui.show_death()
	_modal_mode(true)


func _on_menu(a: String) -> void:
	match a:
		"start":
			start_game()
		"quit":
			get_tree().quit()
		"wipe":
			Game.wipe_persistent()
			to_title()
		"title":
			to_title()
		"retry":
			ui.close_modal()
			_modal_mode(false)
			await ui.fade(1.0, 0.6).finished
			Game.restore_checkpoint()
			load_world(Game.checkpoint)
			state = "play"
			ui.show_hud(true)
			ui.boss_bar("", -1)
			player.cam.make_current()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			ui.fade(0.0, 1.0)


# ------------------------------------------------------------------ modal handling
func _modal_mode(on: bool) -> void:
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else (Input.MOUSE_MODE_CAPTURED if state == "play" else Input.MOUSE_MODE_VISIBLE)


func modal_open(_n: String) -> void:
	_modal_mode(true)


func open_note(title: String, body: String) -> void:
	ui.show_note(title, body)
	Sfx.play("door", -12, 1.8)
	_modal_mode(true)


func after_note(cb: Callable) -> void:
	_after_note = cb


func open_merchant() -> void:
	ui.show_merchant()
	Sfx.play("coins")
	_modal_mode(true)


func close_modal() -> void:
	var was := ui.modal_name
	ui.close_modal()
	if state == "title":
		ui.show_title()
		return
	_modal_mode(false)
	if was == "note" and _after_note.is_valid():
		var cb := _after_note
		_after_note = Callable()
		cb.call()


func _input(event: InputEvent) -> void:
	if ui.modal_name != "":
		if ui.modal_name == "note" and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
			close_modal()
			get_viewport().set_input_as_handled()
		elif ui.modal_name in ["merchant", "pause"] and event.is_action_pressed("pause"):
			close_modal()
			get_viewport().set_input_as_handled()
		return
	if state != "play" or player == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		if player.dead:
			return
		ui.show_pause()
		_modal_mode(true)
	elif event.is_action_pressed("interact"):
		_interact()
	else:
		player.handle_input(event)


func _interact() -> void:
	if player.dead or not player.controls:
		return
	if player.try_kick():
		return
	var b := world.boss
	if b and is_instance_valid(b) and b.finisher_ready() and b.global_position.distance_to(player.global_position) < 6.0:
		player.set_controls(false)
		player.body.set_state("knife")
		b.finisher()
		await get_tree().create_timer(0.8).timeout
		player.set_controls(true)
		return
	var it := _nearest_interactable()
	if it:
		it.use(player)


func _nearest_interactable() -> Interactable:
	var best: Interactable = null
	var bd := 999.0
	for n in get_tree().get_nodes_in_group("interact"):
		var it := n as Interactable
		if it == null or not it.enabled or not it.is_inside_tree():
			continue
		var d := it.global_position.distance_to(player.global_position + Vector3(0, 0.9, 0))
		if d < it.radius and d < bd:
			bd = d
			best = it
	return best


func _process(delta: float) -> void:
	if state == "title" and world:
		_title_t += delta
		var a := _title_t * 0.05
		world.cine.global_position = Vector3(sin(a) * 3.0 - 2.5, 2.0 + sin(_title_t * 0.3) * 0.3, 5.0 - _title_t * 0.15)
		world.cine.look_at(Vector3(0, 1.5, -30))
		if _title_t > 120:
			_title_t = 0
		return
	if state != "play" or player == null or ui.modal_name != "":
		ui.prompt("")
		return
	var p := ""
	if not player.dead and player.controls:
		if player.kickable_near():
			p = "[E]  KICK"
		elif world.boss and is_instance_valid(world.boss) and world.boss.finisher_ready() and world.boss.global_position.distance_to(player.global_position) < 6.0:
			p = "[E]  DRIVE THE KNIFE INTO THE EYE"
		else:
			var it := _nearest_interactable()
			if it:
				p = "[E]  " + it.prompt
		if player.reload_t <= 0 and Game.mag[Game.weapon] == 0 and Game.reserve(Game.weapon) > 0 and p == "":
			p = "[R]  Reload"
	ui.prompt(p)


# ------------------------------------------------------------------ services used by the world
func noise_at(pos: Vector3, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.state in ["idle", "pray"] and e.aggro_radius > 0 and e.global_position.distance_to(pos) < radius:
			e.set_aggro()


func shake(amount: float) -> void:
	if player:
		player.shake = maxf(player.shake, amount)


func flash(color: Color, secs := 0.6) -> void:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, secs)
	tw.tween_callback(r.queue_free)


func spark(pos: Vector3, normal: Vector3, color: Color, count := 6) -> void:
	if world == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 50
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	p.mesh = m
	p.material_override = Models.mat(color, "none")
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func drop_loot(pos: Vector3, kind: String) -> void:
	var r := randf()
	var at := pos + Vector3(0, 0.1, 0)
	if kind == "brute":
		Pickup.make(self, world, at + Vector3(0.6, 0, 0), "coins", 1500)
		Pickup.make(self, world, at + Vector3(-0.6, 0, 0), "herb")
		return
	var p: Pickup = null
	if r < 0.35:
		p = Pickup.make(self, world, at, "coins", randi_range(4, 16) * 10)
	elif r < 0.6:
		p = Pickup.make(self, world, at, "handgun", randi_range(4, 8))
	elif r < 0.7 and Game.weapons.has("shotgun"):
		p = Pickup.make(self, world, at, "shells", randi_range(2, 4))
	elif r < 0.76 and Game.weapons.has("magnum"):
		p = Pickup.make(self, world, at, "magnum", 2)
	elif r < 0.84:
		p = Pickup.make(self, world, at, "herb")
	if p:
		p.life = 60.0


func spawn_orb(pos: Vector3, target: Node3D, spread: float) -> void:
	var o := Orb.new()
	o.main = self
	o.target = target
	var to := (target.global_position + Vector3(0, 1, 0) - pos).normalized()
	o.vel = to.rotated(Vector3.UP, spread) * 6.0
	world.add_child(o)
	o.global_position = pos


func boss_summon(n: int) -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			alive += 1
	for i in mini(n, 5 - alive):
		var a := randf() * TAU
		var e := world.enemy("zealot", world.boss.center + Vector3(cos(a), 0, sin(a)) * 14.0, true)
		e.drops = randf() < 0.7
		spark(e.global_position, Vector3.UP, Color(0.5, 0.1, 0.3), 14)
	Sfx.play("bell_low", -2)


func boss_transform(b: Boss) -> void:
	player.set_controls(false)
	ui.cinema(true)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.die(Vector3.UP)
	world.cine.global_position = b.global_position + Vector3(4, 2, 6)
	world.cine.look_at(b.global_position + Vector3(0, 2, 0))
	world.cine.make_current()
	Sfx.music("")
	ui.subtitle("FATHER ALDRIC: You think it's me you're killing? I'm only the mouth...", 3)
	await get_tree().create_timer(3.0).timeout
	Sfx.play("boss_roar", 4)
	shake(2.0)
	for i in 6:
		flash(Color(0.6, 0.0, 0.1, 0.6), 0.2)
		await get_tree().create_timer(0.25).timeout
	flash(Color.WHITE, 1.0)
	b.become_beast()
	var tw := world.cine.create_tween()
	tw.tween_property(world.cine, "global_position", b.global_position + Vector3(6, 3, 10), 2.0)
	await get_tree().create_timer(2.2).timeout
	ui.title_card("THE CHOIR", "It was never him. It was always the bell.")
	ui.cinema(false)
	player.cam.make_current()
	player.set_controls(true)
	Sfx.music("boss_music", -2)
	ui.message("Only the EYE can be hurt.", 4)


func drown() -> void:
	if player.dead:
		return
	Sfx.play("splash", 4)
	Sfx.play("boss_roar", 0, 0.5)
	ui.subtitle("Something beneath the black water takes hold of your leg.", 4)
	player.velocity = Vector3.ZERO
	Game.hp = 0
	Game.changed.emit()
	player.die()


# ------------------------------------------------------------------ endings
func _crowd(center: Vector3, count: int, radius_min: float, radius_max: float, facing: Vector3) -> Array:
	var bodies := []
	for i in count:
		var b := Body.new().setup("villager" if i % 5 else "zealot", 500 + i)
		var a := randf_range(-1.2, 1.2)
		var r := randf_range(radius_min, radius_max)
		b.position = center + Vector3(sin(a) * r, 0, cos(a) * r)
		var d := facing - b.position
		b.rotation.y = atan2(-d.x, -d.z)
		world.add_child(b)
		b.set_state("pray")
		b.animate(0.01, 0)
		b.set_eye_glow(3.0)
		bodies.append(b)
	return bodies


func _say(who: String, text: String, secs := 3.4) -> void:
	ui.subtitle(("%s: %s" % [who, text]) if who != "" else text, secs)
	await get_tree().create_timer(secs + 0.3).timeout


func ending_loop() -> void:
	if Game.flags.get("dawn", false):
		_dawn_final()
		return
	state = "ending"
	player.set_controls(false)
	ui.cinema(true)
	Sfx.music("")
	var pp := player.global_position
	world.cine.global_position = pp + Vector3(-4, 2.2, -5)
	world.cine.look_at(pp + Vector3(0, 1.4, 0))
	world.cine.make_current()
	await _say("HANDLER (radio)", "Rook, we have you on thermal. Good work. Who's that with you?")
	await _say("ROOK", "Nobody. It's just me.")
	await _say("HANDLER (radio)", "...Rook. There are forty-one heat signatures standing behind you.", 4)
	Sfx.play("bell", 4)
	shake(0.6)
	var crowd := _crowd(pp + Vector3(0, 0, 3), 41, 2.0, 11.0, pp)
	world.cine.global_position = pp + Vector3(1.5, 2.4, -3.5)
	world.cine.look_at(pp + Vector3(0, 0.8, 6))
	var tw := world.cine.create_tween()
	tw.tween_property(world.cine, "global_position", pp + Vector3(2.5, 3.2, -5.5), 6.0).set_trans(Tween.TRANS_SINE)
	Sfx.ambience("amb_chant", -2)
	await _say("", "They kneel. All of them. The whole village. Their eyes are burning.", 3.5)
	await _say("HANDLER (radio)", "Rook, get in the helicopter. Rook. ROOK—", 3)
	Sfx.play("screech", -6)
	await _say("", "You look down at your left hand.", 3)
	await _say("", "Carved into the skin — old scars, fresh cuts — tally marks. You count them.", 4)
	ui.big_text("||||  ||||  ||||  %s" % "| ".repeat(Game.loop), 2.0, Color(0.8, 0.1, 0.08))
	await get_tree().create_timer(3.6).timeout
	await _say("LENA (distant)", "Whoever kills the Father becomes the Father. That's how the Choir keeps its voice, Elias.", 4.5)
	await _say("LENA (distant)", "You've killed him %d times. He's never been anyone but you." % Game.loop, 4.2)
	flash(Color(0.6, 0, 0.05), 1.2)
	Sfx.play("boss_roar", 2, 0.8)
	player.dead = true
	player.body.queue_free()
	player.body = Body.new().setup("aldric")
	player.add_child(player.body)
	player.body.rotation.y = PI
	player.body.set_state("cast")
	world.cine.global_position = pp + Vector3(0, 1.6, -4.5)
	world.cine.look_at(pp + Vector3(0, 1.7, 0))
	for b in crowd:
		b.set_state("kneel")
		b.animate(0.01, 0)
	await _say("VILLAGERS", "Welcome home, Father.", 3.5)
	await _say("VILLAGERS", "WELCOME HOME, FATHER.", 3.0)
	Sfx.play("bell", 6)
	Sfx.play("bell_low", 6)
	await ui.fade(1.0, 0.15).finished
	Sfx.stop_all()
	ui.cinema(false, 0.01)
	ui.show_hud(false)
	await get_tree().create_timer(2.0).timeout
	_finish_run("loop")
	await ui.big_text("ENDING I:  WELCOME HOME", 3.0, Color(0.8, 0.1, 0.08)).finished
	await ui.big_text("Time  %s        Kills  %d\n\nShards of the first bell found:  %d / 5" % [Game.format_time(Game.run_time), Game.kills, Game.shards], 4.0).finished
	Sfx.play("musicbox_rev", -4)
	await ui.big_text("...A car is coming up the mountain road.", 3.0).finished
	await ui.big_text("LOOP %d" % Game.loop, 2.5, Color(0.8, 0.1, 0.08)).finished
	to_title()


func ending_dawn() -> void:
	state = "ending"
	Game.flags["dawn"] = true
	player.set_controls(false)
	ui.cinema(true)
	Sfx.music("")
	var bell := world.great_bell
	world.cine.global_position = player.global_position + Vector3(3, 2.5, 5)
	world.cine.look_at(bell.global_position + Vector3(0, -2, 0))
	world.cine.make_current()
	await _say("", "You press the five shards into the cracks. They fit perfectly. They were always part of it.", 4)
	for i in 5:
		Sfx.play("bell_high", -2, 1.0 + i * 0.12)
		spark(bell.global_position + Vector3(randf_range(-2, 2), -2, randf_range(-2, 2)), Vector3.UP, Color(0.6, 0.9, 1.0), 20)
		await get_tree().create_timer(0.5).timeout
	await _say("THE CHOIR", "ELIAS. YOU ARE OURS. YOU ARE OUR VOICE. YOU ARE—", 2.5)
	Sfx.play("screech", 4)
	Sfx.play("bell", 6, 0.5)
	shake(3.0)
	for i in 30:
		var shard := Models.box(world, Vector3(randf_range(0.2, 0.7), randf_range(0.2, 0.7), 0.1), bell.global_position + Vector3(0, -2, 0), Color(0.45, 0.33, 0.14), Vector3(randf() * 360, randf() * 360, 0))
		var t := shard.create_tween()
		t.tween_property(shard, "global_position", shard.global_position + Vector3(randf_range(-12, 12), randf_range(-1, 8), randf_range(-12, 12)), 1.4).set_ease(Tween.EASE_OUT)
	bell.visible = false
	flash(Color.WHITE, 3.0)
	await get_tree().create_timer(3.0).timeout
	await ui.fade(1.0, 1.5).finished
	await ui.big_text("Silence.\n\nFor the first time in seven years, the valley is silent.", 3.0).finished
	world.mood("dawn", 0.01)
	Game.flags["boss_dead"] = true
	player.global_position = world.SPAWNS.G
	player.face(0.0)
	world._enter_area("G", true)
	var lena := Body.new().setup("lena")
	lena.position = world.SPAWNS.G + Vector3(1.4, 0, -1)
	world.add_child(lena)
	lena.animate(0.01, 0)
	ui.cinema(false)
	player.cam.make_current()
	player.set_controls(true)
	state = "play"
	Sfx.ambience("amb_wind", -14)
	Sfx.music("musicbox", -10)
	ui.fade(0.0, 3.0)
	ui.set_objective("Go home.")
	await _say("LENA", "Look. The sun. I'd forgotten what it looked like.", 3.5)


func _dawn_final() -> void:
	state = "ending"
	player.set_controls(false)
	ui.cinema(true)
	var pp := player.global_position
	world.cine.global_position = pp + Vector3(-5, 2.0, -4)
	world.cine.look_at(pp + Vector3(0, 1.4, 0))
	world.cine.make_current()
	await _say("HANDLER (radio)", "Rook? Rook, respond. The bell signal is gone. The whole mountain just went quiet.")
	await _say("ROOK", "It's over. I'm coming home. I've got Dr. Hart.")
	await _say("LENA", "Elias... your hand.")
	await _say("", "You look down. The tally marks are fading like breath on a mirror.", 4)
	await ui.fade(1.0, 2.0).finished
	Sfx.stop_all()
	_finish_run("dawn")
	await ui.big_text("MISSION LOG — GRAUWALD\n\nAgents deployed: 1\nAgents recovered: 1\nLoops endured: %d" % (Game.loop - 1), 4.0).finished
	await ui.big_text("ENDING II:  DAWN", 3.0, Color(1.0, 0.75, 0.5)).finished
	await get_tree().create_timer(2.0).timeout
	await ui.big_text("Three weeks later.", 2.0).finished
	Sfx.play("musicbox_rev", -2)
	await ui.big_text("FIELD ORDERS — EYES ONLY\n\nAGENT M. HALE\n\nAgent Elias Rook has stopped transmitting from St. Anne's Hospital, Vienna.\nHis final transmission was a forty-second recording of church bells.", 6.0).finished
	Sfx.play("bell", 2)
	await ui.big_text("Locate Agent Rook.", 3.0, Color(0.8, 0.1, 0.08)).finished
	await ui.big_text("THE END ?", 3.0, Color(0.8, 0.1, 0.08)).finished
	to_title()


func _finish_run(ending: String) -> void:
	Game.flags["running"] = false
	Game.endings[ending] = true
	Game.runs_finished += 1
	if Game.best_time == 0.0 or Game.run_time < Game.best_time:
		Game.best_time = Game.run_time
	Game.loop += 1
	Game.save_persistent()


# ------------------------------------------------------------------ automated smoke test
func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _t_at(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	await _wait(0.4)


func _t_use(pos: Vector3, label_contains := "") -> bool:
	await _t_at(pos)
	var best: Interactable = null
	var bd := 999.0
	for n in get_tree().get_nodes_in_group("interact"):
		var it := n as Interactable
		if it and it.enabled and (label_contains == "" or it.prompt.contains(label_contains)):
			var d := it.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = it
	if best == null:
		push_error("AUTOTEST: no interactable '%s' near %s" % [label_contains, pos])
		return false
	best.use(player)
	await _wait(0.3)
	if ui.modal_name == "note":
		close_modal()
	return true


func _t_kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.take_hit(99999, e.global_position + Vector3(0, 1, 0), Vector3.FORWARD, "handgun")
	await _wait(0.2)


func _run_autotest() -> void:
	print("AUTOTEST start")
	Engine.time_scale = 4.0
	Game.wipe_persistent()
	to_title()
	await _wait(1.0)
	await start_game()
	await _wait(1.0)
	# A
	await _t_use(Vector3(1.6, 0.1, 10.8), "orders")
	player.fire()
	player.do_knife()
	await _t_use(Vector3(-4.8, 0.1, -26), "ledger")
	await _t_kill_all()
	await _wait(1.0)
	await _t_kill_all()
	await _t_at(Vector3(0, 0.1, -57))
	# B
	await _t_at(Vector3(0, 0.1, -82))
	await _wait(3.0)
	for i in 5:
		player.take_damage(1, player.global_position + Vector3.FORWARD)
		await _wait(1.0)
	world.siege_t = 500.0
	await _wait(14.0)
	assert(Game.flags.get("siege_done", false), "siege did not finish")
	# C
	await _t_at(Vector3(0, 0.1, -142))
	await _t_use(Vector3(-9.5, 0.1, -149.5), "Peddler")
	close_modal()
	await _t_at(Vector3(0, 0.1, -168))
	await _wait(1.0)
	var bpos := world.butcher.global_position
	await _t_kill_all()
	await _wait(0.5)
	await _t_use(bpos + Vector3(0, 0.6, 0), "Iron Key")
	await _t_use(Vector3(0, 0.1, -208.5), "Unlock")
	# D
	await _t_at(Vector3(0, 0.1, -212))
	await _t_use(Vector3(5.5, 0.1, -221.5), "journal")
	await _t_use(Vector3(21.5, 0.1, -264.5), "carving")
	await _t_use(Vector3(14, 0.1, -266.5), "grave")
	await _wait(3.0)
	await _t_kill_all()
	await _wait(1.0)
	await _t_kill_all()
	await _t_at(Vector3(-15, 0.1, -250))
	await _wait(2.0)
	print("AUTOTEST drown dead=", player.dead)
	await _wait(3.0)
	if ui.modal_name == "death":
		_on_menu("retry")
		await _wait(3.0)
	print("AUTOTEST after retry checkpoint=", Game.checkpoint, " keys=", Game.keys)
	# E
	await _t_use(Vector3(0, 0.1, -290.8), "chapel")
	await _t_at(Vector3(0, 0.1, -295))
	await _wait(16.0)
	await _t_use(Vector3(-4, 0.1, -321), "bird")
	await _wait(2.0)
	await _t_kill_all()
	await _t_use(Vector3(0, 0.1, -321), "sleeping")
	await _t_use(Vector3(-4, 0.1, -321), "bird")
	await _t_use(Vector3(4, 0.1, -321), "weeping")
	await _wait(5.0)
	await _t_use(Vector3(0, 0.1, -326), "Descend")
	await _wait(3.0)
	# F
	await _t_use(Vector3(207, 0.1, -27), "cage")
	await _wait(21.0)
	await _t_use(Vector3(207.5, 0.1, -58), "coffin")
	await _t_kill_all()
	await _t_use(Vector3(200, 0.1, -64.5), "sanctum")
	await _t_at(Vector3(200, 0.1, -77))
	await _wait(15.0)
	var b := world.boss
	for i in 3:
		player.fire()
		await _wait(0.5)
	b.take_hit(99999, b.global_position + Vector3(0, 1, 0), Vector3.FORWARD, "magnum")
	await _wait(12.0)
	print("AUTOTEST boss phase=", b.phase)
	b.take_hit(200, b.eye_pos(), Vector3.FORWARD, "magnum")
	await _wait(0.5)
	print("AUTOTEST boss state=", b.state)
	if b.state == "kneel":
		await _t_at(b.global_position + Vector3(0, 0, 3))
		_interact()
	await _wait(1.5)
	b.take_hit(99999, b.eye_pos(), Vector3.FORWARD, "magnum")
	await _wait(8.0)
	await _t_use(Vector3(200, 0.1, -85), "bell")
	await _t_use(Vector3(200, 0.1, -106), "cliff")
	await _wait(2.0)
	await _t_use(Vector3(398.5, 0.1, -15), "helicopter")
	await _wait(70.0)
	print("AUTOTEST loop now=", Game.loop, " state=", state)
	# Loop 2, true ending straight from the sanctum
	Game.new_run()
	Game.shards = 5
	Game.give_weapon("magnum")
	load_world("F2")
	state = "play"
	player.cam.make_current()
	await _t_at(Vector3(200, 0.1, -77))
	await _wait(15.0)
	world.boss.take_hit(99999, world.boss.global_position + Vector3(0, 1, 0), Vector3.FORWARD, "magnum")
	await _wait(12.0)
	world.boss.take_hit(99999, world.boss.eye_pos(), Vector3.FORWARD, "magnum")
	await _wait(8.0)
	await _t_use(Vector3(200, 0.1, -85), "shards")
	await _wait(0.5)
	ui.choice_made.emit(0)
	await _wait(25.0)
	await _t_use(Vector3(398.5, 0.1, -15), "helicopter")
	await _wait(60.0)
	print("AUTOTEST endings=", Game.endings, " loop=", Game.loop, " state=", state)
	Game.wipe_persistent()
	print("AUTOTEST PASS")
	get_tree().quit()


func _shot(name: String, pos: Vector3, yaw_deg: float, pitch := -0.1, wait := 1.5) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.face(deg_to_rad(yaw_deg))
	player.pitch.rotation.x = pitch
	await _wait(wait)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS_DIR") + "/" + name + ".png")
	print("shot ", name)


func _run_shots() -> void:
	Game.wipe_persistent()
	to_title()
	await _wait(2.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS_DIR") + "/00_title.png")
	autotest = true
	await start_game()
	await _shot("01_road", Vector3(0, 0.1, 4), 0)
	await _shot("02_cabin", Vector3(-1, 0.1, -20), 40)
	player.set_controls(true)
	Input.action_press("aim")
	await _shot("03_aim", Vector3(0, 0.1, -22), 45, -0.05)
	Input.action_release("aim")
	await _shot("04_village", Vector3(0, 0.1, -70), 0, -0.05)
	await _shot("05_siege", Vector3(0, 0.1, -82), 0, -0.1, 4.0)
	await _t_kill_all()
	await _shot("06_farm", Vector3(-4, 0.1, -146), 30)
	await _shot("07_butcher", Vector3(0, 0.1, -168), -60, -0.05, 3.0)
	await _t_kill_all()
	await _shot("08_lake", Vector3(-4, 0.1, -240), 70, -0.05, 6.0)
	await _shot("09_cemetery", Vector3(6, 0.1, -232), -30)
	await _shot("10_chapel_out", Vector3(0, 0.1, -278), 0, 0.15)
	world.open_gate(world.find_child("ChapelDoor", false, false))
	await _shot("11_chapel_in", Vector3(0, 0.1, -299), 0, 0.0, 16.0)
	await _shot("12_crypt", Vector3(200, 0.1, -8), 0)
	await _shot("13_lena", Vector3(205, 0.1, -27), -90)
	await _t_at(Vector3(200, 0.1, -77))
	await _wait(14.0)
	await _shot("14_boss", Vector3(200, 0.1, -78), 0, 0.0, 2.0)
	world.boss.take_hit(99999, world.boss.global_position + Vector3(0, 1, 0), Vector3.FORWARD, "magnum")
	await _wait(10.0)
	await _shot("15_beast", Vector3(200, 0.1, -80), 0, 0.2, 1.0)
	world.boss.take_hit(99999, world.boss.eye_pos(), Vector3.FORWARD, "magnum")
	await _wait(7.0)
	await _shot("16_bell", Vector3(200, 0.1, -80), 0, 0.1, 1.0)
	await _t_use(Vector3(200, 0.1, -106), "cliff")
	await _wait(2.0)
	await _shot("17_cliff", Vector3(400, 0.1, 5), 0, 0.0, 1.0)
	await _t_use(Vector3(398.5, 0.1, -15), "helicopter")
	await _wait(16.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS_DIR") + "/18_crowd.png")
	await _wait(30.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS_DIR") + "/19_father.png")
	Game.wipe_persistent()
	get_tree().quit()
