class_name Models
## Material + mesh factory. Every visual in the game is created here.
## If a Blender-exported model exists at res://assets/models/<name>.glb it is used,
## otherwise a procedural low-poly stand-in is built from primitives.

const PSX := preload("res://shaders/psx.gdshader")

static var _mats := {}
static var _texs := {}
static var _meshes := {}


static func tex(kind: String) -> Texture2D:
	if kind == "none":
		return null
	if _texs.has(kind):
		return _texs[kind]
	var nz := FastNoiseLite.new()
	nz.seed = kind.hash() & 0xffff
	match kind:
		"stone":
			nz.noise_type = FastNoiseLite.TYPE_CELLULAR
			nz.frequency = 0.12
		"wood":
			nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
			nz.frequency = 0.03
			nz.fractal_octaves = 1
		"grass":
			nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			nz.frequency = 0.08
			nz.fractal_octaves = 4
		"cloth":
			nz.noise_type = FastNoiseLite.TYPE_VALUE
			nz.frequency = 0.5
		_:
			nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
			nz.frequency = 0.1
	var t := NoiseTexture2D.new()
	t.width = 64
	t.height = 64 if kind != "wood" else 16
	t.seamless = true
	t.noise = nz
	_texs[kind] = t
	return t


static func mat(color: Color, tex_kind := "noise", uv := 1.0, glow := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [color.to_html(), tex_kind, uv, glow.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = PSX
	m.set_shader_parameter("albedo", color)
	var t := tex(tex_kind)
	if t:
		m.set_shader_parameter("tex", t)
	else:
		m.set_shader_parameter("tex_strength", 0.0)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("emission", glow)
	m.set_shader_parameter("emission_energy", energy)
	_mats[key] = m
	return m


static func glow_mat(color: Color, energy := 2.0) -> ShaderMaterial:
	return mat(color, "none", 1.0, color, energy)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func mi(parent: Node, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = m
	node.position = pos
	node.rotation_degrees = rot
	parent.add_child(node)
	return node


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, tk := "noise") -> MeshInstance3D:
	return mi(parent, _box_mesh(size), pos, mat(color, tk), rot)


static func cyl(parent: Node, rt: float, rb: float, h: float, pos: Vector3, color: Color, seg := 8, rot := Vector3.ZERO, tk := "noise") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return mi(parent, m, pos, mat(color, tk), rot)


static func sphere(parent: Node, r: float, pos: Vector3, color: Color, seg := 8, m: Material = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return mi(parent, s, pos, m if m else mat(color), Vector3.ZERO)


static func collider(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0, layer := 1) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	parent.add_child(sb)
	return sb


static func solid(parent: Node, size: Vector3, pos: Vector3, color: Color, tk := "noise", rot_y := 0.0) -> StaticBody3D:
	var sb := collider(parent, size, pos, rot_y)
	box(sb, size, Vector3.ZERO, color, Vector3.ZERO, tk)
	return sb


static func glb(model_name: String) -> Node3D:
	var path := "res://assets/models/%s.glb" % model_name
	if ResourceLoader.exists(path):
		var ps = load(path)
		if ps is PackedScene:
			var inst: Node3D = ps.instantiate()
			_psx_convert(inst)
			return inst
	return null


## Swap imported StandardMaterial3Ds for the PSX shader so Blender models match the look.
static func _psx_convert(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		var mesh: Mesh = n.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				var tk := "cloth" if sm.roughness > 0.9 else "noise"
				if sm.emission_enabled:
					n.set_surface_override_material(i, glow_mat(sm.emission, maxf(1.0, sm.emission_energy_multiplier)))
				else:
					n.set_surface_override_material(i, mat(sm.albedo_color, tk))
	for c in n.get_children():
		_psx_convert(c)


# ------------------------------------------------------------------ props
## Returns a Node3D visual for a prop (glb if available, else procedural).
static func prop(model_name: String, seed_value := 0) -> Node3D:
	var g := glb(model_name)
	if g:
		return g
	var root := Node3D.new()
	root.name = model_name
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match model_name:
		"house":
			var wall: Color = [Color(0.42, 0.36, 0.28), Color(0.5, 0.45, 0.36), Color(0.35, 0.3, 0.25)][seed_value % 3]
			box(root, Vector3(8, 3.2, 6), Vector3(0, 1.6, 0), wall, Vector3.ZERO, "stone")
			for side in [-1, 1]:
				box(root, Vector3(8.6, 0.2, 3.9), Vector3(0, 4.2, side * 1.55), Color(0.25, 0.12, 0.08), Vector3(side * 33, 0, 0), "wood")
			box(root, Vector3(7.6, 1.8, 0.2), Vector3(0, 4.0, 2.9), wall.darkened(0.2), Vector3.ZERO, "stone")
			box(root, Vector3(1.4, 2.3, 0.1), Vector3(0, 1.15, 3.02), Color(0.22, 0.14, 0.08), Vector3.ZERO, "wood")
			for x in [-2.6, 2.6]:
				box(root, Vector3(1.1, 0.9, 0.08), Vector3(x, 1.9, 3.02), Color(0.05, 0.05, 0.04), Vector3.ZERO, "none")
				box(root, Vector3(1.3, 0.12, 0.2), Vector3(x, 1.4, 3.05), Color(0.25, 0.16, 0.1), Vector3.ZERO, "wood")
			box(root, Vector3(0.7, 1.6, 0.7), Vector3(2.5, 5.0, -1), Color(0.3, 0.28, 0.25), Vector3.ZERO, "stone")
		"tree":
			var h := rng.randf_range(7, 11)
			cyl(root, 0.15, 0.3, h * 0.4, Vector3(0, h * 0.2, 0), Color(0.2, 0.13, 0.08), 6, Vector3.ZERO, "wood")
			var c := Color(0.07, 0.13, 0.08).lerp(Color(0.1, 0.12, 0.06), rng.randf())
			for k in 3:
				var r := 2.3 - k * 0.6
				cyl(root, 0.0, r, h * 0.35, Vector3(0, h * (0.35 + k * 0.2), 0), c, 7)
		"deadtree":
			cyl(root, 0.1, 0.3, 6, Vector3(0, 3, 0), Color(0.15, 0.12, 0.1), 5, Vector3.ZERO, "wood")
			for k in 4:
				cyl(root, 0.02, 0.1, 2.2, Vector3(0, 3.5 + k * 0.6, 0), Color(0.15, 0.12, 0.1), 4, Vector3(rng.randf_range(35, 70), k * 90 + rng.randf_range(0, 40), 0), "wood")
		"tombstone":
			var grey := Color(0.35, 0.35, 0.37).darkened(rng.randf() * 0.3)
			if rng.randf() < 0.5:
				box(root, Vector3(0.7, 1.0, 0.18), Vector3(0, 0.5, 0), grey, Vector3(0, 0, rng.randf_range(-8, 8)), "stone")
				cyl(root, 0.35, 0.35, 0.18, Vector3(0, 1.0, 0), grey, 8, Vector3(90, 0, 0), "stone")
			else:
				box(root, Vector3(0.15, 1.5, 0.15), Vector3(0, 0.75, 0), grey, Vector3.ZERO, "stone")
				box(root, Vector3(0.8, 0.15, 0.15), Vector3(0, 1.1, 0), grey, Vector3.ZERO, "stone")
			box(root, Vector3(0.9, 0.1, 1.8), Vector3(0, 0.05, 1.0), Color(0.18, 0.14, 0.1), Vector3.ZERO, "grass")
		"crate":
			box(root, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0), Color(0.45, 0.32, 0.18), Vector3.ZERO, "wood")
			box(root, Vector3(0.95, 0.12, 0.95), Vector3(0, 0.45, 0), Color(0.3, 0.2, 0.1), Vector3.ZERO, "wood")
		"barrel":
			cyl(root, 0.38, 0.38, 1.1, Vector3(0, 0.55, 0), Color(0.4, 0.26, 0.14), 8, Vector3.ZERO, "wood")
			for y in [0.2, 0.9]:
				cyl(root, 0.4, 0.4, 0.07, Vector3(0, y, 0), Color(0.2, 0.2, 0.2), 8, Vector3.ZERO, "none")
		"fence":
			for x in [-1.5, 0, 1.5]:
				box(root, Vector3(0.14, 1.3, 0.14), Vector3(x, 0.65, 0), Color(0.3, 0.22, 0.13), Vector3.ZERO, "wood")
			for y in [0.5, 1.0]:
				box(root, Vector3(3.2, 0.1, 0.06), Vector3(0, y, 0), Color(0.33, 0.24, 0.14), Vector3(0, 0, rng.randf_range(-4, 4)), "wood")
		"car":
			box(root, Vector3(1.9, 0.7, 4.3), Vector3(0, 0.6, 0), Color(0.12, 0.14, 0.12), Vector3.ZERO, "noise")
			box(root, Vector3(1.7, 0.6, 2.2), Vector3(0, 1.25, 0.2), Color(0.1, 0.12, 0.1))
			box(root, Vector3(1.6, 0.45, 0.05), Vector3(0, 1.25, -0.92), Color(0.2, 0.25, 0.3), Vector3(-20, 0, 0), "none")
			for p in [Vector3(-0.9, 0.35, 1.4), Vector3(0.9, 0.35, 1.4), Vector3(-0.9, 0.35, -1.4), Vector3(0.9, 0.35, -1.4)]:
				cyl(root, 0.35, 0.35, 0.25, p, Color(0.05, 0.05, 0.05), 8, Vector3(0, 0, 90), "none")
			for x in [-0.6, 0.6]:
				box(root, Vector3(0.3, 0.15, 0.05), Vector3(x, 0.7, -2.16), Color(1, 0.9, 0.6), Vector3.ZERO, "none").material_override = glow_mat(Color(1, 0.9, 0.6), 3)
		"cart":
			box(root, Vector3(1.6, 0.5, 2.6), Vector3(0, 0.9, 0), Color(0.35, 0.25, 0.14), Vector3.ZERO, "wood")
			for x in [-0.9, 0.9]:
				cyl(root, 0.6, 0.6, 0.12, Vector3(x, 0.6, 0.3), Color(0.25, 0.18, 0.1), 10, Vector3(0, 0, 90), "wood")
			box(root, Vector3(0.12, 0.12, 2.2), Vector3(0.4, 0.8, -2.2), Color(0.3, 0.22, 0.12), Vector3(-10, 0, 0), "wood")
			box(root, Vector3(0.12, 0.12, 2.2), Vector3(-0.4, 0.8, -2.2), Color(0.3, 0.22, 0.12), Vector3(-10, 0, 0), "wood")
			box(root, Vector3(1.4, 0.6, 2.2), Vector3(0, 1.3, 0), Color(0.55, 0.48, 0.25), Vector3.ZERO, "grass")
		"well":
			cyl(root, 1.1, 1.1, 0.9, Vector3(0, 0.45, 0), Color(0.35, 0.34, 0.33), 10, Vector3.ZERO, "stone")
			cyl(root, 0.9, 0.9, 0.05, Vector3(0, 0.88, 0), Color(0.01, 0.01, 0.02), 10, Vector3.ZERO, "none")
			for x in [-1.0, 1.0]:
				box(root, Vector3(0.15, 2.0, 0.15), Vector3(x, 1.5, 0), Color(0.3, 0.2, 0.12), Vector3.ZERO, "wood")
			box(root, Vector3(2.6, 0.12, 1.4), Vector3(0, 2.6, 0), Color(0.25, 0.12, 0.08), Vector3(0, 0, 0), "wood")
		"bell":
			cyl(root, 0.35, 1.1, 1.6, Vector3(0, -0.8, 0), Color(0.45, 0.33, 0.14), 12, Vector3.ZERO, "noise")
			cyl(root, 1.15, 1.15, 0.12, Vector3(0, -1.6, 0), Color(0.4, 0.3, 0.12), 12, Vector3.ZERO, "noise")
			sphere(root, 0.36, Vector3(0, 0, 0), Color(0.45, 0.33, 0.14), 10)
			sphere(root, 0.18, Vector3(0, -1.5, 0), Color(0.2, 0.15, 0.1), 6)
		"cage":
			for i in 10:
				var a := TAU * i / 10.0
				box(root, Vector3(0.06, 2.4, 0.06), Vector3(cos(a) * 1.0, 1.2, sin(a) * 1.0), Color(0.2, 0.18, 0.16), Vector3.ZERO, "none")
			cyl(root, 1.05, 1.05, 0.1, Vector3(0, 2.4, 0), Color(0.2, 0.18, 0.16), 10, Vector3.ZERO, "none")
			cyl(root, 1.05, 1.05, 0.1, Vector3(0, 0.05, 0), Color(0.2, 0.18, 0.16), 10, Vector3.ZERO, "none")
		"helicopter":
			box(root, Vector3(2.2, 2.0, 5.0), Vector3(0, 1.4, 0), Color(0.18, 0.22, 0.18))
			box(root, Vector3(1.9, 1.0, 1.5), Vector3(0, 1.8, -2.7), Color(0.3, 0.4, 0.45), Vector3(-15, 0, 0), "none")
			box(root, Vector3(0.5, 0.6, 5.5), Vector3(0, 1.9, 5.0), Color(0.18, 0.22, 0.18))
			box(root, Vector3(0.1, 1.6, 0.6), Vector3(0.3, 2.4, 7.5), Color(0.18, 0.22, 0.18))
			box(root, Vector3(11, 0.05, 0.35), Vector3(0, 2.7, 0), Color(0.08, 0.08, 0.08), Vector3.ZERO, "none").name = "Rotor"
			for x in [-1.1, 1.1]:
				box(root, Vector3(0.12, 0.12, 4.2), Vector3(x, 0.1, 0), Color(0.1, 0.1, 0.1), Vector3.ZERO, "none")
		"altar":
			box(root, Vector3(3.2, 1.1, 1.3), Vector3(0, 0.55, 0), Color(0.4, 0.38, 0.36), Vector3.ZERO, "stone")
			box(root, Vector3(3.4, 0.1, 1.5), Vector3(0, 1.12, 0), Color(0.45, 0.1, 0.1), Vector3.ZERO, "cloth")
			for x in [-1.3, 1.3]:
				cyl(root, 0.05, 0.05, 0.4, Vector3(x, 1.35, 0), Color(0.9, 0.85, 0.7), 6, Vector3.ZERO, "none")
		"pew":
			box(root, Vector3(4.0, 0.12, 0.6), Vector3(0, 0.5, 0), Color(0.3, 0.18, 0.1), Vector3.ZERO, "wood")
			box(root, Vector3(4.0, 0.7, 0.1), Vector3(0, 0.85, 0.3), Color(0.28, 0.17, 0.1), Vector3.ZERO, "wood")
			for x in [-1.9, 1.9]:
				box(root, Vector3(0.1, 0.5, 0.6), Vector3(x, 0.25, 0), Color(0.26, 0.16, 0.1), Vector3.ZERO, "wood")
		"lantern":
			box(root, Vector3(0.25, 0.35, 0.25), Vector3(0, 0, 0), Color(0.1, 0.1, 0.1), Vector3.ZERO, "none")
			sphere(root, 0.1, Vector3.ZERO, Color.ORANGE, 6, glow_mat(Color(1.0, 0.6, 0.2), 4))
		"cross":
			box(root, Vector3(0.3, 4.0, 0.3), Vector3(0, 2, 0), Color(0.25, 0.15, 0.08), Vector3.ZERO, "wood")
			box(root, Vector3(2.0, 0.3, 0.3), Vector3(0, 3, 0), Color(0.25, 0.15, 0.08), Vector3.ZERO, "wood")
		"shard":
			var sm := glow_mat(Color(0.6, 0.9, 1.0), 3)
			var p := PrismMesh.new()
			p.size = Vector3(0.25, 0.5, 0.08)
			mi(root, p, Vector3.ZERO, sm)
			mi(root, p, Vector3(0, -0.2, 0), sm, Vector3(180, 40, 0))
		_:
			box(root, Vector3.ONE, Vector3(0, 0.5, 0), Color.MAGENTA)
	return root
