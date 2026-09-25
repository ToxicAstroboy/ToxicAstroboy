class_name Player
extends CharacterBody3D
## Over-the-shoulder survival-horror controller: aim-to-shoot (no moving while aiming),
## laser sight, knife, contextual kick on staggered enemies, quick-turn.

signal died

const WALK := 3.1
const RUN := 5.6
const GRAVITY := 18.0

var main: Node
var body: Body
var yaw: Node3D
var pitch: Node3D
var spring: SpringArm3D
var cam: Camera3D
var flashlight: SpotLight3D
var laser: MeshInstance3D
var dot: MeshInstance3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var gun_root: Node3D

var aiming := false
var controls := true
var dead := false
var fire_cd := 0.0
var reload_t := 0.0
var action_t := 0.0
var action := ""
var shake := 0.0
var invuln := 0.0
var step_t := 0.0
var turning := 0.0
var sway := Vector2.ZERO
var knock := Vector3.ZERO
var aim_target := Vector3.ZERO
var sensitivity := 0.0025


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	body = Body.new().setup("player")
	add_child(body)

	yaw = Node3D.new()
	yaw.top_level = true
	add_child(yaw)
	pitch = Node3D.new()
	pitch.position.y = 1.6
	yaw.add_child(pitch)
	spring = SpringArm3D.new()
	spring.spring_length = 2.6
	spring.collision_mask = 1
	spring.margin = 0.25
	spring.position = Vector3(0.5, 0, 0)
	spring.add_excluded_object(get_rid())
	pitch.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70
	cam.near = 0.05
	cam.far = 220
	spring.add_child(cam)

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 26
	flashlight.spot_angle = 26
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.82)
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.15, 1.45, -0.2)
	add_child(flashlight)

	_build_gun()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.012, 0.012, 1.0)
	laser = Models.mi(self, lm, Vector3.ZERO, Models.glow_mat(Color(1, 0.05, 0.05), 4))
	laser.top_level = true
	laser.visible = false
	dot = Models.sphere(self, 0.035, Vector3.ZERO, Color.RED, 6, Models.glow_mat(Color(1, 0.1, 0.1), 6))
	dot.top_level = true
	dot.visible = false
	yaw.rotation.y = rotation.y
	rotation.y = 0
	body.rotation.y = yaw.rotation.y
	add_to_group("player")


func _build_gun() -> void:
	gun_root = Node3D.new()
	body.hand_r.add_child(gun_root)
	gun_root.rotation_degrees = Vector3(90, 0, 0)
	muzzle = Node3D.new()
	gun_root.add_child(muzzle)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1, 0.75, 0.4)
	muzzle_light.omni_range = 8
	muzzle_light.light_energy = 0
	muzzle.add_child(muzzle_light)
	refresh_gun()


func refresh_gun() -> void:
	for c in gun_root.get_children():
		if c != muzzle:
			c.queue_free()
	var metal := Color(0.12, 0.12, 0.13)
	match Game.weapon:
		"handgun":
			Models.box(gun_root, Vector3(0.05, 0.08, 0.26), Vector3(0, 0.03, -0.1), metal, Vector3.ZERO, "none")
			Models.box(gun_root, Vector3(0.045, 0.14, 0.07), Vector3(0, -0.05, 0), Color(0.2, 0.14, 0.1), Vector3(-15, 0, 0), "none")
			muzzle.position = Vector3(0, 0.04, -0.25)
		"shotgun":
			Models.box(gun_root, Vector3(0.06, 0.07, 0.9), Vector3(0, 0.03, -0.35), metal, Vector3.ZERO, "none")
			Models.box(gun_root, Vector3(0.07, 0.1, 0.35), Vector3(0, -0.02, 0.15), Color(0.35, 0.2, 0.1), Vector3.ZERO, "wood")
			muzzle.position = Vector3(0, 0.05, -0.8)
		"magnum":
			Models.box(gun_root, Vector3(0.06, 0.09, 0.38), Vector3(0, 0.04, -0.15), Color(0.5, 0.5, 0.55), Vector3.ZERO, "none")
			Models.cyl(gun_root, 0.05, 0.05, 0.1, Vector3(0, 0.03, -0.02), Color(0.4, 0.4, 0.42), 6, Vector3(90, 0, 0), "none")
			Models.box(gun_root, Vector3(0.045, 0.15, 0.07), Vector3(0, -0.06, 0.03), Color(0.1, 0.05, 0.05), Vector3(-15, 0, 0), "none")
			muzzle.position = Vector3(0, 0.05, -0.36)


func look(rel: Vector2) -> void:
	if not controls or dead:
		return
	var s := sensitivity * (0.6 if aiming else 1.0)
	yaw.rotation.y -= rel.x * s
	pitch.rotation.x = clampf(pitch.rotation.x - rel.y * s, -1.1, 0.85)


func handle_input(event: InputEvent) -> void:
	if not controls or dead:
		return
	if event.is_action_pressed("quickturn") and not aiming and turning <= 0.0:
		turning = 0.25
		var tw := create_tween()
		tw.tween_property(yaw, "rotation:y", yaw.rotation.y + PI, 0.25).set_trans(Tween.TRANS_SINE)
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("knife") and action == "":
		do_knife()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("heal"):
		use_heal()
	for i in 3:
		if event.is_action_pressed("weapon%d" % (i + 1)):
			var w: String = ["handgun", "shotgun", "magnum"][i]
			if Game.weapons.has(w) and Game.weapon != w:
				Game.weapon = w
				reload_t = 0.0
				refresh_gun()
				Game.changed.emit()


func use_heal() -> void:
	if Game.hp >= Game.max_hp:
		Game.say("You're not hurt.")
		return
	if Game.herbs > 0:
		Game.herbs -= 1
		Game.heal(45)
		Sfx.play("pickup")
		Game.say("Green herb used. (+45)")
	elif Game.sprays > 0:
		Game.sprays -= 1
		Game.heal(100)
		Sfx.play("pickup")
		Game.say("First aid spray used.")
	else:
		Game.say("No healing items.")


func start_reload() -> void:
	var w := Game.weapon
	if reload_t > 0 or Game.mag[w] >= Game.mag_size(w) or Game.reserve(w) <= 0:
		return
	reload_t = 1.3 if w != "shotgun" else 1.8
	Sfx.play("reload")


func _finish_reload() -> void:
	var w := Game.weapon
	var need: int = Game.mag_size(w) - Game.mag[w]
	var take: int = mini(need, Game.reserve(w))
	Game.mag[w] += take
	Game.ammo[Game.ammo_type(w)] -= take
	Game.changed.emit()


func _physics_process(delta: float) -> void:
	yaw.global_position = global_position
	fire_cd = maxf(0, fire_cd - delta)
	invuln = maxf(0, invuln - delta)
	turning = maxf(0, turning - delta)
	if is_instance_valid(muzzle_light):
		muzzle_light.light_energy = maxf(0, muzzle_light.light_energy - delta * 60)
	if reload_t > 0:
		reload_t -= delta
		if reload_t <= 0:
			_finish_reload()
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -1.0

	var input := Vector2.ZERO
	var want_aim := false
	if controls and not dead:
		input = Input.get_vector("move_l", "move_r", "move_f", "move_b")
		want_aim = Input.is_action_pressed("aim") and action == ""
	if action != "":
		action_t -= delta
		if action_t <= 0:
			action = ""
	_set_aim(want_aim)

	var speed := 0.0
	if dead:
		velocity.x = 0
		velocity.z = 0
	elif aiming or action != "":
		velocity.x = move_toward(velocity.x, 0, 30 * delta)
		velocity.z = move_toward(velocity.z, 0, 30 * delta)
		body.rotation.y = lerp_angle(body.rotation.y, yaw.rotation.y, 18 * delta)
	else:
		var basis_y := Basis(Vector3.UP, yaw.rotation.y)
		var dir := basis_y * Vector3(input.x, 0, input.y)
		var running := Input.is_action_pressed("run") and input.y < 0.1
		var target := WALK if not running else RUN
		if input.length() < 0.1:
			target = 0.0
		velocity.x = dir.x * target
		velocity.z = dir.z * target
		speed = target * input.length()
		if speed > 0.1:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), 10 * delta)
			step_t -= delta * speed
			if step_t <= 0:
				step_t = 2.0
				Sfx.play("step%d" % (randi() % 3), -18, randf_range(0.85, 1.1))
	velocity += knock
	knock = knock.move_toward(Vector3.ZERO, 25 * delta)
	move_and_slide()

	if not dead:
		if aiming:
			body.set_state("aim")
		elif action != "":
			body.set_state(action)
		else:
			body.set_state("run" if speed > WALK + 0.5 else ("walk" if speed > 0.1 else "idle"))
		body.animate(delta, speed)
	else:
		body.animate(delta, 0)
	if is_instance_valid(gun_root):
		gun_root.visible = aiming or action == ""
	flashlight.global_rotation = Vector3(pitch.rotation.x * 0.8, yaw.rotation.y if aiming else body.rotation.y, 0)

	if aiming:
		_update_laser(delta)
		if Input.is_action_pressed("fire") and fire_cd <= 0 and reload_t <= 0:
			fire()
	else:
		laser.visible = false
		dot.visible = false

	shake = maxf(0, shake - delta * 2.5)
	cam.h_offset = randf_range(-1, 1) * shake * 0.15
	cam.v_offset = randf_range(-1, 1) * shake * 0.15


func _set_aim(on: bool) -> void:
	if on == aiming:
		return
	aiming = on
	var tw := create_tween().set_parallel()
	tw.tween_property(spring, "spring_length", 1.9 if on else 2.6, 0.18)
	tw.tween_property(spring, "position:x", 1.05 if on else 0.5, 0.18)
	tw.tween_property(cam, "fov", 52.0 if on else 70.0, 0.18)
	if on:
		sway = Vector2.ZERO


func _aim_ray(spread := 0.0) -> Dictionary:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	dir = (dir + cam.global_transform.basis.x * (sway.x + randf_range(-spread, spread)) + cam.global_transform.basis.y * (sway.y + randf_range(-spread, spread))).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 90.0, 1 | 2 | 8 | 16, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		hit = {"position": from + dir * 90.0, "normal": -dir, "collider": null}
	hit["dir"] = dir
	return hit


func _update_laser(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var steady := 0.0025 if Game.weapon != "magnum" else 0.004
	sway = sway.lerp(Vector2(sin(t * 1.3) * steady, cos(t * 1.7) * steady), 5 * delta)
	var hit := _aim_ray()
	aim_target = hit.position
	var from := muzzle.global_position
	var d := aim_target.distance_to(from)
	laser.visible = d > 0.05
	dot.visible = true
	if laser.visible:
		laser.global_position = (from + aim_target) * 0.5
		laser.look_at(aim_target, Vector3.UP if absf((aim_target - from).normalized().y) < 0.99 else Vector3.RIGHT)
		laser.scale = Vector3(1, 1, d)
	dot.global_position = aim_target - hit.dir * 0.03


func fire() -> void:
	var w := Game.weapon
	var cfg: Dictionary = Game.WEAPONS[w]
	if Game.mag[w] <= 0:
		fire_cd = 0.3
		Sfx.play("empty")
		if Game.reserve(w) > 0:
			start_reload()
		return
	Game.mag[w] -= 1
	fire_cd = cfg.rate
	Sfx.play(cfg.sound, -2, randf_range(0.95, 1.05))
	muzzle_light.light_energy = 6.0
	shake = 0.4 if w == "handgun" else 1.0
	main.noise_at(global_position, 30.0)
	var dmg: float = cfg.dmg * Game.dmg_mult[w]
	var hit_enemies := {}
	for i in cfg.pellets:
		var hit := _aim_ray(cfg.spread if cfg.pellets > 1 else 0.0)
		var c = hit.collider
		if c and c.has_method("take_hit"):
			var falloff := 1.0
			if w == "shotgun":
				falloff = clampf(1.4 - hit.position.distance_to(global_position) / 14.0, 0.25, 1.4)
			c.take_hit(dmg * falloff, hit.position, hit.dir, w)
			hit_enemies[c] = true
		else:
			main.spark(hit.position, hit.normal, Color(0.6, 0.55, 0.45))
	pitch.rotation.x += 0.02 if w == "handgun" else 0.07
	Game.changed.emit()


func do_knife() -> void:
	action = "knife"
	action_t = 0.35
	body.set_state("knife")
	Sfx.play("knife")
	var fwd := -body.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("hittable"):
		if not is_instance_valid(e):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() < 1.9 and fwd.dot(to.normalized()) > 0.3:
			e.take_hit(9.0, e.global_position + Vector3(0, 1.0, 0), fwd, "knife")


func try_kick() -> bool:
	var fwd := -body.global_transform.basis.z
	var target: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_kickable") and e.is_kickable():
			var to: Vector3 = e.global_position - global_position
			to.y = 0
			if to.length() < 2.6:
				target = e
				break
	if target == null:
		return false
	var to_t := target.global_position - global_position
	body.rotation.y = atan2(-to_t.x, -to_t.z)
	action = "kick"
	action_t = 0.5
	body.set_state("kick")
	Sfx.play("kick")
	shake = 0.6
	fwd = -body.global_transform.basis.z
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() < 3.0 and fwd.dot(to.normalized()) > -0.2 and e.has_method("kicked"):
			e.kicked(fwd)
	return true


func kickable_near() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_kickable") and e.is_kickable() and e.global_position.distance_to(global_position) < 2.6:
			return true
	return false


func take_damage(amount: float, from: Vector3, knockback := 0.0) -> void:
	if dead or invuln > 0 or not controls:
		return
	Game.hp -= amount
	invuln = 0.6
	shake = 1.2
	Sfx.play("hurt", -2, randf_range(0.9, 1.1))
	Sfx.play("flesh", -4)
	var away := global_position - from
	away.y = 0
	if knockback > 0 and away.length() > 0.01:
		knock = away.normalized() * knockback
	main.ui.hurt(amount)
	Game.changed.emit()
	if Game.hp <= 0:
		Game.hp = 0
		die()


func die() -> void:
	dead = true
	aiming = false
	laser.visible = false
	dot.visible = false
	body.set_state("dead")
	died.emit()


func set_controls(on: bool) -> void:
	controls = on
	if not on:
		_set_aim(false)
		laser.visible = false
		dot.visible = false
		velocity = Vector3.ZERO


func face(dir_y: float) -> void:
	yaw.rotation.y = dir_y
	body.rotation.y = dir_y
	pitch.rotation.x = -0.1
