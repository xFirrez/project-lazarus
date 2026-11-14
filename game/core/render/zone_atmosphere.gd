# ZoneAtmosphere — local per-zone colour grading and fog (Step 13, VESPER_PEAK §8.1 / §8.3): finds
# the zone the active camera is in (the map's ZoneVolumes), blends the WorldEnvironment toward that
# zone's AtmosphereProfile over ~1.5 s, scales the moon and the camera snow, and folds in the
# special-round storm (SpecialRoundDirector publishes `storm_u` as Environment meta once this
# presenter claims the fog with `atmosphere_presenter`) and the storm gusts (StormSystem).
# Authority: local presentation on every peer (no shared state).
class_name ZoneAtmosphere
extends Node

signal sky_visibility_changed(visible: bool)

const STORM_FOG_SCALE: float = 1.8
const STORM_COLOR: Color = Color(0.35, 0.75, 0.5)

@export var blend_time: float = 1.5

var env: Environment = null
var moon: DirectionalLight3D = null
var storm: StormSystem = null
var profiles: Dictionary = {}  # StringName zone -> AtmosphereProfile
var default_profile: AtmosphereProfile = null
var current: AtmosphereProfile = AtmosphereProfile.new()
var current_zone: StringName = &""
var forced_zone: StringName = &""  # debug / screenshots: pin a profile
var exposure_scale: float = 1.0  # map presenters dip it (energy pulses)
## False while the blended profile is underground (`sky` < 0.5): the background is solid rock
## colour; map presenters listen to `sky_visibility_changed` to hide their distant backdrop.
var sky_visible: bool = true

var _volumes: Array[ZoneVolume] = []
var _moon_energy: float = 1.0
var _snow: Array[Node] = []
var _probe_timer: float = 0.0
var _probe: Vector3 = Vector3.ZERO


func setup(map_root: Node, environment: Environment, moon_light: DirectionalLight3D) -> void:
	env = environment
	moon = moon_light
	if moon != null:
		_moon_energy = moon.light_energy
	for v: Node in map_root.find_children("*", "ZoneVolume", true, false):
		_volumes.append(v as ZoneVolume)
	if env != null:
		env.set_meta(&"atmosphere_presenter", true)
	var start: AtmosphereProfile = default_profile if default_profile != null else AtmosphereProfile.new()
	current.copy_from(start)


func profile_for(zone: StringName) -> AtmosphereProfile:
	return profiles.get(zone, default_profile) as AtmosphereProfile


func zone_at(p: Vector3) -> StringName:
	for v: ZoneVolume in _volumes:
		if is_instance_valid(v) and v.contains(p):
			return v.zone
	return &""


# Jumps straight to a zone's look (screenshots, teleports).
func snap_to(zone: StringName) -> void:
	var p: AtmosphereProfile = profile_for(zone)
	if p != null:
		current.copy_from(p)
		current_zone = zone
	_apply()


func _process(delta: float) -> void:
	if env == null:
		return
	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.25
		var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
		if cam != null:
			_probe = cam.global_position
			var z: StringName = forced_zone if forced_zone != &"" else zone_at(_probe)
			if z != &"":
				current_zone = z
		if _snow.is_empty() or not is_instance_valid(_snow[0]):
			_snow = get_tree().root.find_children("*", "CameraSnow", true, false)
	var target: AtmosphereProfile = profile_for(current_zone)
	if target != null:
		current.blend_toward(target, clampf(delta / maxf(blend_time, 0.01) * 3.0, 0.0, 1.0))
	_apply()


func _apply() -> void:
	if env == null:
		return
	var u: float = float(env.get_meta(&"storm_u", 0.0))
	var gust: float = storm.gust if storm != null else 0.0
	var outdoor: float = clampf(current.snow, 0.0, 1.0)
	env.fog_density = (
		lerpf(current.fog_density, current.fog_density * STORM_FOG_SCALE, u) * (1.0 + 0.5 * gust * outdoor)
	)
	env.fog_light_color = current.fog_color.lerp(STORM_COLOR, u * 0.6)
	env.ambient_light_color = current.ambient_color
	env.ambient_light_energy = current.ambient_energy
	env.adjustment_brightness = current.brightness
	env.adjustment_contrast = current.contrast
	env.adjustment_saturation = current.saturation
	env.tonemap_exposure = current.exposure * exposure_scale
	env.volumetric_fog_density = current.vol_fog_density * (1.0 + 0.6 * gust * outdoor)
	env.volumetric_fog_albedo = current.vol_fog_albedo
	env.volumetric_fog_emission = current.vol_fog_emission
	var show_sky: bool = current.sky >= 0.5
	if show_sky != sky_visible:
		sky_visible = show_sky
		env.background_mode = Environment.BG_SKY if show_sky else Environment.BG_COLOR
		sky_visibility_changed.emit(show_sky)
	if not show_sky:
		env.background_color = (current.fog_color * 0.35).lerp(Color(0.02, 0.02, 0.025), 0.5)
	if moon != null:
		moon.light_energy = _moon_energy * current.moon_energy
		moon.visible = current.moon_energy > 0.01
	for s: Node in _snow:
		if is_instance_valid(s):
			(s as CameraSnow).intensity = current.snow * (1.0 + 0.8 * gust)
