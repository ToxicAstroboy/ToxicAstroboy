class_name Orb
extends Area3D
## Choir orb thrown by Father Aldric. Slightly homing; can be shot down.

var target: Node3D
var vel := Vector3.ZERO
var life := 6.0
var main: Node


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	add_child(cs)
	Models.sphere(self, 0.3, Vector3.ZERO, Color.PURPLE, 8, Models.glow_mat(Color(0.7, 0.2, 1.0), 4))
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.3, 1.0)
	l.omni_range = 5
	l.light_energy = 2
	add_child(l)
	add_to_group("hittable")
	Sfx.play_at("orb", global_position, main.world, 0)


func take_hit(_a: float, _p: Vector3, _d: Vector3, _w: String) -> void:
	main.spark(global_position, Vector3.UP, Color(0.7, 0.3, 1.0), 10)
	queue_free()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0 or target == null or not is_instance_valid(target):
		queue_free()
		return
	var want: Vector3 = (target.global_position + Vector3(0, 1.2, 0) - global_position).normalized() * 9.0
	vel = vel.lerp(want, 1.2 * delta)
	global_position += vel * delta
	if global_position.distance_to(target.global_position + Vector3(0, 1.0, 0)) < 0.9:
		target.take_damage(18, global_position, 5)
		queue_free()
