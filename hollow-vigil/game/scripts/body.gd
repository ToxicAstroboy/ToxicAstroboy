class_name Body
extends Node3D
## A jointed low-poly character. Limbs are pivots named Torso/Head/ArmL/ArmR/LegL/LegR
## (and Tent1..Tent4 / Eye for the beast). Animation is procedural.

var kind := "villager"
var parts := {}
var hand_r: Node3D
var phase := 0.0
var state := "idle"
var state_t := 0.0
var fall_dir := 1.0
var eye_mat: ShaderMaterial

const SKIN := Color(0.62, 0.48, 0.38)


func setup(k: String, seed_value := 0) -> Body:
	kind = k
	var model := Models.glb(k)
	if model:
		add_child(model)
		for n in ["Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Tent1", "Tent2", "Tent3", "Tent4", "Eye"]:
			var found := model.find_child(n, true, false)
			if found:
				parts[n] = found
		var eyes := model.find_child("Eyes", true, false)
		if eyes is MeshInstance3D:
			var col: Color = {"player": Color(0.05, 0.05, 0.05), "lena": Color(0.05, 0.05, 0.05), "aldric": Color(1, 0.8, 0.2), "merchant": Color(0.4, 0.6, 1.0), "beast": Color(1.0, 0.75, 0.1)}.get(k, Color(1.0, 0.12, 0.05))
			eye_mat = Models.glow_mat(col, 3.0).duplicate()
			eyes.material_override = eye_mat
			if k in ["villager", "zealot", "player", "lena"]:
				eye_mat.set_shader_parameter("emission_energy", 0.0)
	else:
		_build(seed_value)
	if kind == "brute":
		scale = Vector3.ONE * 1.45
	elif kind == "beast":
		scale = Vector3.ONE * 2.3
	if parts.has("ArmR"):
		hand_r = Node3D.new()
		hand_r.name = "HandR"
		parts.ArmR.add_child(hand_r)
		hand_r.position = Vector3(0, -0.66, -0.02)
	_add_held(seed_value)
	return self


func _pivot(pname: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = pname
	p.position = pos
	add_child(p)
	parts[pname] = p
	return p


func _humanoid(shirt: Color, pants: Color, skin: Color, head_scale := 1.0) -> void:
	var t := _pivot("Torso", Vector3(0, 0.95, 0))
	Models.box(t, Vector3(0.46, 0.56, 0.26), Vector3(0, 0.29, 0), shirt, Vector3.ZERO, "cloth")
	Models.box(t, Vector3(0.44, 0.12, 0.25), Vector3(0, 0.02, 0), pants.darkened(0.2), Vector3.ZERO, "cloth")
	var h := _pivot("Head", Vector3(0, 1.52, 0))
	Models.box(h, Vector3(0.1, 0.1, 0.1), Vector3(0, 0.03, 0), skin)
	Models.box(h, Vector3(0.25, 0.29, 0.27) * head_scale, Vector3(0, 0.19, 0), skin)
	for side in [-1, 1]:
		var a := _pivot("ArmL" if side < 0 else "ArmR", Vector3(side * 0.31, 1.45, 0))
		Models.box(a, Vector3(0.13, 0.36, 0.14), Vector3(0, -0.16, 0), shirt, Vector3.ZERO, "cloth")
		Models.box(a, Vector3(0.11, 0.3, 0.12), Vector3(0, -0.47, 0), shirt.darkened(0.1), Vector3.ZERO, "cloth")
		Models.box(a, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.66, 0), skin)
		var l := _pivot("LegL" if side < 0 else "LegR", Vector3(side * 0.12, 0.95, 0))
		Models.box(l, Vector3(0.17, 0.86, 0.19), Vector3(0, -0.44, 0), pants, Vector3.ZERO, "cloth")
		Models.box(l, Vector3(0.18, 0.1, 0.28), Vector3(0, -0.9, -0.04), Color(0.1, 0.08, 0.06))


func _eyes(color: Color, z := -0.14, y := 0.22, spacing := 0.06) -> void:
	eye_mat = Models.glow_mat(color, 3.0).duplicate()
	for side in [-1, 1]:
		Models.mi(parts.Head, _eye_mesh(), Vector3(side * spacing, y, z), eye_mat)


static func _eye_mesh() -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.045, 0.03, 0.02)
	return m


func _build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		"player":
			_humanoid(Color(0.32, 0.2, 0.12), Color(0.16, 0.2, 0.3), SKIN)
			Models.box(parts.Head, Vector3(0.27, 0.1, 0.29), Vector3(0, 0.33, 0.01), Color(0.12, 0.09, 0.06))
			Models.box(parts.Head, Vector3(0.27, 0.16, 0.06), Vector3(0, 0.24, 0.13), Color(0.12, 0.09, 0.06))
			Models.box(parts.Torso, Vector3(0.12, 0.5, 0.05), Vector3(0.1, 0.3, -0.14), Color(0.2, 0.2, 0.2))
			Models.box(parts.Torso, Vector3(0.3, 0.35, 0.12), Vector3(0, 0.3, 0.18), Color(0.2, 0.22, 0.14), Vector3.ZERO, "cloth")
			_eyes(Color(0.05, 0.05, 0.05), -0.14, 0.2, 0.06)
			eye_mat.set_shader_parameter("emission_energy", 0.0)
		"villager", "zealot":
			var shirts := [Color(0.4, 0.33, 0.22), Color(0.3, 0.3, 0.26), Color(0.35, 0.22, 0.18), Color(0.25, 0.28, 0.2), Color(0.45, 0.4, 0.3)]
			var shirt: Color = shirts[rng.randi() % shirts.size()]
			if kind == "zealot":
				shirt = Color(0.18, 0.08, 0.1)
			var skin := SKIN.darkened(rng.randf_range(0.05, 0.35)).lerp(Color(0.5, 0.52, 0.45), 0.3)
			_humanoid(shirt, Color(0.2, 0.17, 0.13).lightened(rng.randf() * 0.15), skin)
			if kind == "zealot":
				Models.cyl(parts.Head, 0.08, 0.2, 0.45, Vector3(0, 0.3, 0.02), shirt, 6)
				Models.cyl(parts.Torso, 0.26, 0.38, 0.95, Vector3(0, -0.4, 0), shirt, 8, Vector3.ZERO, "cloth")
				Models.box(parts.Head, Vector3(0.2, 0.2, 0.04), Vector3(0, 0.18, -0.15), Color(0.8, 0.78, 0.7))
			else:
				match rng.randi() % 4:
					0:
						Models.cyl(parts.Head, 0.16, 0.16, 0.06, Vector3(0, 0.36, 0), Color(0.2, 0.18, 0.15), 8)
						Models.box(parts.Head, Vector3(0.28, 0.02, 0.12), Vector3(0, 0.34, -0.17), Color(0.2, 0.18, 0.15))
					1:
						Models.box(parts.Head, Vector3(0.29, 0.3, 0.3), Vector3(0, 0.22, 0.03), Color(0.35, 0.1, 0.1), Vector3.ZERO, "cloth")
						Models.cyl(parts.Torso, 0.24, 0.34, 0.6, Vector3(0, -0.2, 0), Color(0.25, 0.2, 0.15), 8, Vector3.ZERO, "cloth")
					2:
						Models.box(parts.Head, Vector3(0.26, 0.12, 0.2), Vector3(0, 0.03, -0.06), Color(0.22, 0.2, 0.18))
					_:
						pass
		"brute":
			_humanoid(Color(0.3, 0.26, 0.2), Color(0.18, 0.15, 0.12), SKIN.darkened(0.2), 1.25)
			Models.box(parts.Head, Vector3(0.36, 0.42, 0.36), Vector3(0, 0.2, 0), Color(0.55, 0.47, 0.32), Vector3.ZERO, "cloth")
			Models.box(parts.Torso, Vector3(0.6, 0.7, 0.4), Vector3(0, 0.3, 0), Color(0.45, 0.4, 0.35), Vector3.ZERO, "cloth")
			Models.box(parts.Torso, Vector3(0.5, 0.8, 0.05), Vector3(0, 0.1, -0.22), Color(0.4, 0.15, 0.1), Vector3.ZERO, "cloth")
			_eyes(Color(1, 0.1, 0.05), -0.19, 0.25, 0.08)
		"aldric":
			_humanoid(Color(0.35, 0.05, 0.08), Color(0.2, 0.03, 0.05), Color(0.7, 0.66, 0.6))
			Models.cyl(parts.Torso, 0.26, 0.5, 1.05, Vector3(0, -0.45, 0), Color(0.35, 0.05, 0.08), 8, Vector3.ZERO, "cloth")
			Models.box(parts.Torso, Vector3(0.14, 0.9, 0.03), Vector3(0, 0.1, -0.14), Color(0.7, 0.55, 0.15))
			Models.cyl(parts.Head, 0.06, 0.16, 0.45, Vector3(0, 0.52, 0), Color(0.75, 0.7, 0.55), 4)
			Models.box(parts.Head, Vector3(0.2, 0.18, 0.08), Vector3(0, 0.02, -0.12), Color(0.85, 0.85, 0.85))
			_eyes(Color(1, 0.8, 0.2), -0.14, 0.2)
		"beast":
			_humanoid(Color(0.3, 0.05, 0.08), Color(0.2, 0.05, 0.05), Color(0.45, 0.35, 0.38))
			Models.cyl(parts.Torso, 0.3, 0.6, 1.1, Vector3(0, -0.45, 0), Color(0.3, 0.05, 0.08), 7, Vector3.ZERO, "cloth")
			Models.box(parts.Torso, Vector3(0.7, 0.4, 0.5), Vector3(0, 0.55, 0.12), Color(0.4, 0.3, 0.33), Vector3(20, 0, 0))
			for i in 4:
				var side := -1 if i % 2 == 0 else 1
				var t := _pivot("Tent%d" % (i + 1), Vector3(side * 0.25, 1.35 + (i / 2) * 0.12, 0.2))
				for s in 5:
					Models.box(t, Vector3(0.12, 0.3, 0.12) * (1.0 - s * 0.12), Vector3(0, -0.15 - s * 0.28, 0), Color(0.5, 0.2, 0.25).darkened(s * 0.08))
			var eye := _pivot("Eye", Vector3(0, 1.25, -0.16))
			eye_mat = Models.glow_mat(Color(1.0, 0.75, 0.1), 3.0).duplicate()
			Models.sphere(eye, 0.2, Vector3.ZERO, Color.WHITE, 10, eye_mat)
			Models.sphere(eye, 0.08, Vector3(0, 0, -0.17), Color.BLACK, 6, Models.mat(Color(0.02, 0, 0), "none"))
			Models.cyl(parts.Head, 0.02, 0.18, 0.6, Vector3(-0.12, 0.45, 0), Color(0.8, 0.75, 0.6), 4, Vector3(0, 0, 25))
			Models.cyl(parts.Head, 0.02, 0.18, 0.6, Vector3(0.12, 0.45, 0), Color(0.8, 0.75, 0.6), 4, Vector3(0, 0, -25))
		"lena":
			_humanoid(Color(0.8, 0.8, 0.76), Color(0.2, 0.2, 0.22), SKIN.lightened(0.1))
			Models.box(parts.Head, Vector3(0.28, 0.34, 0.2), Vector3(0, 0.23, 0.07), Color(0.1, 0.07, 0.05))
			Models.cyl(parts.Torso, 0.25, 0.32, 0.6, Vector3(0, -0.2, 0), Color(0.8, 0.8, 0.76), 8, Vector3.ZERO, "cloth")
			_eyes(Color(0.05, 0.05, 0.05))
			eye_mat.set_shader_parameter("emission_energy", 0.0)
		"merchant":
			_humanoid(Color(0.12, 0.14, 0.2), Color(0.1, 0.1, 0.12), SKIN.darkened(0.4))
			Models.cyl(parts.Torso, 0.28, 0.45, 1.0, Vector3(0, -0.4, 0), Color(0.12, 0.14, 0.2), 8, Vector3.ZERO, "cloth")
			Models.box(parts.Head, Vector3(0.34, 0.38, 0.36), Vector3(0, 0.22, 0.04), Color(0.1, 0.12, 0.16), Vector3.ZERO, "cloth")
			Models.box(parts.Torso, Vector3(0.5, 0.7, 0.35), Vector3(0, 0.3, 0.3), Color(0.25, 0.18, 0.1), Vector3.ZERO, "cloth")
			_eyes(Color(0.4, 0.6, 1.0), -0.16, 0.2)
	if kind in ["villager", "zealot"]:
		_eyes(Color(1.0, 0.12, 0.05), -0.14, 0.22)
		eye_mat.set_shader_parameter("emission_energy", 0.0)


func set_eye_glow(energy: float) -> void:
	if eye_mat:
		eye_mat.set_shader_parameter("emission_energy", energy)


func _add_held(seed_value: int) -> void:
	if hand_r == null:
		return
	var wood := Color(0.35, 0.24, 0.13)
	match kind:
		"villager":
			match seed_value % 5:
				0:
					Models.box(hand_r, Vector3(0.05, 0.05, 1.6), Vector3(0, 0, -0.4), wood, Vector3.ZERO, "wood")
					for x in [-0.08, 0, 0.08]:
						Models.box(hand_r, Vector3(0.02, 0.02, 0.3), Vector3(x, 0, -1.3), Color(0.4, 0.4, 0.42), Vector3.ZERO, "none")
				1:
					Models.box(hand_r, Vector3(0.05, 0.05, 0.6), Vector3(0, 0, -0.2), wood, Vector3.ZERO, "wood")
					Models.box(hand_r, Vector3(0.04, 0.2, 0.18), Vector3(0, 0.05, -0.5), Color(0.5, 0.5, 0.52), Vector3.ZERO, "none")
				2:
					Models.box(hand_r, Vector3(0.05, 0.05, 0.4), Vector3(0, 0, -0.15), wood, Vector3.ZERO, "wood")
					Models.box(hand_r, Vector3(0.03, 0.03, 0.4), Vector3(0, 0.12, -0.4), Color(0.5, 0.5, 0.52), Vector3(40, 0, 0), "none")
				_:
					pass
		"zealot":
			Models.box(hand_r, Vector3(0.05, 0.05, 0.7), Vector3(0, 0, -0.25), Color(0.15, 0.1, 0.08), Vector3.ZERO, "none")
			Models.box(hand_r, Vector3(0.05, 0.3, 0.05), Vector3(0, 0, -0.55), Color(0.5, 0.45, 0.2), Vector3.ZERO, "none")
		"brute":
			Models.box(hand_r, Vector3(0.05, 0.05, 0.4), Vector3(0, 0, -0.15), wood, Vector3.ZERO, "wood")
			Models.box(hand_r, Vector3(0.04, 0.35, 0.55), Vector3(0, 0.05, -0.6), Color(0.45, 0.43, 0.42), Vector3.ZERO, "none")
			Models.box(hand_r, Vector3(0.045, 0.1, 0.4), Vector3(0, -0.1, -0.6), Color(0.35, 0.05, 0.05), Vector3.ZERO, "none")
		"aldric":
			Models.box(hand_r, Vector3(0.05, 1.9, 0.05), Vector3(0, 0.1, 0), Color(0.5, 0.4, 0.15), Vector3.ZERO, "none")
			Models.sphere(hand_r, 0.12, Vector3(0, 1.1, 0), Color.PURPLE, 6, Models.glow_mat(Color(0.7, 0.2, 1.0), 3))


func set_state(s: String) -> void:
	if s != state:
		state = s
		state_t = 0.0


func _rot(pname: String, rx: float, rz := 0.0, ry := 0.0) -> void:
	if parts.has(pname):
		var p: Node3D = parts[pname]
		p.rotation = Vector3(rx, ry, rz)


func animate(delta: float, speed: float) -> void:
	state_t += delta
	phase += delta * (2.0 + speed * 2.4)
	var s := sin(phase)
	var sw := clampf(speed / 4.0, 0.0, 1.0)
	var breathe := sin(state_t * 2.0) * 0.03
	match state:
		"idle", "walk", "run", "shamble":
			var amp := 0.55 * sw + (0.25 if state == "run" else 0.0)
			_rot("LegL", s * amp)
			_rot("LegR", -s * amp)
			_rot("ArmL", -s * amp * 0.8 + (0.4 if state == "shamble" else 0.0), -0.08)
			_rot("ArmR", s * amp * 0.8 + (0.4 if state == "shamble" else 0.0), 0.08)
			_rot("Torso", -0.08 * sw - (0.15 if state == "run" else 0.0) + breathe, sin(phase * 0.5) * (0.08 if state == "shamble" else 0.0))
			_rot("Head", (0.15 if state == "shamble" else 0.0) + breathe, sin(state_t * 0.7) * 0.15 if state == "shamble" else 0.0)
		"aim":
			_rot("ArmR", -1.5, 0.05, 0.1)
			_rot("ArmL", -1.4, -0.35, -0.4)
			_rot("LegL", 0.15)
			_rot("LegR", -0.1)
			_rot("Torso", breathe * 0.3)
			_rot("Head", 0.0)
		"windup":
			_rot("ArmR", -2.6 - state_t * 0.4, 0.2)
			_rot("ArmL", -0.6, -0.2)
			_rot("Torso", 0.15)
		"strike":
			var k := clampf(state_t / 0.15, 0.0, 1.0)
			_rot("ArmR", lerpf(-2.8, -0.6, k), 0.1)
			_rot("ArmL", lerpf(-0.6, 0.2, k), -0.2)
			_rot("Torso", lerpf(0.15, -0.35, k))
		"stagger":
			_rot("Head", 0.6 + sin(state_t * 12) * 0.1)
			_rot("Torso", 0.35)
			_rot("ArmL", -0.2, -0.6)
			_rot("ArmR", -0.2, 0.6)
			_rot("LegL", -0.2)
			_rot("LegR", 0.25)
		"kick":
			var k := clampf(state_t / 0.35, 0.0, 1.0)
			_rot("LegR", -1.7 * sin(k * PI), 0.0)
			_rot("LegL", 0.2)
			_rot("Torso", 0.3 * sin(k * PI))
			_rot("ArmL", -0.5, -0.8)
			_rot("ArmR", -0.5, 0.8)
		"knife":
			var k := clampf(state_t / 0.25, 0.0, 1.0)
			_rot("ArmR", -1.4, 0.0, lerpf(1.2, -1.0, k))
			_rot("Torso", 0.0, 0.0)
		"cast":
			_rot("ArmL", -2.8 + sin(state_t * 8) * 0.1, -0.3)
			_rot("ArmR", -2.8 + cos(state_t * 8) * 0.1, 0.3)
			_rot("Head", 0.4)
			_rot("Torso", 0.25)
		"dead", "down":
			var k := clampf(state_t / 0.6, 0.0, 1.0)
			rotation.x = lerpf(0.0, -PI * 0.5 * fall_dir, k * k)
			position.y = lerpf(0.0, 0.15, k)
			_rot("ArmL", -2.5 * k, -0.4)
			_rot("ArmR", -2.2 * k, 0.4)
			_rot("LegL", 0.2 * k)
			_rot("LegR", -0.3 * k)
		"rise":
			var k := clampf(state_t / 1.2, 0.0, 1.0)
			rotation.x = lerpf(-PI * 0.5 * fall_dir, 0.0, k)
			position.y = lerpf(0.15, 0.0, k)
		"kneel":
			_rot("LegL", -1.2)
			_rot("LegR", 0.4)
			position.y = -0.45
			_rot("Torso", 0.4)
			_rot("Head", 0.5)
			_rot("ArmL", 0.0, -0.1)
			_rot("ArmR", 0.0, 0.1)
		"pray":
			_rot("LegL", -1.4)
			_rot("LegR", -1.4)
			position.y = -0.5
			_rot("Torso", 0.2)
			_rot("Head", -0.3)
			_rot("ArmL", -2.9, 0.3)
			_rot("ArmR", -2.9, -0.3)
	if state not in ["dead", "down", "rise", "kneel", "pray"]:
		rotation.x = 0.0
		position.y = 0.0
	for i in 4:
		var tn := "Tent%d" % (i + 1)
		if parts.has(tn):
			var fx := -1.0 if state in ["windup", "strike"] else 0.0
			_rot(tn, fx * (1.5 + i * 0.2) + sin(state_t * 3.0 + i) * 0.5, (i % 2 * 2 - 1) * (0.5 + sin(state_t * 2.0 + i * 1.3) * 0.3))
