class_name Pickup
extends Node3D
## Floating item collected by walking into it.

var kind := "coins"
var amount := 0
var main: Node
var t := 0.0
var vis: Node3D
var life := -1.0


static func make(m: Node, parent: Node, pos: Vector3, k: String, amt := 0) -> Pickup:
	var p := Pickup.new()
	p.kind = k
	p.amount = amt
	p.main = m
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	vis = Node3D.new()
	add_child(vis)
	match kind:
		"coins":
			for i in 3:
				Models.cyl(vis, 0.08, 0.08, 0.02, Vector3(i * 0.03, 0.02 + i * 0.025, 0), Color(0.9, 0.75, 0.2), 8, Vector3.ZERO, "none").material_override = Models.glow_mat(Color(0.9, 0.7, 0.2), 1.2)
		"handgun":
			Models.box(vis, Vector3(0.22, 0.14, 0.14), Vector3.ZERO, Color(0.3, 0.35, 0.2), Vector3.ZERO, "none").material_override = Models.glow_mat(Color(0.35, 0.4, 0.25), 0.8)
		"shells":
			Models.box(vis, Vector3(0.24, 0.14, 0.14), Vector3.ZERO, Color(0.6, 0.1, 0.1), Vector3.ZERO, "none").material_override = Models.glow_mat(Color(0.6, 0.12, 0.1), 0.8)
		"magnum":
			Models.box(vis, Vector3(0.18, 0.12, 0.12), Vector3.ZERO, Color(0.5, 0.5, 0.6), Vector3.ZERO, "none").material_override = Models.glow_mat(Color(0.6, 0.6, 0.7), 0.8)
		"herb":
			for i in 3:
				Models.box(vis, Vector3(0.05, 0.25, 0.12), Vector3(0, 0.1, 0), Color(0.2, 0.7, 0.2), Vector3(0, i * 60, 20), "none").material_override = Models.glow_mat(Color(0.2, 0.7, 0.2), 1.0)
		"spray":
			Models.cyl(vis, 0.06, 0.06, 0.25, Vector3.ZERO, Color(0.8, 0.8, 0.85), 6, Vector3.ZERO, "none").material_override = Models.glow_mat(Color(0.7, 0.9, 1.0), 0.8)
		"shard":
			vis.add_child(Models.prop("shard"))
			var l := OmniLight3D.new()
			l.light_color = Color(0.6, 0.9, 1.0)
			l.omni_range = 4
			l.light_energy = 1.2
			add_child(l)


func _process(delta: float) -> void:
	t += delta
	vis.rotation.y += delta * 2.0
	vis.position.y = 0.35 + sin(t * 3.0) * 0.06
	if life > 0:
		life -= delta
		if life <= 0:
			queue_free()
			return
	var p = main.player if main else null
	if p and is_instance_valid(p) and not p.dead and p.global_position.distance_to(global_position) < 1.3:
		collect()


func collect() -> void:
	match kind:
		"coins":
			Game.coins += amount
			Game.say("+%d crowns" % amount, 1.5)
			Sfx.play("coins")
		"handgun", "shells", "magnum":
			Game.add_ammo(kind, amount)
			Game.say("Picked up %s ammo (%d)" % [{"handgun": "handgun", "shells": "shotgun", "magnum": "magnum"}[kind], amount], 1.5)
			Sfx.play("pickup")
		"herb":
			Game.herbs += 1
			Game.say("Picked up a green herb  [H] to use", 2.0)
			Sfx.play("pickup")
		"spray":
			Game.sprays += 1
			Game.say("Picked up first aid spray", 2.0)
			Sfx.play("pickup")
		"shard":
			Game.shards += 1
			Game.say("A BELL SHARD... it hums in your hand. (%d/5)" % Game.shards, 4.0)
			Sfx.play("bell_high", -4, 1.5)
	Game.changed.emit()
	queue_free()
