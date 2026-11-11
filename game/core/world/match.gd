# Match — per-match root: instances the map scene and per-match systems (PlayerSync,
# TargetRegistry, WeaponSync, WeaponFx now; RoundDirector, Economy, ... in later steps).
# Reachable via Match.current.
# Authority: exists on every peer; host-only systems check Net.is_host().
class_name Match
extends Node

static var current: Match = null

var definition: MapDefinition = null
var map_root: Node = null
var players: PlayerSync = null
var targets: TargetRegistry = null
var weapons: WeaponSync = null
var fx: WeaponFx = null


func setup(def: MapDefinition) -> Error:
	definition = def
	name = "Match"
	var packed: PackedScene = load(def.scene_path) as PackedScene
	if packed == null:
		Log.error(&"match", "Cannot load map scene %s" % def.scene_path)
		return ERR_CANT_OPEN
	map_root = packed.instantiate()
	add_child(map_root)
	current = self
	fx = WeaponFx.new()
	add_child(fx)
	targets = TargetRegistry.new()
	add_child(targets)
	targets.scan(map_root)
	players = PlayerSync.new()
	for node: Node in map_root.find_children("*", "Marker3D", true, false):
		if node.is_in_group(&"player_spawn"):
			players.spawn_points.append((node as Marker3D).global_position)
			players.spawn_yaw = (node as Marker3D).global_rotation.y
	add_child(players)
	weapons = WeaponSync.new()
	weapons.players = players
	weapons.targets = targets
	weapons.starting_weapons = def.starting_weapons
	add_child(weapons)
	Log.info(&"match", "Match started on '%s'" % def.id)
	return OK


func _exit_tree() -> void:
	if current == self:
		current = null
