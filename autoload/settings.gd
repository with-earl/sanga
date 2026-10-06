extends Node
## Player settings: one volume for sound effects and one for music (each from 0 to 1, in steps of
## a quarter: 0%, 25%, 50%, 75% or 100%), whether the phone vibrates, and whether the content
## warning was already shown.
##
## Each volume drives its own audio bus ("Sound" and "Music"), created here if the project does
## not define them. Anything that plays sound effects should use the "Sound" bus, and anything
## that plays music or ambience the "Music" bus. Values are saved between sessions.

const SETTINGS_PATH := "user://settings.cfg"
const SOUND_BUS := &"Sound"
const MUSIC_BUS := &"Music"
const DEFAULT_VOLUME := 0.75
## Volumes move in these steps.
const VOLUME_STEP := 0.25

## Short buzzes for taps and moments in the story, in milliseconds.
const HAPTIC_LIGHT := 12
const HAPTIC_MEDIUM := 28

var sound_volume := DEFAULT_VOLUME
var music_volume := DEFAULT_VOLUME
var vibration := true
var content_warning_seen := false


func _ready() -> void:
	_ensure_bus(SOUND_BUS)
	_ensure_bus(MUSIC_BUS)
	load_settings()


## A short buzz on phones, unless the player turned vibration off.
func vibrate(milliseconds: int) -> void:
	if vibration and can_vibrate():
		Input.vibrate_handheld(milliseconds)


## Only the installed Android and iOS apps can vibrate. A browser cannot (iPhone Safari has no
## vibration at all), so the web build has no vibration and no switch for it.
func can_vibrate() -> bool:
	return (OS.has_feature("android") or OS.has_feature("ios")) and not OS.has_feature("web")


func set_vibration(enabled: bool) -> void:
	vibration = enabled
	save()


## The nearest step to `value`, from 0 to 1.
func snap_volume(value: float) -> float:
	return clampf(snappedf(value, VOLUME_STEP), 0.0, 1.0)


func set_sound_volume(value: float) -> void:
	sound_volume = snap_volume(value)
	_apply_volume(SOUND_BUS, sound_volume)


func set_music_volume(value: float) -> void:
	music_volume = snap_volume(value)
	_apply_volume(MUSIC_BUS, music_volume)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound", sound_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("device", "vibration", vibration)
	config.set_value("device", "content_warning_seen", content_warning_seen)
	config.save(SETTINGS_PATH)


## Reads the saved volumes. Missing or invalid values fall back to the default.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		set_sound_volume(DEFAULT_VOLUME)
		set_music_volume(DEFAULT_VOLUME)
		return
	set_sound_volume(_read_volume(config, "sound"))
	set_music_volume(_read_volume(config, "music"))
	vibration = config.get_value("device", "vibration", true) == true
	content_warning_seen = config.get_value("device", "content_warning_seen", false) == true


func _read_volume(config: ConfigFile, key: String) -> float:
	var value: Variant = config.get_value("audio", key, DEFAULT_VOLUME)
	if value is float or value is int:
		return clampf(float(value), 0.0, 1.0)
	return DEFAULT_VOLUME


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _apply_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, -80.0 if linear <= 0.001 else linear_to_db(linear))
