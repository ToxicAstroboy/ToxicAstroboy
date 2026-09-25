class_name Interactable
extends Node3D
## Something the player can use with [E]. `action` is called with the player.

var prompt := "Examine"
var action: Callable
var radius := 2.2
var enabled := true
var once := false


static func make(parent: Node, pos: Vector3, text: String, cb: Callable, r := 2.2, one_shot := false) -> Interactable:
	var it := Interactable.new()
	it.prompt = text
	it.action = cb
	it.radius = r
	it.once = one_shot
	parent.add_child(it)
	it.global_position = pos
	it.add_to_group("interact")
	return it


func use(p: Node) -> void:
	if not enabled:
		return
	if once:
		enabled = false
	if action.call(p) == true:
		enabled = false
