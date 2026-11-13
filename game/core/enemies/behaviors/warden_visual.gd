# WardenVisual — the Warden's armor presentation on every peer (DEVELOPMENT_PLAN Step 12B; greybox+,
# authored model in Step 13): three dark reactor-steel plates on chest and shoulders (bone
# attachments on the scaled zombie rig), the vesperite core on its back (dim behind its housing,
# blazing and lit once every plate is broken) and a telegraph glow while an attack winds up.
# Reads the actor's replicated metadata (`warden_plates`, `warden_phase`) and flags.
# Authority: local presentation.
class_name WardenVisual
extends Node3D

const PLATE_SPECS: Array = [
	[&"Chest", Vector3(0, 0.05, 0.16), Vector3(0.42, 0.36, 0.08)],
	[&"LeftUpperArm", Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.2)],
	[&"RightUpperArm", Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.2)],
]

var plates: Array[MeshInstance3D] = []
var core: MeshInstance3D = null
var core_light: OmniLight3D = null
var warn_light: OmniLight3D = null
var _shown_plates: int = -1
var _t: float = 0.0
var _core_mat: StandardMaterial3D = null


func _ready() -> void:
	var v: ZombieVisual = get_meta(&"visual") as ZombieVisual
	if v == null or v.model == null or v.model.skeleton == null:
		return
	var sk: Skeleton3D = v.model.skeleton
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color(0.2, 0.21, 0.23)
	steel.metallic = 0.85
	steel.roughness = 0.45
	for spec: Array in PLATE_SPECS:
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.bone_name = spec[0]
		sk.add_child(att)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = spec[2]
		mi.mesh = bm
		mi.position = spec[1]
		mi.material_override = steel
		att.add_child(mi)
		plates.append(mi)
	var back: BoneAttachment3D = BoneAttachment3D.new()
	back.bone_name = &"Chest"
	sk.add_child(back)
	core = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	core.mesh = sm
	core.position = Vector3(0, 0.05, -0.17)
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.25, 0.9, 0.4)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.3, 1.0, 0.45)
	_core_mat.emission_energy_multiplier = 0.3
	core.material_override = _core_mat
	back.add_child(core)
	core_light = OmniLight3D.new()
	core_light.light_color = Color(0.3, 1.0, 0.45)
	core_light.omni_range = 4.0
	core_light.light_energy = 0.0
	core.add_child(core_light)
	warn_light = OmniLight3D.new()
	warn_light.light_color = Color(1.0, 0.45, 0.15)
	warn_light.omni_range = 7.0
	warn_light.light_energy = 0.0
	warn_light.position = Vector3(0, 2.2, 0.4)
	add_child(warn_light)


func _process(delta: float) -> void:
	var v: ZombieVisual = get_meta(&"visual") as ZombieVisual
	if v == null or v.actor == null or core == null:
		return
	_t += delta
	var a: ZombieActor = v.actor
	var left: int = int(a.get_meta(&"warden_plates", plates.size()))
	if left != _shown_plates:
		_shown_plates = left
		for i: int in plates.size():
			plates[i].visible = i >= plates.size() - left
	var exposed: bool = left == 0 and a.alive
	_core_mat.emission_energy_multiplier = (2.5 + sin(_t * 9.0)) if exposed else 0.3
	core_light.light_energy = 2.0 if exposed else 0.0
	var warn: bool = a.flags & ZombieActor.Flag.TELEGRAPH != 0 and a.alive
	warn_light.light_energy = (3.0 + 2.0 * sin(_t * 30.0)) if warn else 0.0
