class_name World
extends Node3D
## Builds the whole map and runs every scripted event.
## Layout (Godot units, -Z is "forward"):
##   A forest road    z   10 .. -60      B village square  z  -60 .. -140
##   C farm           z -140 .. -210     D lake+cemetery   z -210 .. -292
##   E chapel         z -292 .. -334     F crypt+sanctum   x = 200 (underground)
##   G cliff helipad  x = 400

var main: Node
var player: Player
var env: Environment
var moon: DirectionalLight3D
var cine: Camera3D
var siege_t := -1.0
var siege_spawn_t := 0.0
var farm_spawn_t := 0.0
var butcher: Enemy
var boss: Boss
var bell_seq: Array[String] = []
var great_bell: Node3D
var lake_monster: Node3D
var lake_t := 8.0
var heli_rotor: Node3D
var altar: Node3D
var sanctum_blocker: StaticBody3D
var exit_gate: Node3D
var siege_blocker: StaticBody3D
var crows: Array[Node3D] = []
var flicker_lights: Array[OmniLight3D] = []
var mood_name := ""

const SPAWNS := {
	"A": Vector3(0, 0.1, 5), "B": Vector3(0, 0.1, -62), "C": Vector3(0, 0.1, -144), "D": Vector3(0, 0.1, -214),
	"E": Vector3(0, 0.1, -296), "F": Vector3(200, 0.1, -3), "F2": Vector3(200, 0.1, -68.5), "G": Vector3(400, 0.1, 12),
}


var start := "A"
const ORDER := ["A", "B", "C", "D", "E", "F", "F2", "G"]


func past(area: String) -> bool:
	return ORDER.find(area) < ORDER.find(start)


func build(m: Node, start_area: String) -> void:
	main = m
	start = start_area
	name = "World"
	_build_env()
	_area_a()
	_area_b()
	_area_c()
	_area_d()
	_area_e()
	_area_f()
	_area_g()
	cine = Camera3D.new()
	cine.fov = 55
	cine.far = 250
	add_child(cine)
	player = Player.new()
	player.main = main
	player.position = SPAWNS[start_area]
	add_child(player)
	player.face(0.0)
	_enter_area(start_area, true)


# ------------------------------------------------------------------ environment
func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.light_color = Color(0.55, 0.62, 0.8)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40
	add_child(moon)
	var moon_disc := Models.sphere(self, 7, Vector3(-60, 70, -170), Color.WHITE, 12, Models.glow_mat(Color(0.8, 0.85, 0.9), 1.5))
	moon_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mood("forest", 0.0)


const MOODS := {
	"forest": [Color(0.05, 0.07, 0.08), 0.045, Color(0.32, 0.37, 0.45), 0.7, 0.4],
	"village": [Color(0.16, 0.1, 0.07), 0.024, Color(0.5, 0.4, 0.34), 0.8, 0.45],
	"farm": [Color(0.1, 0.08, 0.07), 0.03, Color(0.45, 0.38, 0.33), 0.7, 0.4],
	"lake": [Color(0.12, 0.13, 0.14), 0.05, Color(0.38, 0.4, 0.45), 0.65, 0.3],
	"church": [Color(0.03, 0.02, 0.02), 0.02, Color(0.45, 0.35, 0.3), 0.7, 0.0],
	"crypt": [Color(0.02, 0.0, 0.0), 0.045, Color(0.4, 0.25, 0.2), 0.55, 0.0],
	"sanctum": [Color(0.05, 0.0, 0.02), 0.025, Color(0.45, 0.25, 0.3), 0.6, 0.0],
	"cliff": [Color(0.06, 0.07, 0.1), 0.035, Color(0.38, 0.4, 0.55), 0.7, 0.45],
	"dawn": [Color(0.75, 0.45, 0.32), 0.018, Color(0.9, 0.7, 0.6), 1.0, 1.2],
}


func mood(n: String, secs := 2.0) -> void:
	if n == mood_name:
		return
	mood_name = n
	var d: Array = MOODS[n]
	var tw := create_tween().set_parallel()
	tw.tween_property(env, "background_color", d[0], maxf(secs, 0.01))
	tw.tween_property(env, "fog_light_color", d[0], maxf(secs, 0.01))
	tw.tween_property(env, "fog_density", d[1], maxf(secs, 0.01))
	tw.tween_property(env, "ambient_light_color", d[2], maxf(secs, 0.01))
	tw.tween_property(env, "ambient_light_energy", d[3], maxf(secs, 0.01))
	tw.tween_property(moon, "light_energy", d[4], maxf(secs, 0.01))
	if n == "dawn":
		moon.light_color = Color(1.0, 0.7, 0.45)
		moon.rotation_degrees = Vector3(-12, 160, 0)


# ------------------------------------------------------------------ helpers
func ground(center: Vector3, size: Vector2, color: Color, tk := "grass") -> void:
	Models.solid(self, Vector3(size.x, 1.0, size.y), center + Vector3(0, -0.5, 0), color, tk)


func path_strip(a: Vector3, b: Vector3, w: float, color := Color(0.28, 0.22, 0.16)) -> void:
	var mid := (a + b) * 0.5
	var l := a.distance_to(b)
	var m := Models.box(self, Vector3(w, 0.02, l), mid + Vector3(0, 0.01, 0), color, Vector3.ZERO, "noise")
	m.look_at_from_position(mid + Vector3(0, 0.01, 0), b + Vector3(0, 0.01, 0), Vector3.UP)


func wall(center: Vector3, size: Vector3) -> StaticBody3D:
	return Models.collider(self, size, center)


func place(model: String, pos: Vector3, rot_y_deg := 0.0, s := 1.0, seed_value := 0) -> Node3D:
	var n := Models.prop(model, seed_value)
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	n.scale = Vector3.ONE * s
	add_child(n)
	return n


func tree(pos: Vector3, dead := false) -> void:
	var t := place("deadtree" if dead else "tree", pos, randf() * 360, randf_range(0.8, 1.2), randi())
	Models.collider(self, Vector3(0.6, 4, 0.6), pos + Vector3(0, 2, 0))
	t.name = "Tree"


func tree_band(x0: float, x1: float, z0: float, z1: float, count: int, dead_ratio := 0.0) -> void:
	for i in count:
		var p := Vector3(randf_range(x0, x1), 0, randf_range(z0, z1))
		var t := place("deadtree" if randf() < dead_ratio else "tree", p, randf() * 360, randf_range(0.8, 1.25), randi())
		t.name = "Tree"


func house(pos: Vector3, face_to: Vector3, s := 1.0, seed_value := 0) -> void:
	var d := face_to - pos
	var ry := atan2(d.x, d.z)
	place("house", pos, rad_to_deg(ry), s, seed_value)
	Models.collider(self, Vector3(8, 6, 6) * s, pos + Vector3(0, 3 * s, 0), ry)


func solid_prop(model: String, pos: Vector3, size: Vector3, rot := 0.0, s := 1.0) -> void:
	place(model, pos, rot, s)
	Models.collider(self, size * s, pos + Vector3(0, size.y * s * 0.5, 0), deg_to_rad(rot))


func light(pos: Vector3, color: Color, energy := 1.5, rng := 9.0, flicker := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	add_child(l)
	if flicker:
		l.set_meta("base", energy)
		flicker_lights.append(l)
	return l


func torch(pos: Vector3) -> void:
	Models.box(self, Vector3(0.08, 0.5, 0.08), pos, Color(0.25, 0.15, 0.08), Vector3(-20, 0, 0), "wood")
	Models.sphere(self, 0.12, pos + Vector3(0, 0.3, 0), Color.ORANGE, 5, Models.glow_mat(Color(1, 0.5, 0.1), 5))
	light(pos + Vector3(0, 0.5, 0), Color(1, 0.55, 0.25), 1.6, 8)


func fire(pos: Vector3, big := false) -> void:
	for i in (6 if big else 3):
		var a := TAU * i / (6.0 if big else 3.0)
		Models.box(self, Vector3(0.15, 0.15, 1.4), pos + Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4), Color(0.2, 0.12, 0.06), Vector3(0, rad_to_deg(-a), 0), "wood")
	var fm := Models.glow_mat(Color(1, 0.4, 0.08), 2.2)
	var core := Node3D.new()
	core.position = pos
	add_child(core)
	for i in 4:
		var p := PrismMesh.new()
		p.size = Vector3(0.6, 1.2 + i * 0.2, 0.6) * (1.6 if big else 1.0)
		Models.mi(core, p, Vector3(randf_range(-0.2, 0.2), 0.6, randf_range(-0.2, 0.2)), fm, Vector3(0, i * 45, 0))
	core.set_meta("fire", true)
	light(pos + Vector3(0, 1.5, 0), Color(1, 0.5, 0.2), 3.0 if big else 2.0, 16 if big else 10)


func trigger(pos: Vector3, size: Vector3, cb: Callable) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	add_child(a)
	a.body_entered.connect(func(b):
		if b is Player and a.has_meta("armed"):
			a.remove_meta("armed")
			cb.call())
	a.set_meta("armed", true)
	return a


func note(pos: Vector3, doc: Callable, label := "Read") -> Interactable:
	var paper := Models.box(self, Vector3(0.3, 0.02, 0.4), pos, Color(0.85, 0.8, 0.65), Vector3(0, randf() * 40, 0), "none")
	paper.material_override = Models.glow_mat(Color(0.85, 0.8, 0.6), 0.6)
	return Interactable.make(self, pos, label, func(_p):
		var d: Array = doc.call()
		main.open_note(d[0], d[1]))


func enemy(kind: String, pos: Vector3, aggro := false, state := "idle") -> Enemy:
	var e := Enemy.new().setup(kind, main, randi())
	e.aggro = aggro
	e.position = pos
	add_child(e)
	if state != "idle":
		e.go(state)
	elif aggro:
		e.go("chase")
	return e


func shard(pos: Vector3) -> void:
	if Game.is_haunted():
		Pickup.make(main, self, pos, "shard")


func crate(pos: Vector3, loot := "", amt := 0, model := "crate") -> void:
	Breakable.make(main, self, pos, model, loot, amt)


func gate(pos: Vector3, width: float, key: String, prompt_locked: String, on_open: Callable) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	var bars := Node3D.new()
	g.add_child(bars)
	var n := int(width / 0.4)
	for i in n:
		Models.box(bars, Vector3(0.12, 3.2, 0.12), Vector3(-width / 2 + 0.2 + i * 0.4, 1.6, 0), Color(0.25, 0.22, 0.2), Vector3.ZERO, "none")
	for y in [0.4, 2.8]:
		Models.box(bars, Vector3(width, 0.14, 0.14), Vector3(0, y, 0), Color(0.3, 0.26, 0.2), Vector3.ZERO, "none")
	for x in [-width / 2 - 0.3, width / 2 + 0.3]:
		Models.box(g, Vector3(0.6, 4, 0.6), Vector3(x, 2, 0), Color(0.35, 0.33, 0.3), Vector3.ZERO, "stone")
	var col := Models.collider(g, Vector3(width, 4, 0.5), Vector3(0, 2, 0))
	g.set_meta("col", col)
	g.set_meta("bars", bars)
	if key != "":
		Interactable.make(self, pos + Vector3(0, 1, 0.8), prompt_locked, func(_p):
			if key == "*" or Game.keys.has(key):
				open_gate(g)
				on_open.call()
				return true
			Game.say("It's locked. You need the %s." % key)
			Sfx.play("empty")
			return false, 2.6)
	return g


func open_gate(g: Node3D) -> void:
	if g.has_meta("opened"):
		return
	g.set_meta("opened", true)
	var col: StaticBody3D = g.get_meta("col")
	col.queue_free()
	var bars: Node3D = g.get_meta("bars")
	var tw := create_tween()
	tw.tween_property(bars, "position:y", 3.6, 1.6).set_trans(Tween.TRANS_SINE)
	Sfx.play_at("door", g.global_position, self, 0, 0.7)


# ------------------------------------------------------------------ AREA A: forest road
func _area_a() -> void:
	ground(Vector3(0, 0, -22.5), Vector2(90, 75), Color(0.16, 0.2, 0.12))
	path_strip(Vector3(0, 0, 14), Vector3(0, 0, -64), 4.5)
	wall(Vector3(0, 3, 16), Vector3(40, 6, 1))
	wall(Vector3(-13, 3, -22), Vector3(1, 6, 76))
	wall(Vector3(13, 3, -22), Vector3(1, 6, 76))
	tree_band(-45, -14, 15, -62, 70)
	tree_band(14, 45, 15, -62, 70)
	for z in range(10, -58, -7):
		tree(Vector3(randf_range(-12, -7), 0, z + randf_range(-2, 2)))
		if z > -20 or z < -34:
			tree(Vector3(randf_range(7, 12), 0, z + randf_range(-2, 2)))
	# crashed car, still running
	solid_prop("car", Vector3(2.8, 0, 9), Vector3(2, 1.5, 4.4), 25)
	light(Vector3(2.0, 0.8, 6.5), Color(1, 0.9, 0.6), 1.5, 10, false)
	note(Vector3(1.6, 0.9, 10.2), Story.orders, "Read the field orders")
	# woodcutter's cabin
	house(Vector3(-9.5, 0, -28), Vector3(0, 0, -28), 0.8, 2)
	fire(Vector3(-4, 0, -24))
	crate(Vector3(-5, 0, -31), "handgun", 10)
	crate(Vector3(-5.8, 0, -32), "", 0, "barrel")
	note(Vector3(-5.4, 0.7, -26.2), Story.ledger, "Read the ledger")
	Models.box(self, Vector3(1.0, 0.7, 0.6), Vector3(-5.4, 0.35, -26.2), Color(0.3, 0.2, 0.1), Vector3.ZERO, "wood")
	shard(Vector3(-11.5, 0.1, -34))
	if not past("B"):
		_woodcutter()
	# village arch
	for x in [-3.5, 3.5]:
		Models.solid(self, Vector3(0.5, 5, 0.5), Vector3(x, 2.5, -58), Color(0.3, 0.2, 0.12), "wood")
	Models.box(self, Vector3(8, 0.5, 0.4), Vector3(0, 5, -58), Color(0.3, 0.2, 0.12), Vector3.ZERO, "wood")
	var sign := Label3D.new()
	sign.text = "GRAUWALD"
	sign.font_size = 64
	sign.modulate = Color(0.8, 0.75, 0.6)
	sign.position = Vector3(0, 5, -57.7)
	add_child(sign)
	trigger(Vector3(0, 1, -57), Vector3(12, 3, 1), func(): _enter_area("B"))


func _woodcutter() -> void:
	var woodcutter := enemy("villager", Vector3(-3.5, 0, -28))
	woodcutter.aggro_radius = 11
	woodcutter.killed.connect(func(_e):
		main.ui.subtitle("ROOK: ...He didn't even flinch. What's wrong with these people?", 4)
		enemy("villager", Vector3(-8, 0, -48), true)
		enemy("villager", Vector3(6, 0, -52), true)
		if Game.is_haunted():
			enemy("villager", Vector3(0, 0, -58), true))


# ------------------------------------------------------------------ AREA B: village
func _area_b() -> void:
	ground(Vector3(0, 0, -100), Vector2(80, 80), Color(0.2, 0.17, 0.12), "noise")
	path_strip(Vector3(0, 0, -60), Vector3(0, 0, -140), 5)
	wall(Vector3(-33, 3, -100), Vector3(1, 6, 82))
	wall(Vector3(33, 3, -100), Vector3(1, 6, 82))
	tree_band(-60, -34, -60, -140, 60, 0.3)
	tree_band(34, 60, -60, -140, 60, 0.3)
	var c := Vector3(0, 0, -100)
	var hs := [Vector3(-22, 0, -76), Vector3(22, 0, -78), Vector3(-27, 0, -100), Vector3(27, 0, -102), Vector3(-22, 0, -124), Vector3(22, 0, -124), Vector3(-12, 0, -136)]
	for i in hs.size():
		house(hs[i], c, 1.0, i)
	# the stake
	Models.solid(self, Vector3(0.35, 5, 0.35), c + Vector3(0, 2.5, 0), Color(0.18, 0.1, 0.06), "wood")
	var burned := Body.new().setup("villager", 99)
	burned.position = c + Vector3(0, 1.3, 0.25)
	burned.rotation.y = PI
	add_child(burned)
	burned.set_state("aim")
	burned.animate(0.01, 0)
	burned.parts.ArmL.rotation = Vector3(-2.8, 0, -0.4)
	burned.parts.ArmR.rotation = Vector3(-2.8, 0, 0.4)
	burned.parts.Head.rotation.x = 0.5
	fire(c, true)
	solid_prop("well", Vector3(9, 0, -90), Vector3(2.4, 2, 2.4))
	solid_prop("cart", Vector3(-10, 0, -112), Vector3(1.8, 2, 3), 30)
	solid_prop("cart", Vector3(12, 0, -116), Vector3(1.8, 2, 3), -70)
	for p in [Vector3(-16, 0, -85), Vector3(15, 0, -84), Vector3(-18, 0, -110), Vector3(17, 0, -112), Vector3(-6, 0, -130), Vector3(6, 0, -128)]:
		crate(p)
	crate(Vector3(18, 0, -92), "shells" if Game.weapons.has("shotgun") else "handgun", 8)
	crate(Vector3(-17, 0, -93), "herb")
	crate(Vector3(4, 0, -79), "coins", 300, "barrel")
	for i in 5:
		Models.solid(self, Vector3(1.2, 1.0, 1.2), Vector3(randf_range(-24, 24), 0.5, randf_range(-82, -130)), Color(0.55, 0.48, 0.25), "grass")
	# a shotgun left on a porch table
	var table := Models.solid(self, Vector3(1.6, 0.8, 0.8), Vector3(19.5, 0.4, -81.5), Color(0.3, 0.2, 0.1), "wood")
	if not Game.weapons.has("shotgun"):
		var sg := Node3D.new()
		table.add_child(sg)
		sg.position = Vector3(0, 0.45, 0)
		sg.rotation_degrees = Vector3(90, 70, 0)
		Models.box(sg, Vector3(0.06, 0.07, 0.9), Vector3(0, 0, -0.35), Color(0.12, 0.12, 0.13), Vector3.ZERO, "none")
		Models.box(sg, Vector3(0.07, 0.1, 0.35), Vector3(0, -0.04, 0.15), Color(0.35, 0.2, 0.1), Vector3.ZERO, "wood")
		Interactable.make(self, Vector3(19.5, 1.0, -81.5), "Take the shotgun", func(_p):
			sg.queue_free()
			Game.give_weapon("shotgun")
			Game.add_ammo("shells", 8)
			Game.mag["shotgun"] = Game.mag_size("shotgun")
			player.refresh_gun()
			Sfx.play("reload")
			Game.say("Got the SHOTGUN.  [1] [2] switch weapons", 3)
			return true, 2.2)
	var n := note(Vector3(-19.2, 1.4, -78.4), Story.notice, "Read the notice")
	n.radius = 2.8
	shard(Vector3(-30, 0.1, -112))
	for p in [Vector3(-8, 3, -86), Vector3(8, 3, -114)]:
		light(p, Color(1, 0.6, 0.3), 1.2, 10)
	exit_gate = gate(Vector3(0, 0, -140), 6, "", "", func(): pass)
	wall(Vector3(-17, 3, -140), Vector3(28, 6, 1))
	wall(Vector3(17, 3, -140), Vector3(28, 6, 1))
	if past("C"):
		open_gate(exit_gate)
		return
	# praying villagers around the fire
	for i in 6:
		var a := TAU * i / 6.0
		var e := enemy("villager", c + Vector3(cos(a) * 4.2, 0, sin(a) * 4.2), false, "pray")
		e.body.rotation.y = atan2(cos(a), sin(a))
		e.aggro_radius = 0.0
		e.add_to_group("siege")
	siege_blocker = Models.collider(self, Vector3(12, 6, 1), Vector3(0, 3, -61))
	siege_blocker.collision_layer = 0
	trigger(Vector3(0, 1, -82), Vector3(60, 3, 2), _start_siege)


func _start_siege() -> void:
	siege_t = 0.0
	siege_spawn_t = 3.0
	siege_blocker.collision_layer = 1
	Sfx.music("boss_music", -12)
	main.ui.subtitle("VILLAGERS (in unison): ...He's here.", 3)
	main.ui.set_objective("Survive.")
	await get_tree().create_timer(1.2).timeout
	for e in get_tree().get_nodes_in_group("siege"):
		if is_instance_valid(e):
			e.aggro_radius = 30.0
			e.set_aggro()


func _siege_process(delta: float) -> void:
	if siege_t < 0:
		return
	siege_t += delta
	var dur := 95.0 + 12.0 * float(mini(Game.loop - 1, 2))
	if siege_t < dur:
		siege_spawn_t -= delta
		var alive := get_tree().get_nodes_in_group("enemies").size()
		if siege_spawn_t <= 0 and alive < 7 + mini(Game.loop, 3):
			siege_spawn_t = randf_range(3.0, 6.0)
			var pts := [Vector3(-26, 0, -88), Vector3(26, 0, -90), Vector3(-25, 0, -114), Vector3(25, 0, -113), Vector3(-6, 0, -134), Vector3(8, 0, -133)]
			var p: Vector3 = pts[randi() % pts.size()]
			var e := enemy("villager" if randf() < 0.85 else "zealot", p, true)
			if randf() < 0.3:
				e.add_torch()
		if siege_t > 40 and siege_t - delta <= 40:
			main.ui.subtitle("ROOK: There's no end to them...", 3)
	else:
		siege_t = -1.0
		_end_siege()


func _end_siege() -> void:
	Sfx.music("")
	for i in 3:
		get_tree().create_timer(i * 2.2).timeout.connect(func(): Sfx.play("bell", -2 + i * 2))
	main.ui.subtitle("A church bell tolls somewhere beyond the village...", 4)
	await get_tree().create_timer(2.0).timeout
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.start_leave(Vector3(0, 0, -137))
	await get_tree().create_timer(4.0).timeout
	main.ui.subtitle("ROOK: They're... going to pray? Fine by me.", 3.5)
	await get_tree().create_timer(4.0).timeout
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	open_gate(exit_gate)
	Game.flags["siege_done"] = true
	main.ui.set_objective("Follow the villagers north.")


# ------------------------------------------------------------------ AREA C: farm
func _area_c() -> void:
	ground(Vector3(0, 0, -175), Vector2(80, 70), Color(0.22, 0.2, 0.12))
	path_strip(Vector3(0, 0, -140), Vector3(0, 0, -212), 4)
	wall(Vector3(-31, 3, -175), Vector3(1, 6, 72))
	wall(Vector3(31, 3, -175), Vector3(1, 6, 72))
	tree_band(-60, -32, -140, -212, 50, 0.2)
	tree_band(32, 60, -140, -212, 50, 0.2)
	# merchant's shed
	Models.solid(self, Vector3(4, 0.2, 3), Vector3(-11, 3, -151), Color(0.25, 0.15, 0.1), "wood")
	for p in [Vector3(-12.8, 1.5, -149.7), Vector3(-9.2, 1.5, -149.7), Vector3(-12.8, 1.5, -152.3), Vector3(-9.2, 1.5, -152.3)]:
		Models.solid(self, Vector3(0.2, 3, 0.2), p, Color(0.25, 0.15, 0.1), "wood")
	var lan := place("lantern", Vector3(-10, 2.6, -150))
	lan.name = "Lantern"
	light(Vector3(-10, 2.4, -149.5), Color(0.5, 0.65, 1.0), 2.2, 8)
	var merchant := Body.new().setup("merchant")
	merchant.position = Vector3(-11, 0, -151.5)
	merchant.rotation.y = deg_to_rad(-120)
	add_child(merchant)
	merchant.animate(0.01, 0)
	Models.collider(self, Vector3(0.8, 2, 0.8), Vector3(-11, 1, -151.5))
	Interactable.make(self, Vector3(-10, 1, -150), "Trade with the Peddler", func(_p): main.open_merchant(), 2.8)
	trigger(Vector3(-6, 1, -150), Vector3(8, 3, 8), func(): main.ui.subtitle("PEDDLER: Heh heh heh... Over here, pilgrim. Got some things that might keep you breathing.", 4))
	crate(Vector3(-14, 0, -154), "coins", 500)
	# barn
	house(Vector3(18, 0, -182), Vector3(0, 0, -182), 1.5, 1)
	for z in [-160, -170, -196, -204]:
		place("fence", Vector3(-5, 0, z), 90)
		place("fence", Vector3(5, 0, z), 90)
	for x in [-24, -19, -14]:
		place("fence", Vector3(x, 0, -170))
		place("fence", Vector3(x, 0, -192))
	for i in 5:
		Models.solid(self, Vector3(1.2, 1.0, 1.2), Vector3(randf_range(-24, 8), 0.5, randf_range(-160, -205)), Color(0.55, 0.48, 0.25), "grass")
	solid_prop("cart", Vector3(-18, 0, -182), Vector3(1.8, 2, 3), 80)
	solid_prop("well", Vector3(-8, 0, -198), Vector3(2.4, 2, 2.4))
	for p in [Vector3(10, 0, -165), Vector3(-22, 0, -200), Vector3(24, 0, -200)]:
		crate(p)
	crate(Vector3(14, 0, -168), "herb")
	crate(Vector3(-24, 0, -163), "handgun", 10)
	note(Vector3(12.5, 1.2, -177.3), Story.tally, "Read the scrawl on the wall")
	shard(Vector3(27, 0.1, -205))
	torch(Vector3(6, 2.5, -176))
	torch(Vector3(-6, 2.5, -196))
	var g := gate(Vector3(0, 0, -210), 5, "Iron Key", "Unlock gate", func(): Game.say("The iron gate grinds open."))
	g.name = "FarmGate"
	wall(Vector3(-16.5, 3, -210), Vector3(28, 6, 1))
	wall(Vector3(16.5, 3, -210), Vector3(28, 6, 1))
	trigger(Vector3(0, 1, -142), Vector3(20, 3, 1), func(): _enter_area("C"))
	if not past("D"):
		trigger(Vector3(0, 1, -168), Vector3(60, 3, 1.5), _butcher_arrives)


func _butcher_arrives() -> void:
	butcher = enemy("brute", Vector3(16, 0, -177), true)
	butcher.aggro_radius = 60
	main.ui.title_card("THE BUTCHER", "He only wants to take you apart.")
	main.ui.set_objective("Kill the Butcher.")
	Sfx.play("roar", 2)
	Sfx.music("boss_music", -6)
	main.shake(0.8)
	farm_spawn_t = 18.0
	butcher.killed.connect(func(_e):
		Sfx.music("")
		main.ui.boss_bar("", -1)
		var kpos := butcher.global_position + Vector3(0, 0.6, 0)
		var key := Models.box(self, Vector3(0.1, 0.05, 0.35), kpos, Color.GOLD, Vector3.ZERO, "none")
		key.material_override = Models.glow_mat(Color(0.8, 0.6, 0.2), 2)
		Interactable.make(self, kpos, "Take the Iron Key", func(_p):
			key.queue_free()
			Game.keys["Iron Key"] = true
			Sfx.play("pickup")
			Game.say("Got the IRON KEY.")
			main.ui.set_objective("Unlock the north gate."), 2.5, true)
		main.ui.subtitle("ROOK: Something fell out of his apron. A key.", 3))


# ------------------------------------------------------------------ AREA D: lake & cemetery
func _area_d() -> void:
	ground(Vector3(15, 0, -250), Vector2(50, 80), Color(0.16, 0.18, 0.13))
	ground(Vector3(-30, -3, -250), Vector2(40, 80), Color(0.1, 0.1, 0.08), "noise")
	path_strip(Vector3(0, 0, -210), Vector3(0, 0, -292), 4)
	var water := Models.box(self, Vector3(40, 0.1, 80), Vector3(-30, -0.35, -251), Color(0.05, 0.08, 0.1), Vector3.ZERO, "none")
	water.material_override = Models.mat(Color(0.04, 0.07, 0.09), "noise", 0.3, Color(0.05, 0.1, 0.12), 0.3)
	for z in range(-214, -290, -6):
		Models.box(self, Vector3(1.2, 0.6, 1.8), Vector3(-10.2 + randf_range(-0.4, 0.4), -0.1, z), Color(0.3, 0.3, 0.3), Vector3(0, randf() * 90, 0), "stone")
		if randf() < 0.5:
			place("fence", Vector3(-8.5, 0, z + 3), 90)
	var death := Area3D.new()
	death.collision_layer = 0
	death.collision_mask = 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(38, 4, 80)
	cs.shape = sh
	death.add_child(cs)
	death.position = Vector3(-30, -1, -251)
	add_child(death)
	death.body_entered.connect(func(b): if b is Player: main.drown())
	wall(Vector3(31, 3, -251), Vector3(1, 6, 82))
	wall(Vector3(-50, 3, -251), Vector3(1, 6, 82))
	tree_band(32, 55, -210, -292, 40, 0.8)
	# lake monster silhouette
	lake_monster = Node3D.new()
	add_child(lake_monster)
	var lm := Models.mat(Color(0.03, 0.04, 0.04), "noise")
	Models.sphere(lake_monster, 3.5, Vector3(0, 0, 0), Color.BLACK, 10, lm)
	Models.sphere(lake_monster, 2.2, Vector3(0, 0.5, -4), Color.BLACK, 8, lm)
	Models.sphere(lake_monster, 0.35, Vector3(-0.8, 1.2, -5.8), Color.BLACK, 6, Models.glow_mat(Color(0.8, 0.9, 0.2), 3))
	Models.sphere(lake_monster, 0.35, Vector3(0.8, 1.2, -5.8), Color.BLACK, 6, Models.glow_mat(Color(0.8, 0.9, 0.2), 3))
	lake_monster.position = Vector3(-30, -8, -250)
	# research camp
	Models.solid(self, Vector3(3, 2, 3), Vector3(8, 1, -224), Color(0.35, 0.38, 0.3), "cloth")
	Models.box(self, Vector3(3.3, 0.1, 3.4), Vector3(8, 2.2, -224), Color(0.3, 0.33, 0.25), Vector3(0, 0, 8), "cloth")
	Models.box(self, Vector3(0.5, 0.35, 0.4), Vector3(5.6, 0.7, -222), Color(0.15, 0.17, 0.12), Vector3.ZERO, "none")
	Models.solid(self, Vector3(1.4, 0.6, 0.8), Vector3(5.6, 0.3, -222), Color(0.3, 0.3, 0.3), "none")
	note(Vector3(5.2, 0.62, -222.2), Story.journal, "Read Dr. Hart's journal")
	crate(Vector3(10.5, 0, -221), "handgun", 12)
	crate(Vector3(11, 0, -227), "spray")
	light(Vector3(6, 1.2, -222), Color(0.6, 0.8, 1.0), 0.8, 5)
	shard(Vector3(-7.6, 0.1, -262))
	# cemetery
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for gx in range(5, 26, 3):
		for gz in range(-236, -284, -4):
			if rng.randf() < 0.8 and not (gx == 14 and gz == -268):
				place("tombstone", Vector3(gx + rng.randf_range(-0.5, 0.5), 0, gz), rng.randf_range(-10, 10) + 180, 1.0, rng.randi())
	for p in [Vector3(9, 0, -246), Vector3(20, 0, -258), Vector3(6, 0, -280), Vector3(25, 0, -240)]:
		tree(p, true)
	for i in 6:
		var crow := Node3D.new()
		Models.box(crow, Vector3(0.18, 0.15, 0.35), Vector3.ZERO, Color(0.02, 0.02, 0.02), Vector3.ZERO, "none")
		Models.box(crow, Vector3(0.5, 0.03, 0.15), Vector3(0, 0.05, 0), Color(0.02, 0.02, 0.02), Vector3.ZERO, "none")
		crow.position = Vector3(randf_range(6, 24), 0.9, randf_range(-240, -280))
		add_child(crow)
		crows.append(crow)
	# mausoleum
	Models.solid(self, Vector3(5, 4, 0.5), Vector3(22, 2, -262.2), Color(0.4, 0.4, 0.42), "stone")
	Models.solid(self, Vector3(0.5, 4, 5), Vector3(24.3, 2, -264.5), Color(0.4, 0.4, 0.42), "stone")
	Models.solid(self, Vector3(5, 4, 0.5), Vector3(22, 2, -266.8), Color(0.4, 0.4, 0.42), "stone")
	Models.box(self, Vector3(5.6, 0.5, 5.6), Vector3(22, 4.2, -264.5), Color(0.35, 0.35, 0.37), Vector3.ZERO, "stone")
	# west wall with a doorway
	Models.solid(self, Vector3(0.5, 4, 1.5), Vector3(19.7, 2, -262.75), Color(0.4, 0.4, 0.42), "stone")
	Models.solid(self, Vector3(0.5, 4, 1.5), Vector3(19.7, 2, -266.25), Color(0.4, 0.4, 0.42), "stone")
	Models.box(self, Vector3(1.6, 0.6, 0.7), Vector3(22.6, 0.3, -264.5), Color(0.3, 0.3, 0.3), Vector3.ZERO, "stone")
	note(Vector3(22.6, 0.62, -264.5), Story.hymn, "Read the carving")
	light(Vector3(22, 2.5, -264.5), Color(0.5, 0.7, 1.0), 0.8, 5)
	# the grave
	place("tombstone", Vector3(14, 0, -268), 180, 1.1, 3)
	var lan := place("lantern", Vector3(14.6, 0.2, -267.3))
	lan.name = "GraveLantern"
	light(Vector3(14.5, 0.8, -267), Color(1, 0.6, 0.3), 1.6, 6)
	Interactable.make(self, Vector3(14, 0.6, -267), "Examine the grave", func(_p):
		var d := Story.grave()
		main.open_note(d[0], d[1])
		main.after_note(func():
			Game.keys["Church Key"] = true
			Sfx.play("pickup")
			Game.say("You pull the CHURCH KEY from the soil.")
			main.ui.set_objective("Enter the chapel.")
			_grave_ambush())
		return true, 2.4)
	# chapel facade (interior built in area E)
	trigger(Vector3(0, 1, -212), Vector3(20, 3, 1), func(): _enter_area("D"))


func _grave_ambush() -> void:
	await get_tree().create_timer(1.0).timeout
	Sfx.play("screech", -4)
	main.ui.subtitle("VILLAGERS: The grave! He opened his own grave!", 3)
	var pts := [Vector3(28, 0, -248), Vector3(28, 0, -276), Vector3(2, 0, -286), Vector3(3, 0, -236), Vector3(26, 0, -262)]
	for i in pts.size() + (2 if Game.is_haunted() else 0):
		var e := enemy("villager", pts[i % pts.size()] + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), true)
		e.add_torch()
	for p in [Vector3(11, 0, -264), Vector3(17, 0, -272)]:
		var e := enemy("villager", p, true, "down")
		e.body.state = "down"
		e.body.state_t = 1.0
		e.state_t = 0.5
		main.spark(p, Vector3.UP, Color(0.2, 0.15, 0.1), 16)


# ------------------------------------------------------------------ AREA E: chapel
func _area_e() -> void:
	var stone := Color(0.33, 0.31, 0.3)
	Models.solid(self, Vector3(40, 1, 46), Vector3(0, -0.5, -313), Color(0.25, 0.23, 0.22), "stone")
	Models.solid(self, Vector3(1, 10, 44), Vector3(-11.5, 5, -313), stone, "stone")
	Models.solid(self, Vector3(1, 10, 44), Vector3(11.5, 5, -313), stone, "stone")
	Models.solid(self, Vector3(24, 10, 1), Vector3(0, 5, -335), stone, "stone")
	Models.solid(self, Vector3(10, 10, 1), Vector3(-6.5, 5, -292), stone, "stone")
	Models.solid(self, Vector3(10, 10, 1), Vector3(6.5, 5, -292), stone, "stone")
	Models.solid(self, Vector3(3, 6, 1), Vector3(0, 7, -292), stone, "stone")
	for side in [-1, 1]:
		Models.box(self, Vector3(14, 0.4, 46), Vector3(side * 5.8, 12.2, -313), Color(0.2, 0.12, 0.1), Vector3(0, 0, side * -35), "wood")
	Models.box(self, Vector3(3, 14, 3), Vector3(0, 12, -293), stone, Vector3.ZERO, "stone")
	Models.cyl(self, 0.0, 2.4, 4, Vector3(0, 21, -293), Color(0.2, 0.12, 0.1), 4, Vector3.ZERO, "wood")
	place("cross", Vector3(0, 23, -293), 0, 0.6)
	var door := gate(Vector3(0, 0, -292), 3, "Church Key", "Open the chapel doors", func():
		Game.say("The doors groan open.")
		main.ui.set_objective(""))
	door.name = "ChapelDoor"
	for z in range(-300, -318, -3):
		place("pew", Vector3(-5, 0, z), 180)
		place("pew", Vector3(5, 0, z), 180)
		Models.collider(self, Vector3(4, 1, 0.8), Vector3(-5, 0.5, z))
		Models.collider(self, Vector3(4, 1, 0.8), Vector3(5, 0.5, z))
	altar = place("altar", Vector3(0, 0, -327.5))
	var altar_col := Models.collider(altar, Vector3(3.2, 1.2, 1.3), Vector3(0, 0.6, 0))
	altar_col.name = "AltarCol"
	Models.box(self, Vector3(2.4, 0.05, 1.2), Vector3(0, 0.03, -327.5), Color(0.0, 0.0, 0.0), Vector3.ZERO, "none")
	place("cross", Vector3(0, 0, -334), 0, 1.4)
	light(Vector3(0, 5, -321), Color(1, 0.7, 0.45), 1.6, 14)
	for p in [Vector3(-10.5, 3, -300), Vector3(10.5, 3, -300), Vector3(-10.5, 3, -318), Vector3(10.5, 3, -318), Vector3(-6, 3, -333), Vector3(6, 3, -333)]:
		torch(p)
	for x in [-10.9, 10.9]:
		for z in [-304, -312, -320]:
			var win := Models.box(self, Vector3(0.1, 3.2, 1.4), Vector3(x, 5.5, z), Color.WHITE, Vector3.ZERO, "none")
			win.material_override = Models.glow_mat(Color(0.5, 0.1, 0.12), 1.2)
	# the three bells: carvings are what matter, not position
	var bells := [["low", "a sleeping face", Vector3(0, 0, -322)], ["high", "a bird in flight", Vector3(-4, 0, -322)], ["mid", "a weeping woman", Vector3(4, 0, -322)]]
	for b in bells:
		var pos: Vector3 = b[2]
		Models.solid(self, Vector3(0.8, 1.1, 0.8), pos + Vector3(0, 0.55, 0), stone, "stone")
		for x in [-1.1, 1.1]:
			Models.box(self, Vector3(0.2, 3.8, 0.2), pos + Vector3(x, 1.9, -0.6), Color(0.25, 0.15, 0.08), Vector3.ZERO, "wood")
		Models.box(self, Vector3(2.4, 0.2, 0.2), pos + Vector3(0, 3.8, -0.6), Color(0.25, 0.15, 0.08), Vector3.ZERO, "wood")
		var bell := place("bell", pos + Vector3(0, 3.7, -0.6), 0, {"low": 0.75, "mid": 0.6, "high": 0.45}[b[0]])
		var lbl := Label3D.new()
		lbl.text = b[1]
		lbl.font_size = 28
		lbl.modulate = Color(0.8, 0.75, 0.65)
		lbl.position = pos + Vector3(0, 1.3, 0.42)
		add_child(lbl)
		var which: String = b[0]
		Interactable.make(self, pos + Vector3(0, 1, 0.6), "Ring the bell carved with %s" % b[1], func(_p): _ring(which, bell), 1.8)
	trigger(Vector3(0, 1, -295), Vector3(8, 3, 1), _chapel_intro)


func _ring(which: String, bell: Node3D) -> void:
	if Game.flags.get("bells_solved", false):
		return
	Sfx.play("bell_" + which, 0)
	var tw := create_tween()
	tw.tween_property(bell, "rotation:x", 0.35, 0.2)
	tw.tween_property(bell, "rotation:x", -0.25, 0.4)
	tw.tween_property(bell, "rotation:x", 0.0, 0.4)
	bell_seq.append(which)
	var want := ["low", "high", "mid"]
	for i in bell_seq.size():
		if bell_seq[i] != want[i]:
			bell_seq.clear()
			await get_tree().create_timer(0.8).timeout
			Sfx.play("screech", -2)
			main.shake(0.6)
			main.ui.subtitle("The bells shriek in discord. Something answers from the dark.", 3)
			for p in [Vector3(-9, 0, -298), Vector3(9, 0, -298), Vector3(-9, 0, -330), Vector3(9, 0, -330)]:
				enemy("zealot", p, true)
			return
	if bell_seq.size() == 3:
		Game.flags["bells_solved"] = true
		await get_tree().create_timer(1.0).timeout
		Sfx.play("bell", 2)
		main.shake(0.4)
		var t2 := create_tween()
		t2.tween_property(altar, "position:z", -330.5, 3.0).set_trans(Tween.TRANS_SINE)
		main.ui.subtitle("Stone grinds against stone. The altar slides back, revealing a stairway down.", 4)
		main.ui.set_objective("Descend beneath the altar.")
		await t2.finished
		Interactable.make(self, Vector3(0, 0.5, -327.5), "Descend into the crypt", func(_p): main.teleport("F"), 2.2, true)


func _chapel_intro() -> void:
	_enter_area("E")
	await get_tree().create_timer(1.0).timeout
	var ald := Body.new().setup("aldric")
	ald.position = Vector3(0, 0, -325.5)
	add_child(ald)
	ald.set_state("idle")
	ald.animate(0.01, 0)
	player.set_controls(false)
	main.ui.cinema(true)
	cine.global_position = Vector3(-3, 2.2, -318)
	cine.look_at(Vector3(0, 1.6, -325.5))
	cine.make_current()
	Sfx.ambience("amb_organ", -6)
	var lines := [
		["FATHER ALDRIC", "Ah. There you are, child. We kept the candles lit."],
		["ROOK", "Where's Dr. Hart?"],
		["FATHER ALDRIC", "Below. With the others who listened. You'll join us soon enough. You always do."] if Game.loop == 1 else ["FATHER ALDRIC", "Back again? You never learn. That's what makes you such a good son."],
		["FATHER ALDRIC", "Ring the hymn, and come down to me. The Choir is waiting to sing your name."],
	]
	for l in lines:
		main.ui.subtitle("%s: %s" % l, 3.2)
		await get_tree().create_timer(3.4).timeout
	Sfx.play("bell", 2)
	main.flash(Color.WHITE)
	ald.queue_free()
	await get_tree().create_timer(0.8).timeout
	main.ui.cinema(false)
	player.cam.make_current()
	player.set_controls(true)
	main.ui.set_objective("Ring the three bells in the order of the hymn.")
	if not Game.flags.has("hymn_read"):
		main.ui.message("Perhaps something in the cemetery explains the bells...", 4)


# ------------------------------------------------------------------ AREA F: crypt + sanctum
func _area_f() -> void:
	var st := Color(0.28, 0.25, 0.24)
	var X := 200.0
	Models.solid(self, Vector3(40, 1, 120), Vector3(X, -0.5, -50), Color(0.2, 0.18, 0.17), "stone")
	# corridor
	Models.solid(self, Vector3(1, 5, 66), Vector3(X - 3.5, 2.5, -33), st, "stone")
	Models.solid(self, Vector3(1, 5, 20), Vector3(X + 3.5, 2.5, -10), st, "stone")
	Models.solid(self, Vector3(1, 5, 22), Vector3(X + 3.5, 2.5, -45), st, "stone")
	Models.solid(self, Vector3(8, 1, 70), Vector3(X, 5.5, -33), Color(0.15, 0.13, 0.12), "stone")
	Models.solid(self, Vector3(8, 5, 1), Vector3(X, 2.5, 1), st, "stone")
	for z in range(-6, -66, -10):
		torch(Vector3(X - 2.9, 2.6, z))
		torch(Vector3(X + 2.9, 2.6, z - 5))
	# Lena's cell (east, z -20..-34)
	Models.solid(self, Vector3(9, 5, 1), Vector3(X + 8, 2.5, -20), st, "stone")
	Models.solid(self, Vector3(9, 5, 1), Vector3(X + 8, 2.5, -34), st, "stone")
	Models.solid(self, Vector3(1, 5, 15), Vector3(X + 12.5, 2.5, -27), st, "stone")
	Models.solid(self, Vector3(9, 1, 15), Vector3(X + 8, 5.5, -27), Color(0.15, 0.13, 0.12), "stone")
	place("cage", Vector3(X + 9, 0, -27))
	Models.collider(self, Vector3(2.2, 3, 2.2), Vector3(X + 9, 1.5, -27))
	var lena := Body.new().setup("lena")
	lena.position = Vector3(X + 9, 0, -27)
	lena.rotation.y = deg_to_rad(90)
	add_child(lena)
	lena.set_state("kneel")
	lena.animate(0.01, 0)
	light(Vector3(X + 9, 3.5, -27), Color(0.6, 0.7, 0.9), 1.2, 7)
	note(Vector3(X + 5, 0.8, -32.5), Story.confession, "Read the confession")
	Models.box(self, Vector3(1.2, 0.8, 0.8), Vector3(X + 5, 0.4, -32.5), Color(0.3, 0.2, 0.12), Vector3.ZERO, "wood")
	Interactable.make(self, Vector3(X + 7.6, 1, -27), "Talk to the woman in the cage", func(p): _talk_lena(p), 2.5, true)
	# ossuary alcove with the magnum (east, z -60..-64)
	Models.solid(self, Vector3(6, 5, 1), Vector3(X + 6.5, 2.5, -34.5 - 0.0), st, "stone")
	Models.solid(self, Vector3(6, 5, 1), Vector3(X + 6.5, 2.5, -66), st, "stone")
	Models.solid(self, Vector3(1, 5, 32), Vector3(X + 9.5, 2.5, -50), st, "stone")
	for z in [-40, -46, -52]:
		Models.solid(self, Vector3(2.2, 0.8, 1.1), Vector3(X + 7.5, 0.4, z), Color(0.25, 0.2, 0.15), "wood")
	var coffin := Models.solid(self, Vector3(1.1, 0.9, 2.3), Vector3(X + 7.5, 0.45, -60), Color(0.3, 0.1, 0.08), "wood")
	coffin.name = "MagnumCoffin"
	Interactable.make(self, Vector3(X + 7.5, 0.8, -58.5), "Open the ornate coffin", func(_p):
		Game.give_weapon("magnum")
		Game.add_ammo("magnum", 8)
		player.refresh_gun()
		Sfx.play("pickup")
		main.open_note("BROKEN CHOIR .50", "A heavy revolver lies across the chest of a skeleton in a leather jacket.\n\nEngraved on the grip: [b]E.R.[/b]\n\n[i]You got the magnum. Press [3] to equip it.[/i]"), 2.0, true)
	shard(Vector3(X + 8.5, 0.1, -48))
	# merchant, again
	var merchant := Body.new().setup("merchant")
	merchant.position = Vector3(X - 2.5, 0, -12)
	merchant.rotation.y = deg_to_rad(-90)
	add_child(merchant)
	merchant.animate(0.01, 0)
	light(Vector3(X - 2, 2.4, -12), Color(0.5, 0.65, 1.0), 1.6, 6)
	Interactable.make(self, Vector3(X - 1.5, 1, -12), "Trade with the Peddler", func(_p): main.open_merchant(), 2.2)
	crate(Vector3(X + 2.5, 0, -4), "handgun", 15)
	crate(Vector3(X - 2.5, 0, -40), "herb")
	# enemies
	for z in ([] if past("F2") else [-18, -38, -44, -54, -60]):
		var e := enemy("zealot", Vector3(X + randf_range(-1.5, 1.5), 0, z), false, "pray")
		e.aggro_radius = 9
	if Game.is_haunted() and not past("F2"):
		var b := enemy("brute", Vector3(X, 0, -50))
		b.aggro_radius = 12
	var dg := gate(Vector3(X, 0, -66), 4, "Crypt Key", "Unlock the sanctum door", func(): pass)
	dg.name = "SanctumDoor"
	Models.solid(self, Vector3(1.5, 5, 1), Vector3(X - 2.75, 2.5, -66), st, "stone")
	Models.solid(self, Vector3(1.5, 5, 1), Vector3(X + 2.75, 2.5, -66), st, "stone")
	# sanctum ring
	var c := Vector3(X, 0, -90)
	for i in 16:
		var a := TAU * i / 16.0
		if i == 4:
			continue  # entrance faces +z
		var p := c + Vector3(cos(a), 0, sin(a)) * 18.5
		var w := Models.solid(self, Vector3(7.4, 12, 1), p + Vector3(0, 6, 0), st, "stone")
		w.rotation.y = -a + PI / 2
	Models.solid(self, Vector3(6, 5, 7), Vector3(X - 5.5, 2.5, -69.5), st, "stone")
	Models.solid(self, Vector3(6, 5, 7), Vector3(X + 5.5, 2.5, -69.5), st, "stone")
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		Models.solid(self, Vector3(1.4, 12, 1.4), c + Vector3(cos(a) * 12, 6, sin(a) * 12), Color(0.3, 0.26, 0.25), "stone")
		torch(c + Vector3(cos(a) * 11.2, 3, sin(a) * 11.2))
	great_bell = place("bell", c + Vector3(0, 12, 0), 0, 2.2)
	for k in 3:
		Models.box(self, Vector3(0.15, 6, 0.15), c + Vector3(0, 16, 0), Color(0.15, 0.15, 0.15), Vector3(0, k * 60, 0), "none")
	light(c + Vector3(0, 8, 0), Color(0.8, 0.2, 0.25), 2.0, 30)
	sanctum_blocker = Models.collider(self, Vector3(5, 6, 1), Vector3(X, 3, -72))
	sanctum_blocker.collision_layer = 0
	trigger(Vector3(X, 1, -77), Vector3(5, 3, 1), _boss_intro)


func _talk_lena(_p) -> void:
	player.set_controls(false)
	for l in Story.lena_lines():
		main.ui.subtitle("%s: %s" % l, 3.6)
		await get_tree().create_timer(3.8).timeout
	player.set_controls(true)
	Game.keys["Crypt Key"] = true
	Sfx.play("pickup")
	Game.say("Got the CRYPT KEY.")
	main.ui.set_objective("Enter the sanctum.")


func _boss_intro() -> void:
	Game.save_checkpoint("F2")
	mood("sanctum", 1.5)
	sanctum_blocker.collision_layer = 1
	player.set_controls(false)
	main.ui.cinema(true)
	boss = Boss.new()
	boss.main = main
	boss.center = Vector3(200, 0, -90)
	boss.position = Vector3(200, 0, -96)
	add_child(boss)
	boss.body.rotation.y = 0
	boss.body.set_state("cast")
	cine.global_position = Vector3(203, 1.4, -80)
	cine.look_at(Vector3(200, 2.5, -96))
	cine.make_current()
	Sfx.ambience("amb_chant", -6)
	var lines := [
		["FATHER ALDRIC", "Do you hear it, child? Every voice in this valley, singing one note."],
		["FATHER ALDRIC", "I was like you once. I came up the road with a gun and a mission."],
		["ROOK", "Then you know how this ends."],
		["FATHER ALDRIC", "Oh, I do. Better than you."],
	]
	for l in lines:
		main.ui.subtitle("%s: %s" % l, 3.0)
		await get_tree().create_timer(3.2).timeout
	main.ui.cinema(false)
	player.cam.make_current()
	player.set_controls(true)
	main.ui.title_card("FATHER ALDRIC", "Shepherd of the Choir")
	Sfx.music("boss_music", -4)
	Sfx.ambience("")
	boss.go("recover")
	boss.defeated.connect(_boss_dead)
	main.ui.set_objective("Kill Father Aldric.")


func _boss_dead() -> void:
	Sfx.music("")
	main.ui.boss_bar("", -1)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.die(Vector3.UP)
	await get_tree().create_timer(2.0).timeout
	Sfx.play("door", 4, 0.5)
	main.shake(0.5)
	await get_tree().create_timer(1.2).timeout
	var tw := create_tween()
	tw.tween_property(great_bell, "position:y", 3.6, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play("bell", 6, 0.6)
	Sfx.play("kick", 6, 0.3)
	main.shake(1.5)
	main.spark(great_bell.global_position + Vector3(0, -3, 0), Vector3.UP, Color(0.3, 0.25, 0.2), 40)
	Models.collider(self, Vector3(4, 4, 4), Vector3(200, 2, -90))
	Game.flags["boss_dead"] = true
	main.ui.subtitle("ROOK: It's done. Time to get out of here.", 3)
	main.ui.set_objective("Reach the extraction point (north passage).")
	# north passage opens
	var exit_p := Vector3(200, 0, -108)
	for n in get_children():
		if n is StaticBody3D and n.global_position.distance_to(exit_p + Vector3(0, 6, 0)) < 1.0:
			n.queue_free()
	light(exit_p + Vector3(0, 2, 0), Color(0.6, 0.7, 1.0), 2.5, 10)
	Interactable.make(self, exit_p + Vector3(0, 1, 1.5), "Climb toward the cliff", func(_p): main.teleport("G"), 2.8)
	var bell_msg := "Examine the fallen bell"
	if Game.is_haunted() and Game.shards >= 5:
		bell_msg = "Press the five shards against the bell"
	Interactable.make(self, Vector3(200, 1, -86.5), bell_msg, func(p): _bell_choice(p), 3.0)


func _bell_choice(_p) -> void:
	if Game.is_haunted() and Game.shards >= 5:
		main.ui.show_choice("The shards burn in your palm. The bell is humming your name.\nIf you do this, there is no going back.", ["Shatter the bell", "Not yet"])
		main.modal_open("choice")
		var i: int = await main.ui.choice_made
		main.close_modal()
		if i == 0:
			main.ending_dawn()
	elif Game.is_haunted():
		main.open_note("THE FALLEN BELL", "Its surface is split by five deep cracks, as if pieces were once pried loose.\n\nYou have found [b]%d[/b] of the five shards.\n\n[i]It's still humming. It knows you'll be back.[/i]" % Game.shards)
	else:
		main.open_note("THE FALLEN BELL", "Its surface is split by five deep cracks, as if pieces were once pried loose and hidden away.\n\nSomeone has scratched letters into the metal:\n\n[b]FIND THEM NEXT TIME. — L.[/b]\n\n[i]Next time?[/i]")


# ------------------------------------------------------------------ AREA G: cliff
func _area_g() -> void:
	var X := 400.0
	Models.solid(self, Vector3(34, 2, 50), Vector3(X, -1, -8), Color(0.3, 0.3, 0.3), "stone")
	wall(Vector3(X - 17, 3, -8), Vector3(1, 6, 50))
	wall(Vector3(X + 17, 3, -8), Vector3(1, 6, 50))
	wall(Vector3(X, 3, -33), Vector3(34, 6, 1))
	wall(Vector3(X, 3, 17), Vector3(34, 6, 1))
	Models.cyl(self, 6, 6, 0.1, Vector3(X, 0.02, -18), Color(0.25, 0.25, 0.27), 16, Vector3.ZERO, "none")
	Models.box(self, Vector3(6, 0.03, 1), Vector3(X, 0.08, -18), Color(0.9, 0.9, 0.9), Vector3.ZERO, "none")
	Models.box(self, Vector3(1, 0.03, 6), Vector3(X - 2.5, 0.08, -18), Color(0.9, 0.9, 0.9), Vector3.ZERO, "none")
	Models.box(self, Vector3(1, 0.03, 6), Vector3(X + 2.5, 0.08, -18), Color(0.9, 0.9, 0.9), Vector3.ZERO, "none")
	var heli := place("helicopter", Vector3(X, 0, -18), 20)
	heli_rotor = heli.find_child("Rotor", true, false)
	Models.collider(self, Vector3(2.4, 3, 6), Vector3(X, 1.5, -18), deg_to_rad(20))
	light(Vector3(X + 1, 3.5, -16), Color(1, 0.1, 0.1), 2.0, 10)
	for i in 8:
		place("tree", Vector3(X + randf_range(-15, 15), 0, randf_range(8, 15)), randf() * 360, 1.0, i)
	Interactable.make(self, Vector3(X - 1.6, 1, -15.5), "Board the helicopter", func(_p): main.ending_loop(), 3.2, true)


# ------------------------------------------------------------------ area transitions
func _enter_area(a: String, silent := false) -> void:
	var cards := {
		"A": ["I. THE ROAD", "October. The mountain pass above Grauwald."],
		"B": ["II. GRAUWALD", "Population: unknown."],
		"C": ["III. THE BUTCHER'S YARD", ""],
		"D": ["IV. STILL WATER", "Don't go near the lake."],
		"E": ["V. THE CHAPEL OF THE CHOIR", ""],
		"F": ["VI. THE VIGIL BELOW", ""],
		"G": ["VII. EXTRACTION", ""],
	}
	var moods := {"A": "forest", "B": "village", "C": "farm", "D": "lake", "E": "church", "F": "crypt", "G": "cliff"}
	var objectives := {
		"A": "Follow the road to Grauwald.", "B": "Search the village for the research team.", "C": "Find a way through the farm.",
		"D": "Search the cemetery. Find a way into the chapel.", "E": "", "F": "Find Dr. Hart.", "G": "Board the helicopter.",
	}
	var ambs := {"A": "amb_wind", "B": "amb_wind", "C": "amb_wind", "D": "amb_wind", "E": "amb_organ", "F": "amb_chant", "G": "amb_wind"}
	if a == "F2":
		mood("sanctum", 0.0)
		Sfx.ambience("amb_chant", -14)
		main.ui.set_objective("Enter the sanctum.")
		return
	if Game.flags.get("entered_" + a, false) and not silent:
		return
	Game.flags["entered_" + a] = true
	mood(moods[a], 0.0 if silent else 2.5)
	Sfx.ambience(ambs[a], -10 if a != "F" else -14)
	if a in ["A", "B", "C", "D", "F", "G"]:
		Game.save_checkpoint(a)
	if not silent or a == "A" or a in ["F", "G"]:
		main.ui.title_card(cards[a][0], cards[a][1])
	if objectives[a] != "":
		main.ui.set_objective(objectives[a])


func enter(a: String) -> void:
	_enter_area(a, true)


# ------------------------------------------------------------------ per-frame ambience
func _physics_process(delta: float) -> void:
	_siege_process(delta)
	var t := Time.get_ticks_msec() * 0.001
	for l in flicker_lights:
		l.light_energy = float(l.get_meta("base")) * (0.85 + 0.15 * sin(t * 13.0 + l.position.x) * sin(t * 7.3 + l.position.z))
	if heli_rotor:
		heli_rotor.rotation.y += delta * 25.0
	if player == null:
		return
	var pp := player.global_position
	# butcher reinforcements + boss bar
	if butcher and is_instance_valid(butcher) and butcher.state != "dead":
		main.ui.boss_bar("THE BUTCHER", butcher.hp / butcher.max_hp)
		farm_spawn_t -= delta
		if farm_spawn_t <= 0:
			farm_spawn_t = 22.0
			for i in 2:
				if get_tree().get_nodes_in_group("enemies").size() < 4:
					enemy("villager", Vector3([-26, 26][i], 0, -185 + randf_range(-10, 10)), true)
	if boss and is_instance_valid(boss) and boss.state != "dead":
		main.ui.boss_bar("FATHER ALDRIC" if boss.phase == 1 else "THE CHOIR", boss.hp / boss.max_hp)
	# the lake
	if pp.z < -212 and pp.z > -292 and lake_monster:
		lake_t -= delta
		if lake_t <= 0:
			lake_t = randf_range(14, 24)
			_lake_rise(pp)
	# crows scatter
	for c in crows:
		if is_instance_valid(c) and not c.has_meta("fly") and c.global_position.distance_to(pp) < 6:
			c.set_meta("fly", true)
			Sfx.play_at("knife", c.global_position, self, -4, 2.0)
			var tw := create_tween()
			tw.tween_property(c, "position", c.position + Vector3(randf_range(-10, 10), 14, randf_range(-10, 10)), 2.5)
			tw.tween_callback(c.queue_free)


func _lake_rise(pp: Vector3) -> void:
	lake_monster.position = Vector3(-24, -8, clampf(pp.z, -280, -222))
	var tw := create_tween()
	tw.tween_property(lake_monster, "position:y", -1.6, 2.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.0)
	tw.tween_property(lake_monster, "position:y", -9.0, 3.0).set_trans(Tween.TRANS_SINE)
	Sfx.play_at("splash", lake_monster.position + Vector3(0, 8, 0), self, 4, 0.6)
	get_tree().create_timer(1.0).timeout.connect(func(): Sfx.play_at("boss_roar", lake_monster.global_position + Vector3(0, 6, 0), self, -2, 0.5))
