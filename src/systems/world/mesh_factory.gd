class_name MeshFactory
extends RefCounted
## Shared meshes and materials for the procedurally generated city.
##
## Everything the city is built from is a unit box or a unit cylinder, scaled
## per instance. Sharing the mesh and material resources keeps draw calls and
## VRAM down on mobile: the whole city renders from a handful of materials, and
## repeated geometry goes through MultiMesh so a district of forty buildings is
## a single draw call.

static var _unit_box: BoxMesh = null
static var _unit_cylinder: CylinderMesh = null
static var _quad: QuadMesh = null
static var _materials: Dictionary = {}


static func unit_box() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


static func unit_cylinder() -> CylinderMesh:
	if _unit_cylinder == null:
		_unit_cylinder = CylinderMesh.new()
		_unit_cylinder.top_radius = 0.5
		_unit_cylinder.bottom_radius = 0.5
		_unit_cylinder.height = 1.0
		_unit_cylinder.radial_segments = 10
		_unit_cylinder.rings = 1
	return _unit_cylinder


static func quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## A solid material keyed by colour so identical surfaces share one resource.
static func solid(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "s_%s_%.2f_%.2f" % [color.to_html(false), roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.metallic_specular = 0.3
	_materials[key] = m
	return m


## Material for MultiMesh instances that carry per-instance colours.
static func vertex_colored(roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "vc_%.2f_%.2f" % [roughness, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	m.metallic = metallic
	_materials[key] = m
	return m


## Emissive material used for windows, signage and Lumen glow. Its energy is
## animated by the world manager as day turns to night.
static func emissive(energy: float = 1.0, name_key: String = "glow") -> StandardMaterial3D:
	var key := "e_%s" % name_key
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.06, 0.08)
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_materials[key] = m
	return m


static func water() -> StandardMaterial3D:
	if _materials.has("water"):
		return _materials["water"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.13, 0.19, 0.92)
	m.roughness = 0.12
	m.metallic = 0.55
	m.rim_enabled = true
	m.rim = 0.6
	_materials["water"] = m
	return m


static func glass() -> StandardMaterial3D:
	if _materials.has("glass"):
		return _materials["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.5, 0.62, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.85
	_materials["glass"] = m
	return m


## Builds a MultiMeshInstance3D ready to receive per-instance transforms.
static func multimesh_node(node_name: String, mesh: Mesh, material: Material,
		count: int, cast_shadow: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Convenience: a static box collider added to a shared StaticBody3D.
static func add_box_collider(body: StaticBody3D, center: Vector3, size: Vector3,
		yaw: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	body.add_child(cs)


## A single visible box as its own node (used for interiors and landmarks).
static func box_node(size: Vector3, color: Color, roughness: float = 0.9) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = solid(color, roughness)
	return mi
