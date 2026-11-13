# AtmosphereProfile — one zone's look (Step 13, VESPER_PEAK §8.1): fog, ambient, colour grading,
# volumetric fog, moonlight share and camera-snow amount. ZoneAtmosphere blends between profiles
# as the local camera moves between zones. Data lives in the map's art resources.
# Authority: data (local presentation).
class_name AtmosphereProfile
extends Resource

const FIELDS: Array[StringName] = [
	&"fog_color",
	&"fog_density",
	&"ambient_color",
	&"ambient_energy",
	&"brightness",
	&"contrast",
	&"saturation",
	&"vol_fog_density",
	&"vol_fog_albedo",
	&"vol_fog_emission",
	&"moon_energy",
	&"snow",
	&"exposure",
]

@export var fog_color: Color = Color(0.16, 0.22, 0.3)
@export var fog_density: float = 0.006
@export var ambient_color: Color = Color(0.22, 0.3, 0.42)
@export var ambient_energy: float = 0.7
@export var brightness: float = 1.0
@export var contrast: float = 1.08
@export var saturation: float = 0.88
@export var vol_fog_density: float = 0.02
@export var vol_fog_albedo: Color = Color(0.55, 0.65, 0.8)
@export var vol_fog_emission: Color = Color(0.012, 0.02, 0.035)
@export var moon_energy: float = 1.0  # share of the moon light's authored energy
@export var snow: float = 1.0  # camera-snow intensity (0 = none underground)
@export var exposure: float = 1.25
@export_multiline var note: String = ""


# Moves every field of `self` toward `target` by fraction `t` (0..1).
func blend_toward(target: AtmosphereProfile, t: float) -> void:
	for f: StringName in FIELDS:
		var a: Variant = get(f)
		var b: Variant = target.get(f)
		if a is Color:
			set(f, (a as Color).lerp(b as Color, t))
		else:
			set(f, lerpf(float(a), float(b), t))


func copy_from(other: AtmosphereProfile) -> void:
	for f: StringName in FIELDS:
		set(f, other.get(f))
