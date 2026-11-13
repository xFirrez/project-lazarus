# VesperMenuBackdrop — the animated 3D main-menu background (DEVELOPMENT_PLAN Step 15 scope 2): the
# real Arrival Station zone (Z01, the gondola dock) and the map-wide night-storm art (VesperArt: sky,
# aurora, mountain ring, cloud sea, storm gusts, searchlights) with a slow camera that drifts
# outside the station, past the gondola cabin hanging in its bay and the cable vanishing into the
# snow. No gameplay systems run (no Match): barricades / doors / machines are inert scenery.
# Authority: local presentation (menu only).
extends Node3D

const ZONE_SCENE: String = "res://maps/vesper_peak/zones/Z01_arrival_station.tscn"
# Camera path: two framings blended slowly (dock interior -> the cable into the storm).
const CAM_A: Vector3 = Vector3(-17.0, 3.2, -25.0)
const LOOK_A: Vector3 = Vector3(-3.0, 2.2, -13.0)
const CAM_B: Vector3 = Vector3(-11.0, 2.0, -28.5)
const LOOK_B: Vector3 = Vector3(-1.0, 3.0, -12.0)

var camera: Camera3D = null
var art: VesperArt = null

var _t: float = 0.0


func _ready() -> void:
	name = "MenuBackdrop"
	art = VesperArt.new()
	art.build(self)
	var zone: Node = (load(ZONE_SCENE) as PackedScene).instantiate()
	add_child(zone)
	art.finish(self)
	camera = Camera3D.new()
	camera.name = "MenuCamera"
	camera.fov = 62.0
	camera.far = 600.0
	add_child(camera)
	camera.make_current()
	art.atmosphere.forced_zone = &"Z06"  # exterior storm grading
	# Blowing snow between the camera and the station.
	add_child(AtmosFx.emitter(AtmosFx.Kind.SNOW_DRIFT, Vector3(-9, 4, -22), Vector3(14, 5, 10), Vector3(1, -0.4, 0.3)))
	_update_camera()


func _process(delta: float) -> void:
	_t += delta
	_update_camera()
	# An occasional distant gust keeps the storm alive behind the menu.
	if art.storm != null and fmod(_t, 17.0) < delta:
		art.storm.force_gust()


func _update_camera() -> void:
	var k: float = 0.5 - 0.5 * cos(_t * TAU / 46.0)
	var sway: Vector3 = Vector3(sin(_t * 0.31) * 0.08, sin(_t * 0.47) * 0.05, 0.0)
	camera.position = CAM_A.lerp(CAM_B, k) + sway
	camera.look_at(LOOK_A.lerp(LOOK_B, k), Vector3.UP)
