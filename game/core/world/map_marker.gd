# MapMarker — a typed, canonically named placeholder for a feature a later step builds (perk
# machines, Relic Box locations, traps, hazards, relays, the Forge, workbench, Conduit parts, EE
# objects, lore items, music boxes, ravens, secret entrances; DEVELOPMENT_PLAN Step 8 scope 6).
# Later steps find markers by `kind` / `marker_id` and replace or extend them; markers never move
# during art passes (AGENT_GUIDE rule 7). Greybox visual: a coloured post + id label; markers with
# `requires_power` light up when the main circuit turns on.
# Authority: static map data (cosmetic visual).
class_name MapMarker
extends Marker3D

const GROUP: StringName = &"map_marker"
const KIND_COLORS: Dictionary = {
	&"perk": Color(0.95, 0.35, 0.2),
	&"box": Color(0.25, 0.6, 1.0),
	&"wallbuy": Color(0.8, 0.8, 0.8),
	&"trap": Color(1.0, 0.85, 0.2),
	&"hazard": Color(1.0, 0.5, 0.1),
	&"relay": Color(0.4, 1.0, 0.6),
	&"forge": Color(0.6, 1.0, 0.9),
	&"workbench": Color(0.7, 0.6, 0.4),
	&"part": Color(0.9, 0.5, 1.0),
	&"ee": Color(0.4, 1.0, 0.4),
	&"lore": Color(0.95, 0.9, 0.7),
	&"reel": Color(0.85, 0.75, 0.55),
	&"music_box": Color(1.0, 0.6, 0.8),
	&"raven": Color(0.3, 0.3, 0.35),
	&"secret": Color(0.6, 0.3, 0.9),
}

@export var kind: StringName = &""
@export var marker_id: StringName = &""
@export var zone: StringName = &""
@export var label: String = ""
@export var requires_power: bool = false
@export var show_visual: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	if marker_id == &"":
		marker_id = StringName(name)
	if show_visual and not DisplayServer.get_name() == "headless":
		_build_visual()


func _build_visual() -> void:
	var c: Color = KIND_COLORS.get(kind, Color(0.7, 0.7, 0.7))
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.12
	cm.height = 1.0
	mi.mesh = cm
	mi.position.y = 0.5
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c * 0.4
	mi.material_override = m
	mi.visibility_range_end = 40.0
	add_child(mi)
	var l: Label3D = Label3D.new()
	l.text = "%s\n%s" % [marker_id, label] if label != "" else String(marker_id)
	l.position.y = 1.3
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = c
	l.visibility_range_end = 25.0
	add_child(l)
	if requires_power:
		var pl: PoweredLight = PoweredLight.new()
		pl.name = "PowerLamp"
		var o: OmniLight3D = OmniLight3D.new()
		o.light_color = c
		o.light_energy = 0.8
		o.omni_range = 3.0
		o.position.y = 1.0
		pl.add_child(o)
		add_child(pl)
