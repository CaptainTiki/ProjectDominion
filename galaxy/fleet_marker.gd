extends Node3D
class_name FleetMarker

# Lightweight visual helper for fleets:
# - draws a line from the fleet to its destination
# - shows a small destination marker

@export var line_y: float = 0.06
@export var line_thickness: float = 0.03

var _dest_global: Vector3 = Vector3.ZERO
var _has_dest: bool = false

@onready var _line_mesh: MeshInstance3D = null
@onready var _dest_marker: MeshInstance3D = null
@onready var _visual: Node3D = null

var _line_box: BoxMesh = null

func _ready() -> void:
	# Create nodes at runtime so existing scenes stay simple.
	_visual = get_node_or_null("Visual") as Node3D

	_line_mesh = get_node_or_null("MoveLine") as MeshInstance3D
	if _line_mesh == null:
		_line_mesh = MeshInstance3D.new()
		_line_mesh.name = "MoveLine"
		add_child(_line_mesh)
		_line_mesh.position = Vector3.ZERO
	_line_box = BoxMesh.new()
	_line_box.size = Vector3(line_thickness, 0.01, 1.0)
	_line_mesh.mesh = _line_box

	_dest_marker = get_node_or_null("DestMarker") as MeshInstance3D
	if _dest_marker == null:
		_dest_marker = MeshInstance3D.new()
		_dest_marker.name = "DestMarker"
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		_dest_marker.mesh = sm
		add_child(_dest_marker)

	# Basic emissive material (inherits fleet tint by default if GalaxyMap overrides Visual/Selection,
	# so we keep this subtle and neutral).
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1, 1)
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh.material_override = mat
	_dest_marker.material_override = mat

	_set_visible(false)

func set_destination_global(dest_world: Vector3, enabled: bool) -> void:
	_has_dest = enabled
	_dest_global = dest_world
	_set_visible(_has_dest)
	_update_line()

func clear_destination() -> void:
	_has_dest = false
	_set_visible(false)

func _process(_delta: float) -> void:
	# Movement is turn-based, but the camera can move and the marker can get reparented.
	# Updating each frame keeps the line + facing direction stable.
	if _has_dest:
		_update_line()

func _set_visible(v: bool) -> void:
	if _line_mesh:
		_line_mesh.visible = v
	if _dest_marker:
		_dest_marker.visible = v

func _update_line() -> void:
	if _line_mesh == null:
		return

	# Destination in local space (XZ plane)
	var local_dest := to_local(_dest_global)
	local_dest.y = line_y

	# Draw a visible "rod" between origin and destination.
	var v := Vector2(local_dest.x, local_dest.z)
	var len := v.length()
	if len <= 0.001:
		_line_mesh.visible = false
		if _dest_marker:
			_dest_marker.visible = false
		return
	_line_mesh.visible = true
	if _dest_marker:
		_dest_marker.visible = true

	# Update mesh dimensions.
	if _line_box == null:
		_line_box = BoxMesh.new()
		_line_mesh.mesh = _line_box
	_line_box.size = Vector3(line_thickness, 0.01, len)

	# Place it halfway.
	_line_mesh.position = Vector3(local_dest.x * 0.5, line_y, local_dest.z * 0.5)
	# Rotate so Z axis points toward destination.
	_line_mesh.rotation = Vector3(0.0, atan2(v.x, v.y), 0.0)

	if _dest_marker:
		_dest_marker.position = local_dest

	# Rotate the fleet visual to face its destination (direction pointer).
	if _visual:
		_visual.rotation = Vector3(0.0, atan2(v.x, v.y), 0.0)
