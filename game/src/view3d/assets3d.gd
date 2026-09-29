# Runtime loaders for game/assets3d (built by game/tools/sync_assets3d.sh; the folder has a .gdignore, so
# nothing goes through the import pipeline: GLB via GLTFDocument, images via Image.load_from_file).
extends RefCounted

static var _tex := {}
static var _glb := {}


## Drop the caches (called when the 3D view leaves the tree, so nothing leaks at exit).
static func clear() -> void:
	_tex.clear()
	_glb.clear()
	_glb_arr.clear()


static func root() -> String:
	# editor/dev: game/assets3d; exported build: an assets3d folder next to the .exe (scripts/export-windows.sh copies it)
	if OS.has_feature("editor"): return ProjectSettings.globalize_path("res://assets3d/")
	return OS.get_executable_path().get_base_dir().path_join("assets3d") + "/"


static func path(rel: String) -> String:
	return root() + rel


static func exists(rel: String) -> bool:
	return FileAccess.file_exists(path(rel))


static func available() -> bool:
	# hall_ext.glb: the one-world winery layout (older asset folders need game/tools/sync_assets3d.sh again)
	return exists("models/winery.json") and exists("models/hall_ext.glb") and exists("models/vine_guyot_g4.glb") and exists("hdri/clear.hdr")


static func tex(rel: String, mipmaps := true) -> Texture2D:
	if _tex.has(rel):
		return _tex[rel]
	var img := Image.load_from_file(path(rel))
	if img == null:
		push_warning("view3d: missing texture " + rel)
		img = Image.create(4, 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 0.5))
	if mipmaps:
		img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[rel] = t
	return t


static func scene(rel: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path(rel), state)
	if err != OK:
		push_warning("view3d: gltf load failed: " + rel)
		return Node3D.new()
	return doc.generate_scene(state)


static func meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		meshes(c, out)
	return out


## The surfaces of every mesh in a GLB, keyed by node name, as CPU arrays: [[arrays, material name, material], …] (cached).
## Read from the importer's meshes before anything is uploaded, so building new meshes from them never reads the
## GPU back (duplicating an uploaded ArrayMesh stalled ~9 ms per mesh).
static var _glb_arr := {}
static func glb_surfaces(rel: String) -> Dictionary:
	if _glb_arr.has(rel):
		return _glb_arr[rel]
	var out := {}
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path(rel), state) == OK:
		var gms := state.get_meshes()
		for node in state.get_nodes():
			if node.mesh < 0 or node.mesh >= gms.size():
				continue
			var im: ImporterMesh = (gms[node.mesh] as GLTFMesh).mesh
			var surfs := []
			for i in im.get_surface_count():
				var m := im.get_surface_material(i)
				surfs.append([im.get_surface_arrays(i), String(m.resource_name) if m else "", m])   # the GLB's own material for unnamed ones
			out[String(node.resource_name)] = surfs
	else:
		push_warning("view3d: gltf load failed: " + rel)
	_glb_arr[rel] = out
	return out


## All meshes of a GLB keyed by node name (cached; the same Mesh resources are shared).
static func glb_meshes(rel: String) -> Dictionary:
	if _glb.has(rel):
		return _glb[rel]
	var root_node := scene(rel)
	var out := {}
	for mi in meshes(root_node):
		out[String(mi.name)] = (mi as MeshInstance3D).mesh
	root_node.free()
	_glb[rel] = out
	return out


static func first_mesh(rel: String) -> Mesh:
	var d := glb_meshes(rel)
	return d.values()[0] if d.size() > 0 else BoxMesh.new()


static func pbr(set_name: String, uv_scale: float, tint := Color(1, 1, 1), rough_mul := 1.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_texture = tex("textures/%s/diff.jpg" % set_name)
	s.albedo_color = tint
	s.normal_enabled = true
	s.normal_texture = tex("textures/%s/nor_gl.jpg" % set_name)
	s.roughness_texture = tex("textures/%s/rough.jpg" % set_name)
	s.roughness = rough_mul
	if exists("textures/%s/ao.jpg" % set_name):
		s.ao_enabled = true
		s.ao_texture = tex("textures/%s/ao.jpg" % set_name)
	s.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s


static func look_basis(forward: Vector3) -> Basis:
	return Basis.looking_at(-forward.normalized(), Vector3.UP)


static func json(rel: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path(rel)))
