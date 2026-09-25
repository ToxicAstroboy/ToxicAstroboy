class_name Breakable
extends StaticBody3D
## Crate or barrel that shatters when shot or knifed and may drop loot.

var main: Node
var loot := ""
var loot_amt := 0


static func make(m: Node, parent: Node, pos: Vector3, model: String, l := "", amt := 0) -> Breakable:
	var b := Breakable.new()
	b.main = m
	b.loot = l
	b.loot_amt = amt
	b.collision_layer = 8
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 1.0, 0.9)
	cs.shape = sh
	cs.position.y = 0.5
	b.add_child(cs)
	b.add_child(Models.prop(model))
	parent.add_child(b)
	b.global_position = pos
	b.rotation.y = randf() * TAU
	b.add_to_group("hittable")
	return b


func take_hit(_amount: float, _pos: Vector3, _dir: Vector3, _w: String) -> void:
	Sfx.play_at("kick", global_position, main.world, -4, 1.6)
	main.spark(global_position + Vector3(0, 0.5, 0), Vector3.UP, Color(0.45, 0.32, 0.18), 14)
	if loot != "":
		Pickup.make(main, main.world, global_position + Vector3(0, 0.1, 0), loot, loot_amt)
	elif randf() < 0.6:
		main.drop_loot(global_position, "crate")
	queue_free()
