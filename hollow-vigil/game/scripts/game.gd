extends Node
## Global state: persistent loop data (survives restarts) and the current run's inventory.

signal changed
signal message(text: String, secs: float)

const SAVE_PATH := "user://hollow_vigil.cfg"

const WEAPONS := {
	"handgun": {"name": "Handgun", "mag": 10, "dmg": 10.0, "rate": 0.32, "pellets": 1, "spread": 0.004, "sound": "pistol", "ammo": "handgun"},
	"shotgun": {"name": "Shotgun", "mag": 6, "dmg": 7.0, "rate": 0.95, "pellets": 8, "spread": 0.06, "sound": "shotgun", "ammo": "shells"},
	"magnum": {"name": "Broken Choir .50", "mag": 5, "dmg": 70.0, "rate": 1.1, "pellets": 1, "spread": 0.002, "sound": "magnum", "ammo": "magnum"},
}

# ---- persistent
var loop := 1
var endings := {}          # ending id -> true
var best_time := 0.0
var runs_finished := 0

# ---- current run
var hp := 100.0
var max_hp := 100.0
var coins := 0
var weapons: Array[String] = ["handgun"]
var weapon := "handgun"
var mag := {"handgun": 10, "shotgun": 0, "magnum": 0}
var ammo := {"handgun": 30, "shells": 0, "magnum": 0}
var herbs := 1
var sprays := 0
var dmg_mult := {"handgun": 1.0, "shotgun": 1.0, "magnum": 1.0}
var mag_bonus := {"handgun": 0, "shotgun": 0, "magnum": 0}
var keys := {}
var flags := {}
var shards := 0
var run_time := 0.0
var kills := 0
var checkpoint := "A"
var _snapshot := {}


func _ready() -> void:
	load_persistent()


func _process(delta: float) -> void:
	if not get_tree().paused and flags.get("running", false):
		run_time += delta


# ------------------------------------------------------------------ persistence
func load_persistent() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		loop = int(cf.get_value("vigil", "loop", 1))
		endings = cf.get_value("vigil", "endings", {})
		best_time = float(cf.get_value("vigil", "best_time", 0.0))
		runs_finished = int(cf.get_value("vigil", "runs_finished", 0))


func save_persistent() -> void:
	var cf := ConfigFile.new()
	cf.set_value("vigil", "loop", loop)
	cf.set_value("vigil", "endings", endings)
	cf.set_value("vigil", "best_time", best_time)
	cf.set_value("vigil", "runs_finished", runs_finished)
	cf.save(SAVE_PATH)


func wipe_persistent() -> void:
	loop = 1
	endings = {}
	best_time = 0.0
	runs_finished = 0
	save_persistent()


# ------------------------------------------------------------------ run lifecycle
func new_run() -> void:
	hp = 100.0
	max_hp = 100.0
	coins = 0
	weapons = ["handgun"]
	weapon = "handgun"
	mag = {"handgun": 10, "shotgun": 0, "magnum": 0}
	ammo = {"handgun": 30, "shells": 0, "magnum": 0}
	herbs = 1
	sprays = 0
	dmg_mult = {"handgun": 1.0, "shotgun": 1.0, "magnum": 1.0}
	mag_bonus = {"handgun": 0, "shotgun": 0, "magnum": 0}
	keys = {}
	flags = {"running": true}
	shards = 0
	run_time = 0.0
	kills = 0
	checkpoint = "A"
	save_checkpoint("A")
	changed.emit()


func save_checkpoint(area: String) -> void:
	checkpoint = area
	_snapshot = {
		"hp": maxf(hp, 60.0), "coins": coins, "weapons": weapons.duplicate(), "weapon": weapon,
		"mag": mag.duplicate(), "ammo": ammo.duplicate(), "herbs": herbs, "sprays": sprays,
		"dmg_mult": dmg_mult.duplicate(), "mag_bonus": mag_bonus.duplicate(), "keys": keys.duplicate(),
		"flags": flags.duplicate(true), "shards": shards, "kills": kills,
	}


func restore_checkpoint() -> void:
	var s := _snapshot
	hp = s.hp
	coins = s.coins
	weapons.assign(s.weapons)
	weapon = s.weapon
	mag = s.mag.duplicate()
	ammo = s.ammo.duplicate()
	herbs = s.herbs
	sprays = s.sprays
	dmg_mult = s.dmg_mult.duplicate()
	mag_bonus = s.mag_bonus.duplicate()
	keys = s.keys.duplicate()
	flags = s.flags.duplicate(true)
	shards = s.shards
	kills = s.kills
	changed.emit()


# ------------------------------------------------------------------ helpers
func mag_size(w: String) -> int:
	return WEAPONS[w].mag + mag_bonus[w]


func ammo_type(w: String) -> String:
	return WEAPONS[w].ammo


func reserve(w: String) -> int:
	return ammo[ammo_type(w)]


func add_ammo(kind: String, amount: int) -> void:
	ammo[kind] = ammo.get(kind, 0) + amount
	changed.emit()


func give_weapon(w: String) -> void:
	if not weapons.has(w):
		weapons.append(w)
		mag[w] = mag_size(w)
	weapon = w
	changed.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	changed.emit()


func say(text: String, secs := 3.0) -> void:
	message.emit(text, secs)


func is_haunted() -> bool:
	return loop >= 2


func enemy_hp_mult() -> float:
	return 1.0 + 0.2 * float(mini(loop - 1, 3))


func format_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
