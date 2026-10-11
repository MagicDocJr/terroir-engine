# Background music (game/assets3d/music, gitignored; made with Suno, prompts in docs/music.md). Tracks are grouped by
# mood from the start of their file name: theme_* (theme_title_* on the title and pre-game screens, theme_main_* for the
# intro), spring_*, summer_*, autumn_*,
# winter_* (the season on the game's calendar), tasting_* (Tasting practice, the Wine Fair, the Cellar book).
# A track plays once, then a quiet gap of 25–70 s, then another track of the current mood (never the same one twice
# in a row), the way open-world games pace their music, so a handful of 3–4 minute tracks never wears thin. A change of
# mood fades the playing track out over a few seconds. The narrator's voice ducks the music. N toggles it; the volume
# and on/off are kept in user://settings.cfg. With no files it is silent.
extends Node

const A := preload("res://src/view3d/assets3d.gd")
const MOODS := ["theme", "spring", "summer", "autumn", "winter", "tasting"]
const GAP := Vector2(25.0, 70.0)          # s of quiet between tracks
const FADE := 3.0

var enabled := true
var volume_db := -14.0
var mood := ""
var prefer := ""                          # a file-name start to prefer within the mood (set_mood)
var tracks := {}                          # mood -> [path]
var player: AudioStreamPlayer
var last := ""
var gap_left := 0.0
var fading_out := false
var duck_players: Array = []              # AudioStreamPlayers that duck the music while they play (the narrator)
var level := 0.0                          # 0..1 fade level


func _ready() -> void:
	_load_settings()
	player = AudioStreamPlayer.new()
	player.volume_db = -80.0
	player.finished.connect(_on_finished)
	add_child(player)
	scan()


## Finds the tracks (call again after adding files).
func scan() -> void:
	tracks = {}
	var dir := A.path("music")
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		if not ext in ["mp3", "ogg", "wav"]:
			continue
		var m := f.get_slice("_", 0).get_basename().to_lower()
		if m in MOODS:
			if not tracks.has(m): tracks[m] = []
			(tracks[m] as Array).append(dir.path_join(f))


func has_music() -> bool:
	return not tracks.is_empty()


## Sets the mood; the music follows (fading out what plays if the mood changed). prefer narrows the choice to tracks
## whose file name starts with it when there are any (theme_title on the title screens, theme_main for the intro).
func set_mood(m: String, pref := "") -> void:
	var switch := m != mood or (pref != "" and pref != prefer and not last.get_file().begins_with(pref))
	prefer = pref
	if not switch:
		return
	mood = m
	if player.playing:
		fading_out = true
	else:
		gap_left = 1.5                # start soon after entering a new mood


func toggle() -> bool:
	enabled = not enabled
	_save_settings()
	if not enabled: fading_out = player.playing
	else: gap_left = 0.5
	return enabled


func _process(delta: float) -> void:
	var duck := false
	for p in duck_players:
		if is_instance_valid(p) and (p as AudioStreamPlayer).playing: duck = true
	if fading_out:
		level = maxf(0.0, level - delta / FADE)
		if level <= 0.0:
			fading_out = false
			player.stop()
			gap_left = 1.0
	elif player.playing:
		level = minf(1.0, level + delta / FADE)
	elif enabled and mood != "" and tracks.has(mood):
		gap_left -= delta
		if gap_left <= 0.0:
			_play_next()
	var target := volume_db + (-11.0 if duck else 0.0)
	var db := linear_to_db(maxf(level, 0.0001)) + target
	player.volume_db = lerpf(player.volume_db, db, clampf(delta * 3.0, 0.0, 1.0)) if player.playing else -80.0


func _play_next() -> void:
	var list: Array = tracks[mood]
	if prefer != "":
		var pl := list.filter(func(p): return String(p).get_file().begins_with(prefer))
		if not pl.is_empty(): list = pl
	var choices := list.filter(func(p): return p != last) if list.size() > 1 else list
	var path: String = choices[randi() % choices.size()]
	var st = _stream(path)
	if st == null:
		gap_left = GAP.x
		return
	last = path
	player.stream = st
	level = 0.0
	player.play()


func _on_finished() -> void:
	gap_left = randf_range(GAP.x, GAP.y)


func _stream(path: String) -> Variant:
	match path.get_extension().to_lower():
		"mp3":
			var m := AudioStreamMP3.new(); m.data = FileAccess.get_file_as_bytes(path); return m
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null


func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		enabled = bool(cf.get_value("music", "enabled", true))
		volume_db = float(cf.get_value("music", "volume_db", -14.0))


func _save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("music", "enabled", enabled)
	cf.set_value("music", "volume_db", volume_db)
	cf.save("user://settings.cfg")
