# GalvanicVisual — the Galvanic's vesperite electrodes on every peer (DEVELOPMENT_PLAN Step 12B;
# greybox+, authored model in Step 13): four glowing electrode spikes bolted to chest and head
# (bone attachments) plus a crackle light; while a leap winds up (TELEGRAPH flag) the electrodes
# flare and flicker — the 0.6 s warning players read.
# Authority: local presentation.
class_name GalvanicVisual
extends Node3D

const SPIKES: Array = [
	[&"Chest", Vector3(0.1, 0.12, 0.14), Vector3(0.4, 0, 0.3)],
	[&"Chest", Vector3(-0.1, 0.12, 0.14), Vector3(0.4, 0, -0.3)],
	[&"Chest", Vector3(0, 0.15, -0.16), Vector3(-0.5, 0, 0)],
	[&"Head", Vector3(0, 0.14, 0), Vector3(0, 0, 0)],
]

var spikes: Array[MeshInstance3D] = []
var light: OmniLight3D = null
var _mat: StandardMaterial3D = null
var _t: float = 0.0


func _ready() -> void:
	var v: ZombieVisual = get_meta(&"visual") as ZombieVisual
	if v == null or v.model == null or v.model.skeleton == null:
		return
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.5, 0.9, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.45, 0.9, 1.0)
	_mat.emission_energy_multiplier = 1.5
	for spec: Array in SPIKES:
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.bone_name = spec[0]
		v.model.skeleton.add_child(att)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.005
		cm.bottom_radius = 0.025
		cm.height = 0.16
		mi.mesh = cm
		mi.position = spec[1]
		mi.rotation = spec[2]
		mi.material_override = _mat
		att.add_child(mi)
		spikes.append(mi)
	light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.9, 1.0)
	light.omni_range = 3.0
	light.light_energy = 0.4
	light.position = Vector3(0, 1.4, 0)
	add_child(light)


func _process(delta: float) -> void:
	var v: ZombieVisual = get_meta(&"visual") as ZombieVisual
	if v == null or v.actor == null or _mat == null:
		return
	_t += delta
	var warn: bool = v.actor.flags & ZombieActor.Flag.TELEGRAPH != 0 and v.actor.alive
	_mat.emission_energy_multiplier = (4.0 + 3.0 * absf(sin(_t * 40.0))) if warn else 1.5
	light.light_energy = (2.5 + 1.5 * sin(_t * 33.0)) if warn else (0.4 if v.actor.alive else 0.0)
