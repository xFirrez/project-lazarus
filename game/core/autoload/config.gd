# Config — persistent user settings (video, audio, input, gameplay) in a ConfigFile.
# Authority: local. Each instance may use a separate profile (--profile=<name>) so several
# local co-op instances on one machine keep separate settings and identities.
extends Node

signal setting_changed(section: StringName, key: StringName, value: Variant)

const DEFAULT_PATH: String = "user://settings.cfg"

const DEFAULTS: Dictionary = {
	"video":
	{
		"fullscreen": false,
		"vsync": true,
		"fps_cap": 0,
		"fov": 90.0,
		"viewmodel_fov": 68.0,
		"quality_preset": "high",
		"camera_bob_scale": 1.0,
		"screen_shake_scale": 1.0,
	},
	"audio":
	{
		"Master": 1.0,
		"Music": 0.8,
		"SFX": 1.0,
		"Weapons": 1.0,
		"Zombies": 1.0,
		"UI": 0.8,
		"VO": 1.0,
		"Ambience": 0.9,
	},
	"input":
	{
		"mouse_sensitivity": 1.0,
		"ads_sensitivity_multiplier": 0.8,
		"invert_y": false,
		"gamepad_sensitivity": 1.0,
		"toggle_ads": false,
		"toggle_crouch": true,
		"toggle_sprint": false,
	},
	"gameplay":
	{
		"player_name": "Survivor",
		"last_join_address": "127.0.0.1",
		"hud_scale": 1.0,
		"subtitles": true,
		"colorblind_mode": "off",
	},
}

var path: String = DEFAULT_PATH

var _values: Dictionary = {}
var _bindings: Dictionary = {}


func _init() -> void:
	reset_to_defaults()


func _ready() -> void:
	var profile: String = CommandLine.get_value("profile", "")
	if profile != "":
		path = "user://settings_%s.cfg" % profile
	load_settings()
	InputDefaults.apply(_bindings)


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_bindings = InputDefaults.ACTIONS.duplicate(true)


func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var sec: Dictionary = _values.get(String(section), {})
	return sec.get(String(key), fallback)


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	var sec_name: String = String(section)
	if not _values.has(sec_name):
		_values[sec_name] = {}
	var sec: Dictionary = _values[sec_name]
	sec[String(key)] = value
	setting_changed.emit(section, key, value)


func get_bindings(action: StringName) -> PackedStringArray:
	return PackedStringArray(_bindings.get(String(action), []))


func set_bindings(action: StringName, bindings: PackedStringArray) -> void:
	_bindings[String(action)] = Array(bindings)
	InputDefaults.apply(_bindings)
	setting_changed.emit(&"bindings", action, bindings)


func save_settings(to_path: String = "") -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	for section: String in _values:
		var sec: Dictionary = _values[section]
		for key: String in sec:
			cfg.set_value(section, key, sec[key])
	for action: String in _bindings:
		cfg.set_value("bindings", action, _bindings[action])
	return cfg.save(to_path if to_path != "" else path)


func load_settings(from_path: String = "") -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(from_path if from_path != "" else path)
	if err != OK:
		return err
	for section: String in cfg.get_sections():
		for key: String in cfg.get_section_keys(section):
			var value: Variant = cfg.get_value(section, key)
			if section == "bindings":
				_bindings[key] = value
			else:
				if not _values.has(section):
					_values[section] = {}
				var sec: Dictionary = _values[section]
				sec[key] = value
	return OK
