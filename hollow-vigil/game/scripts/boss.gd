class_name Boss
extends CharacterBody3D
## Father Aldric. Phase 1: priest who hurls choir orbs and summons zealots.
## Phase 2: the Beast — only the eye in its chest is truly vulnerable.

signal phase_changed(p: int)
signal defeated

var main: Node
var body: Body
var phase := 1
var hp := 380.0
var max_hp := 380.0
var state := "intro"
var state_t := 0.0
var cast_cd := 2.5
var summon_cd := 10.0
var slam_cd := 7.0
var eye_acc := 0.0
var center := Vector3.ZERO
var col: CollisionShape3D
var eye_open := true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.0
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	body = Body.new().setup("aldric")
	add_child(body)
	add_to_group("hittable")
	add_to_group("enemies")
	hp *= Game.enemy_hp_mult()
	max_hp = hp


func player() -> Player:
	return main.player


func go(s: String) -> void:
	state = s
	state_t = 0.0


func is_kickable() -> bool:
	return false


func finisher_ready() -> bool:
	return phase == 2 and state == "kneel" and state_t > 0.3


func finisher() -> void:
	hp -= 140.0 * Game.enemy_hp_mult()
	Sfx.play("kick")
	Sfx.play_at("boss_roar", global_position, main.world, 2, 1.3)
	main.spark(eye_pos(), Vector3.UP, Color(1, 0.7, 0.1), 30)
	main.shake(1.2)
	if hp <= 0:
		_die()
	else:
		go("recover")


func eye_pos() -> Vector3:
	if body.parts.has("Eye"):
		return body.parts.Eye.global_position
	return global_position + Vector3(0, 2.9, 0)


func take_hit(amount: float, pos: Vector3, dir: Vector3, weapon: String) -> void:
	if state in ["intro", "transform", "dead"]:
		return
	if phase == 1:
		if pos.y - global_position.y > 1.5:
			amount *= 1.6
		main.spark(pos, -dir, Color(0.4, 0, 0.1), 6)
		hp -= amount
		if hp <= 0:
			_transform()
		elif randf() < 0.08 or weapon == "magnum":
			go("flinch")
		return
	var on_eye := pos.distance_to(eye_pos()) < 0.85 and eye_open
	if on_eye:
		hp -= amount * (1.3 if state == "kneel" else 1.0)
		eye_acc += amount
		main.spark(pos, -dir, Color(1, 0.7, 0.1), 10)
		Sfx.play_at("flesh", pos, main.world, 2, 0.6)
		if eye_acc > 120.0 and state != "kneel":
			eye_acc = 0.0
			go("kneel")
			Sfx.play_at("boss_roar", global_position, main.world, 0, 1.2)
			main.ui.prompt_hint("The Beast is down! Get close and press [E]!")
	else:
		hp -= amount * 0.12
		main.spark(pos, -dir, Color(0.3, 0.1, 0.15), 3)
	if hp <= 0:
		_die()


func _transform() -> void:
	hp = 1
	go("transform")
	main.boss_transform(self)


func become_beast() -> void:
	body.queue_free()
	body = Body.new().setup("beast")
	add_child(body)
	phase = 2
	hp = 650.0 * Game.enemy_hp_mult()
	max_hp = hp
	var cap := col.shape as CapsuleShape3D
	cap.radius = 1.0
	cap.height = 4.4
	col.position.y = 2.2
	go("recover")
	phase_changed.emit(2)


func _die() -> void:
	go("dead")
	hp = 0
	body.set_state("dead")
	body.set_eye_glow(0)
	collision_layer = 0
	remove_from_group("hittable")
	remove_from_group("enemies")
	Sfx.play_at("boss_roar", global_position, main.world, 4, 0.7)
	defeated.emit()


func _physics_process(delta: float) -> void:
	state_t += delta
	var p := player()
	if p == null:
		return
	var to_p := p.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	if not is_on_floor():
		velocity.y -= 18 * delta
	var h := Vector3.ZERO
	var anim := 0.0
	eye_open = true
	match state:
		"intro", "transform", "dead":
			if state == "transform":
				body.set_state("cast")
		"flinch":
			body.set_state("stagger")
			if state_t > 0.6:
				go("recover")
		"recover":
			body.set_state("idle")
			_face(to_p, delta, 4)
			if state_t > 0.8:
				go("move")
		"move":
			_face(to_p, delta, 5)
			if phase == 1:
				var want := 9.0
				var dir := to_p.normalized() * (1.0 if dist > want else -0.6)
				dir += to_p.normalized().cross(Vector3.UP) * 0.6
				h = dir.normalized() * 1.8
				anim = 1.8
				body.set_state("walk")
				cast_cd -= delta
				summon_cd -= delta
				if summon_cd <= 0:
					summon_cd = 16.0
					go("summon")
				elif cast_cd <= 0:
					cast_cd = randf_range(2.0, 3.2)
					go("cast")
			else:
				slam_cd -= delta
				cast_cd -= delta
				if dist < 5.5:
					go("sweep_wind")
				elif slam_cd <= 0:
					slam_cd = randf_range(6, 9)
					go("leap")
				elif cast_cd <= 0 and dist > 9:
					cast_cd = 4.0
					go("cast")
				else:
					h = to_p.normalized() * 2.6
					anim = 2.6
					body.set_state("walk")
			var from_c := global_position - center
			from_c.y = 0
			if from_c.length() > 13.0:
				h += -from_c.normalized() * 2.0
		"cast":
			body.set_state("cast")
			_face(to_p, delta, 8)
			if state_t > 0.9:
				var n := 1 if phase == 1 else 3
				for i in n:
					var spread := (i - (n - 1) * 0.5) * 0.35
					main.spawn_orb(global_position + Vector3(0, 2.2 if phase == 1 else 4.0, 0), p, spread)
				go("recover")
		"summon":
			body.set_state("cast")
			if state_t > 1.4:
				main.boss_summon(3)
				go("recover")
		"sweep_wind":
			body.set_state("windup")
			_face(to_p, delta, 6)
			eye_open = false
			if state_t > 1.0:
				go("sweep")
				Sfx.play_at("knife", global_position, main.world, 6, 0.4)
				if dist < 6.8:
					p.take_damage(30, global_position, 10)
		"sweep":
			body.set_state("strike")
			if state_t > 0.5:
				go("recover")
		"leap":
			body.set_state("windup")
			eye_open = false
			if state_t < 0.6:
				_face(to_p, delta, 8)
			elif state_t < 1.3:
				h = to_p.normalized() * minf(dist, 14.0) / 0.7
				velocity.y = 6.0 if state_t < 0.7 else velocity.y
			else:
				main.shake(1.0)
				Sfx.play_at("kick", global_position, main.world, 6, 0.4)
				Sfx.play_at("bell_low", global_position, main.world, 0, 0.5)
				main.spark(global_position, Vector3.UP, Color(0.3, 0.25, 0.2), 30)
				if dist < 5.0:
					p.take_damage(26, global_position, 12)
				go("recover")
		"kneel":
			body.set_state("kneel")
			if state_t > 4.0:
				go("recover")
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()
	body.animate(delta, anim)
	if body.eye_mat:
		body.eye_mat.set_shader_parameter("emission_energy", 3.0 if eye_open else 0.2)


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() > 0.01:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), rate * delta)
