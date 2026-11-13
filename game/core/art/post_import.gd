# Post-import step for every 3D scene (glTF/GLB) in the project — set as the scene importer's
# default `import_script/path` in project.godot (ARCHITECTURE §11, docs/ART_PIPELINE.md):
#   1. Material remap: a surface material named "M_<id>" is replaced by the shared
#      res://content/materials/<id>.tres (missing ones are reported and left as imported).
#   2. glTF extras: a "surface" extra becomes the node's `surface` meta (SurfaceTags) and is
#      copied onto the StaticBody3D Godot builds for -colonly / -convcolonly colliders.
#   3. Kit colliders go on physics layer 1 (world).
# Authority: editor/import time only (never runs in game builds).
@tool
extends EditorScenePostImport

const MATERIAL_DIR: String = "res://content/materials/"


func _post_import(scene: Node) -> Object:
	var missing: Dictionary = {}
	_walk(scene, missing)
	if not missing.is_empty():
		push_warning("post_import %s: no shared material for %s" % [get_source_file(), ", ".join(missing.keys())])
	return scene


func _walk(node: Node, missing: Dictionary) -> void:
	_apply_extras(node)
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(i)
			if m == null or not m.resource_name.begins_with("M_"):
				continue
			var mat_id: String = m.resource_name.substr(2)
			var path: String = MATERIAL_DIR + mat_id + ".tres"
			if ResourceLoader.exists(path):
				mi.mesh.surface_set_material(i, load(path) as Material)
			else:
				missing[mat_id] = true
	var body: StaticBody3D = node as StaticBody3D
	if body != null:
		body.collision_layer = 1
		body.collision_mask = 0
	for child: Node in node.get_children():
		_walk(child, missing)


func _apply_extras(node: Node) -> void:
	if not node.has_meta(&"extras"):
		return
	var extras: Variant = node.get_meta(&"extras")
	if not extras is Dictionary:
		return
	var gi: GeometryInstance3D = node as GeometryInstance3D
	if gi != null and (extras as Dictionary).get("cast_shadow", true) == false:
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not (extras as Dictionary).has("surface"):
		return
	var surface: StringName = StringName(str((extras as Dictionary)["surface"]))
	node.set_meta(&"surface", surface)
	var p: Node = node
	while p != null and not p is StaticBody3D:
		p = p.get_parent()
	if p != null:
		p.set_meta(&"surface", surface)
