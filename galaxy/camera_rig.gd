extends Node3D
class_name CameraRig

@export var zoom_speed := 1.0
@export var pan_speed := 0.002            # screen-space pan multiplier
@export var rotate_speed := 0.001         # radians per pixel

@export var min_zoom := 4.0
@export var max_zoom := 140.0

@export var min_pitch_deg := 45.0
@export var max_pitch_deg := 80.0

@export var map_size := 30               # set this from config so panning clamps

@onready var pivot: Node3D = $Pivot
@onready var arm: SpringArm3D = $Pivot/SpringArm3D
@onready var cam: Camera3D = $Pivot/SpringArm3D/Camera3D

var _is_panning := false
var _is_rotating := false
var _last_mouse := Vector2.ZERO

func _ready() -> void:
	cam.current = true
	# Default camera framing (nice angle)
	#pivot.rotation_degrees.x = -55.0
	#pivot.rotation_degrees.y = 45.0

	arm.spring_length = clamp(arm.spring_length, min_zoom, max_zoom)

func set_map_size(sz: int) -> void:
	map_size = sz
	# Center pivot by default
	#pivot.position = Vector3(sz * 0.5, 0.0, sz * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	# --- Zoom: mouse wheel ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(zoom_speed)

		# Pan: RMB drag
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_panning = event.pressed
			_last_mouse = get_viewport().get_mouse_position()

		# Rotate: MMB drag
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_rotating = event.pressed
			_last_mouse = get_viewport().get_mouse_position()

	# --- Mouse motion drag ---
	if event is InputEventMouseMotion:
		var mpos : Vector2 = event.position

		if _is_panning:
			var delta := mpos - _last_mouse
			_pan(delta)
			_last_mouse = mpos

		elif _is_rotating:
			var delta := mpos - _last_mouse
			_rotate(delta)
			_last_mouse = mpos

func _zoom(amount: float) -> void:
	#TODO: get config.galaxysize from the galaxy scene - so we can apply limited zoom
	#max_zoom = max(140.0, config.galaxy_size * 2.0)
	arm.spring_length = clamp(arm.spring_length + amount, min_zoom, max_zoom)

func _pan(mouse_delta: Vector2) -> void:
	var speed_mult := 1.0
	if Input.is_key_pressed(KEY_SHIFT):
		speed_mult = 2.5
	# Convert mouse delta into world movement relative to camera facing.
	# We pan along the ground plane (XZ).
	var right := cam.global_transform.basis.x
	var forward := -cam.global_transform.basis.z

	right.y = 0
	forward.y = 0
	right = right.normalized()
	forward = forward.normalized()

	# Bigger zoom = faster pan feels better
	var zoom_factor := arm.spring_length * pan_speed

	#TODO: add a global settings - to invert mouse x or y here
	var move := (-right * mouse_delta.x + forward * mouse_delta.y) * zoom_factor * speed_mult
	pivot.global_position += move
	_clamp_pivot_to_map()


func _rotate(mouse_delta: Vector2) -> void:
	# Yaw (around global up)
	#pivot.rotate_y(-mouse_delta.x * rotate_speed)

	# Pitch (around local X)
	var pitch := pivot.rotation.x - mouse_delta.y * rotate_speed
	var pitch_deg := rad_to_deg(pitch)
	pitch_deg = clamp(pitch_deg, -max_pitch_deg, -min_pitch_deg)
	pivot.rotation.x = deg_to_rad(pitch_deg)


func _clamp_pivot_to_map() -> void:
	# Keep camera target within map bounds (with small padding)
	var pad := 1.0
	var min_x := 0.0 + pad
	var max_x := float(map_size) - pad
	var min_z := 0.0 + pad
	var max_z := float(map_size) - pad

	pivot.global_position.x = clamp(pivot.global_position.x, min_x, max_x)
	pivot.global_position.z = clamp(pivot.global_position.z, min_z, max_z)
	#y stays 0 (on the plane)
	pivot.global_position.y = 0.0
