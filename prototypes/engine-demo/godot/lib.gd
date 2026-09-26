# PROTOTYPE — shared runtime loaders (assets live in res://assets, loaded without the import pipeline).
extends RefCounted

static var texcache := {}

static func path(rel: String) -> String:
	return ProjectSettings.globalize_path("res://assets/" + rel)

static func tex(rel: String) -> Texture2D:
	if texcache.has(rel):
		return texcache[rel]
	var img := Image.load_from_file(path(rel))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	texcache[rel] = t
	return t

static func scene(rel: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path(rel), state)
	assert(err == OK, "gltf load failed: " + rel)
	return doc.generate_scene(state)

static func meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		meshes(c, out)
	return out

static func first_mesh(rel: String) -> Mesh:
	var root := scene(rel)
	var m: Mesh = (meshes(root)[0] as MeshInstance3D).mesh
	root.free()
	return m

static func pbr(set: String, uv_scale: float, tint := Color(1, 1, 1), rough_mul := 1.0) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_texture = tex("textures/%s/diff.jpg" % set)
	s.albedo_color = tint
	s.normal_enabled = true
	s.normal_texture = tex("textures/%s/nor_gl.jpg" % set)
	s.roughness_texture = tex("textures/%s/rough.jpg" % set)
	s.roughness = rough_mul
	if FileAccess.file_exists(path("textures/%s/ao.jpg" % set)):
		s.ao_enabled = true
		s.ao_texture = tex("textures/%s/ao.jpg" % set)
	s.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s

static func look_basis(forward: Vector3) -> Basis:
	"""Basis whose local +Z points along `forward`."""
	return Basis.looking_at(-forward.normalized(), Vector3.UP)

static func apply_camera(cam: Camera3D, c: Dictionary) -> void:
	var p: Array = c["position"]
	var t: Array = c["target"]
	cam.global_position = Vector3(p[0], p[1], p[2])
	cam.look_at(Vector3(t[0], t[1], t[2]))
