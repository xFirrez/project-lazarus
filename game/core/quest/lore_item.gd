# LoreItem — a collectible document or audio reel on a lore / reel MapMarker (DEVELOPMENT_PLAN Step
# 14 scope 2): interact to read (DocumentReader, the reader's Journal unlock) or to play the reel
# in-world (radio-filtered VO + subtitles for everyone nearby; each listener within
# REEL_HEAR_RADIUS unlocks it). Greybox+ model: a paper sheet / folder, or a reel-to-reel deck.
# Authority: HOST executes (QuestSystem routes the open / play messages); presentation is local.
class_name LoreItem
extends Interactable

const REEL_HEAR_RADIUS: float = 18.0

var entry_id: StringName = &""
var kind: String = "doc"
var quest: QuestSystem = null
var uses: int = 0  # host (tests)


func _ready() -> void:
	super()
	var title: String = String(quest.vo.lore.entry(entry_id).get("title", entry_id)) if quest != null else ""
	prompt = "play the reel" if kind == "reel" else "read"
	hold_time = 0.3
	use_radius = 2.0
	ping_label = title
	_build_model()


func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.3


func host_check(_peer_id: int, _player: PlayerCharacter) -> String:
	if kind == "reel" and quest != null and quest.vo.is_playing(entry_id):
		return "Playing"
	return ""


func host_execute(peer_id: int, _player: PlayerCharacter) -> bool:
	if quest == null:
		return false
	uses += 1
	if kind == "reel":
		quest.host_play_reel(entry_id, global_position + Vector3.UP * 0.4)
	else:
		quest.host_open_document(peer_id, entry_id)
	quest.host_event(&"lore", {"id": entry_id, "peer": peer_id})
	return true


func _build_model() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.roughness = 0.9
	if kind == "reel":
		bm.size = Vector3(0.42, 0.16, 0.3)
		mat.albedo_color = Color(0.28, 0.24, 0.2)
		for i: int in 2:
			var reel: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.09
			cm.bottom_radius = 0.09
			cm.height = 0.02
			reel.mesh = cm
			var rm: StandardMaterial3D = StandardMaterial3D.new()
			rm.albedo_color = Color(0.55, 0.5, 0.42)
			rm.metallic = 0.6
			reel.material_override = rm
			reel.position = Vector3(-0.1 + 0.2 * i, 0.09, 0.0)
			add_child(reel)
	else:
		bm.size = Vector3(0.22, 0.01, 0.3)
		mat.albedo_color = Color(0.88, 0.84, 0.72)
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.23, 0.18)  # readable from a distance in the dark
	mi.mesh = bm
	mi.material_override = mat
	mi.position.y = bm.size.y * 0.5
	add_child(mi)
