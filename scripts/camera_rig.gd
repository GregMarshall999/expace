extends Node3D

@export var pan_speed: float = 20.0
@export var zoom_step: float = 0.1
@export var zoom_speed: float = 1.0 # zoom units per second for Q/E
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.5
@export var zoom: float = 1.0:
	set(value):
		zoom = clampf(value, min_zoom, max_zoom)
		_apply_zoom()

@onready var camera: Camera3D = $Camera3D
var _camera_base_offset: Vector3

func _ready() -> void:
	_camera_base_offset = camera.position
	_apply_zoom()

func _process(delta: float) -> void:
	var input_dir := Vector3(
		Input.get_action_strength("pan_right") - Input.get_action_strength("pan_left"),
		0.0,
		Input.get_action_strength("pan_back") - Input.get_action_strength("pan_forward")
	)
	if input_dir != Vector3.ZERO:
		position += input_dir.normalized() * pan_speed * delta

	var zoom_dir := Input.get_action_strength("zoom_out") - Input.get_action_strength("zoom_in")
	if zoom_dir != 0.0:
		zoom += zoom_dir * zoom_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom += zoom_step

func _apply_zoom() -> void:
	if not is_node_ready():
		return
	camera.position = _camera_base_offset * zoom
