extends Node
## Sound manager: pooled 2D one-shots, positional one-shots and two looping channels.

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _music_name := ""
var _amb_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_amb = AudioStreamPlayer.new()
	add_child(_music)
	add_child(_amb)
	_music.finished.connect(func(): if _music_name != "": _music.play())
	_amb.finished.connect(func(): if _amb_name != "": _amb.play())


func stream(sname: String) -> AudioStream:
	if not _cache.has(sname):
		var path := "res://assets/sounds/%s.wav" % sname
		_cache[sname] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sname]


func play(sname: String, db := 0.0, pitch := 1.0) -> void:
	var s := stream(sname)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return


func play_at(sname: String, pos: Vector3, parent: Node, db := 0.0, pitch := 1.0) -> void:
	var s := stream(sname)
	if s == null or parent == null or not parent.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 60.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func music(sname: String, db := -6.0) -> void:
	if sname == _music_name:
		return
	_music_name = sname
	_music.stop()
	if sname == "":
		return
	_music.stream = stream(sname)
	_music.volume_db = db
	_music.play()


func ambience(sname: String, db := -8.0) -> void:
	if sname == _amb_name:
		return
	_amb_name = sname
	_amb.stop()
	if sname == "":
		return
	_amb.stream = stream(sname)
	_amb.volume_db = db
	_amb.play()


func stop_all() -> void:
	music("")
	ambience("")
	for p in _pool:
		p.stop()
