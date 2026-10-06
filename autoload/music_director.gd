extends Node
## Background music: each scene has its own looping track, and moving between scenes crossfades
## from one to the next. Scenes that share a track (the boot and main screens) keep it playing
## without a restart. The music plays on the Music bus, so the Music volume in Settings controls
## it.
##
## The tracks are made by tools/compose_music.py and live in assets/music.

const CROSSFADE_SECONDS := 2.0
## Quieter than full scale, so the music sits under the dialogue and sound effects.
const VOLUME_DB := -6.0
const SILENT_DB := -60.0

## Scene to track. A scene not listed here fades the music out.
const TRACKS := {
	"res://scenes/boot.tscn": "res://assets/music/menu.wav",
	"res://scenes/main_menu.tscn": "res://assets/music/menu.wav",
	"res://scenes/public_market.tscn": "res://assets/music/market.wav",
	"res://scenes/church_nave.tscn": "res://assets/music/church.wav",
	"res://scenes/confessional.tscn": "res://assets/music/confessional.wav",
	"res://scenes/apartment_room.tscn": "res://assets/music/apartment.wav",
	"res://scenes/timeline_reveal.tscn": "res://assets/music/reveal.wav",
}

## Two players, so one track can fade out while the next fades in.
var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _track := ""
var _tweens: Array[Tween] = [null, null]


func _ready() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.MUSIC_BUS
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	_sync_with_current_scene.call_deferred()


## The first scene is added before this node is ready, so check it once at startup.
func _sync_with_current_scene() -> void:
	var current := get_tree().current_scene
	if current != null:
		play_for_scene(current.scene_file_path)


func _on_node_added(node: Node) -> void:
	if node.get_parent() == get_tree().root and node != self and node.scene_file_path != "":
		play_for_scene(node.scene_file_path)


## Crossfades to the track for this scene, or out to silence if it has none.
func play_for_scene(scene_path: String) -> void:
	play(TRACKS.get(scene_path, ""))


## The path of the track playing now, or "" when the music is silent.
func current_track() -> String:
	return _track


## Crossfades to `track`, a path to a looping audio file, or out to silence with "".
func play(track: String) -> void:
	if track == _track:
		return
	_track = track
	_fade(_current, SILENT_DB, true)
	if track == "" or not ResourceLoader.exists(track):
		return
	_current = 1 - _current
	var player := _players[_current]
	player.stream = _looping(load(track))
	player.volume_db = SILENT_DB
	player.play()
	_fade(_current, VOLUME_DB, false)


## WAV files are imported without a loop, so the loop is set here: the whole file, end to start.
func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", true)
	return stream


func _fade(index: int, volume_db: float, stop_after: bool) -> void:
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	var player := _players[index]
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "volume_db", volume_db, CROSSFADE_SECONDS)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween
