class_name Enemy
extends CharacterBody3D
## Villagers, zealots and brutes. Headshots and leg shots stagger; staggered enemies can be kicked.

signal killed(enemy: Enemy)

const LINES := ["There he is!", "Take him to the Father!", "The bell hungers...", "Outsider!", "Kill him! Kill him!", "Behind you... behind you...", "He must hear the Choir!"]
const HAUNTED_LINES := ["Father...? You came home.", "Again. Again. Again.", "Welcome back, Elias.", "How many times now?", "We kept your bed warm, Father.", "You always come back."]

var kind := "villager"
var main: Node
var body: Body
var hp := 30.0
var max_hp := 30.0
var speed := 1.9
var dmg := 14.0
var reach := 1.7
var windup := 0.75
var aggro := false
var aggro_radius := 16.0
var state := "idle"
var state_t := 0.0
var cd := 0.0
var voice_t := 0.0
var stagger_acc := 0.0
var home := Vector3.ZERO
var leave_target := Vector3.ZERO
var avoid_t := 0.0
var avoid_dir := 1.0
var headless := false
var can_revive := false
var charge_dir := Vector3.ZERO
var charge_cd := 5.0
var boss_title := ""
var drops := true
var label: Label3D
var idle_anim := "idle"
var seed_value := 0
var torch_light: OmniLight3D


func setup(k: String, m: Node, sv := 0) -> Enemy:
	kind = k
	main = m
	seed_value = sv
	var mult := Game.enemy_hp_mult()
	match k:
		"villager":
			hp = 30.0
			speed = randf_range(1.6, 2.3) + 0.15 * (Game.loop - 1)
			dmg = 14.0
		"zealot":
			hp = 45.0
			speed = randf_range(2.2, 2.7)
			dmg = 18.0
			windup = 0.6
		"brute":
			hp = 340.0
			speed = 2.3
			dmg = 38.0
			reach = 2.6
			windup = 0.95
			aggro_radius = 40.0
	hp *= mult
	max_hp = hp
	can_revive = kind == "villager" and randf() < (0.1 if Game.loop == 1 else 0.28)
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var sc := 1.45 if kind == "brute" else 1.0
	cap.radius = 0.35 * sc
	cap.height = 1.85 * sc
	cs.shape = cap
	cs.position.y = 0.925 * sc
	add_child(cs)
	body = Body.new().setup(kind, seed_value)
	add_child(body)
	add_to_group("enemies")
	add_to_group("hittable")
	home = global_position
	voice_t = randf_range(2, 8)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 2.3 * sc
	label.font_size = 22
	label.outline_size = 6
	label.modulate = Color(1, 0.85, 0.75)
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.no_depth_test = true
	label.visible = false
	add_child(label)
	if aggro:
		body.set_eye_glow(3.0)
	set_physics_process(true)


func add_torch() -> void:
	var t := Node3D.new()
	body.hand_r.add_child(t)
	Models.box(t, Vector3(0.05, 0.05, 0.7), Vector3(0, 0, -0.2), Color(0.3, 0.2, 0.1), Vector3.ZERO, "wood")
	Models.sphere(t, 0.1, Vector3(0, 0, -0.55), Color.ORANGE, 5, Models.glow_mat(Color(1, 0.5, 0.1), 5))
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1, 0.55, 0.2)
	torch_light.omni_range = 7
	torch_light.light_energy = 1.6
	torch_light.position = Vector3(0, 0, -0.6)
	t.add_child(torch_light)


func speak(text: String) -> void:
	label.text = text
	label.visible = true
	label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): label.visible = false)


func set_aggro() -> void:
	if aggro or state == "dead":
		return
	aggro = true
	body.set_eye_glow(3.0)
	if state in ["idle", "pray"]:
		go("chase")
	if randf() < 0.5:
		speak(_line())


func _line() -> String:
	if Game.is_haunted() and randf() < 0.6:
		return HAUNTED_LINES[randi() % HAUNTED_LINES.size()]
	return LINES[randi() % LINES.size()]


func go(s: String) -> void:
	state = s
	state_t = 0.0


func player() -> Player:
	return main.player if main else null


func is_kickable() -> bool:
	return state == "stagger" and kind != "brute" or (kind == "brute" and state == "stagger" and state_t > 0.2)


func kicked(dir: Vector3) -> void:
	if state == "dead":
		return
	hp -= 30.0 if kind != "brute" else 45.0
	if hp <= 0:
		die(dir)
		return
	if kind == "brute":
		go("recover")
		cd = 1.0
		return
	body.fall_dir = 1.0
	go("down")
	velocity = dir * 6.0


func take_hit(amount: float, pos: Vector3, dir: Vector3, weapon: String) -> void:
	if state == "dead":
		return
	set_aggro()
	var sc := 1.45 if kind == "brute" else 1.0
	var local_y := pos.y - global_position.y
	var head := local_y > 1.5 * sc and not headless
	var legs := local_y < 0.8 * sc
	if head:
		amount *= 2.2 if weapon != "shotgun" else 1.6
		main.spark(pos, -dir, Color(0.5, 0.0, 0.0), 10)
	else:
		main.spark(pos, -dir, Color(0.4, 0.0, 0.02), 5)
	Sfx.play_at("flesh", pos, main.world, -4)
	hp -= amount
	if hp <= 0:
		die(dir, head)
		return
	if kind == "brute":
		stagger_acc += amount if head else amount * 0.4
		if stagger_acc > 70.0 and state != "charge":
			stagger_acc = 0.0
			go("stagger")
			Sfx.play_at("roar", global_position, main.world, -4, 1.3)
		elif state == "charge" and head:
			go("stagger")
		return
	if state in ["down", "rise"]:
		return
	if head or (legs and randf() < 0.6) or weapon == "shotgun" or weapon == "magnum" or (weapon == "knife" and randf() < 0.35):
		go("stagger")
		velocity = dir * (3.0 if weapon == "shotgun" else 1.0)


func die(dir: Vector3, head := false) -> void:
	if can_revive and not headless and head:
		# Something inside them doesn't need the head.
		headless = true
		can_revive = false
		hp = 25.0 * Game.enemy_hp_mult()
		speed += 1.6
		if body.parts.has("Head"):
			body.parts.Head.visible = false
		main.spark(global_position + Vector3(0, 1.6, 0), Vector3.UP, Color(0.5, 0, 0), 22)
		body.fall_dir = 1.0
		go("down")
		state_t = -1.0
		return
	go("dead")
	body.set_state("dead")
	body.fall_dir = 1.0 if randf() < 0.7 else -1.0
	body.set_eye_glow(0.0)
	collision_layer = 0
	collision_mask = 1
	remove_from_group("enemies")
	remove_from_group("hittable")
	velocity = dir * 3.0
	Sfx.play_at("death", global_position, main.world, -2, randf_range(0.8, 1.2))
	Game.kills += 1
	if torch_light:
		torch_light.light_energy = 0.4
	if drops:
		main.drop_loot(global_position, kind)
	killed.emit(self)
	var tw := create_tween()
	tw.tween_interval(12.0)
	tw.tween_callback(queue_free)


func start_leave(target: Vector3) -> void:
	if state == "dead":
		return
	leave_target = target
	aggro = false
	body.set_eye_glow(0.0)
	go("leave")


func _physics_process(delta: float) -> void:
	state_t += delta
	cd = maxf(0, cd - delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	var p := player()
	var to_p := Vector3.ZERO
	var dist := 999.0
	if p and is_instance_valid(p):
		to_p = p.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
	var anim_speed := 0.0
	var h := Vector3.ZERO

	match state:
		"idle", "pray":
			body.set_state(idle_anim if state == "idle" else "pray")
			if dist < aggro_radius * (0.5 if state == "pray" else 1.0) and p and not p.dead:
				set_aggro()
		"chase":
			if p == null or p.dead:
				go("idle")
			elif dist < reach:
				go("windup")
				Sfx.play_at("groan%d" % (randi() % 4), global_position, main.world, -3, randf_range(0.9, 1.2))
			else:
				if kind == "brute":
					charge_cd -= delta
					if charge_cd <= 0 and dist > 5 and dist < 18:
						charge_cd = randf_range(6, 9)
						go("charge_wind")
						Sfx.play_at("roar", global_position, main.world, 0)
				h = _steer(to_p.normalized(), delta) * speed
				anim_speed = speed
				_face(to_p, delta, 6.0)
				body.set_state("shamble" if kind != "brute" else "walk")
		"windup":
			_face(to_p, delta, 10.0)
			body.set_state("windup")
			if state_t > windup:
				go("strike")
				if p and dist < reach + 0.6 and (-body.global_transform.basis.z).dot(to_p.normalized()) > 0.3:
					p.take_damage(dmg, global_position, 6.0 if kind == "brute" else 2.5)
		"strike":
			body.set_state("strike")
			if state_t > 0.3:
				go("recover")
		"recover":
			body.set_state("idle")
			if state_t > (0.7 if kind != "brute" else 0.9):
				go("chase")
		"stagger":
			body.set_state("stagger")
			velocity.x = move_toward(velocity.x, 0, 8 * delta)
			velocity.z = move_toward(velocity.z, 0, 8 * delta)
			h = Vector3(velocity.x, 0, velocity.z)
			if state_t > (1.5 if kind != "brute" else 2.2):
				go("chase")
		"down":
			body.set_state("down")
			velocity.x = move_toward(velocity.x, 0, 10 * delta)
			velocity.z = move_toward(velocity.z, 0, 10 * delta)
			h = Vector3(velocity.x, 0, velocity.z)
			if state_t > 2.3:
				go("rise")
		"rise":
			body.set_state("rise")
			if state_t > 1.2:
				body.set_eye_glow(3.0)
				go("chase")
				aggro = true
		"charge_wind":
			_face(to_p, delta, 12.0)
			body.set_state("windup")
			if state_t > 0.8:
				charge_dir = to_p.normalized()
				go("charge")
		"charge":
			body.set_state("run")
			anim_speed = 8.0
			h = charge_dir * 8.5
			if p and dist < 1.9:
				p.take_damage(34.0, global_position, 12.0)
				go("recover")
			elif state_t > 1.6:
				go("recover")
			elif state_t > 0.2 and get_real_velocity().length() < 2.0:
				# slammed into something solid
				Sfx.play_at("kick", global_position, main.world, 2, 0.6)
				main.shake(0.6)
				go("stagger")
		"leave":
			var tl := leave_target - global_position
			tl.y = 0
			if tl.length() < 2.0:
				queue_free()
				return
			h = _steer(tl.normalized(), delta) * 2.2
			anim_speed = 2.2
			_face(tl, delta, 5.0)
			body.set_state("walk")
		"dead":
			velocity.x = move_toward(velocity.x, 0, 10 * delta)
			velocity.z = move_toward(velocity.z, 0, 10 * delta)
			h = Vector3(velocity.x, 0, velocity.z)
	if state != "dead":
		h += _separation() * 1.5
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()
	body.animate(delta, anim_speed)

	if aggro and state != "dead":
		voice_t -= delta
		if voice_t <= 0:
			voice_t = randf_range(4, 10)
			Sfx.play_at("groan%d" % (randi() % 4), global_position, main.world, -6, randf_range(0.85, 1.15) * (0.7 if kind == "brute" else 1.0))
			if randf() < 0.25 and dist < 14:
				speak(_line())


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), rate * delta)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0
		var l := d.length()
		if l < 1.1 and l > 0.001:
			push += d / l * (1.1 - l)
	return push


func _steer(dir: Vector3, delta: float) -> Vector3:
	if avoid_t > 0:
		avoid_t -= delta
		return (dir + dir.cross(Vector3.UP) * avoid_dir * 1.6).normalized()
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.8, 0)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1.6, 1 | 8, [get_rid()])
	if not space.intersect_ray(q).is_empty():
		var side := dir.cross(Vector3.UP)
		var ql := PhysicsRayQueryParameters3D.create(origin, origin + (dir + side).normalized() * 2.0, 1 | 8, [get_rid()])
		avoid_dir = 1.0 if space.intersect_ray(ql).is_empty() else -1.0
		avoid_t = 0.7
	return dir
