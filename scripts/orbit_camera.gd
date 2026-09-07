extends Node3D

@export var mouse_sensitivity: float = 0.005
@export var min_pitch_degrees: float = -80.0
@export var max_pitch_degrees: float = 80.0

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-20.0)
var _dragging: bool = false
var _last_mouse_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	rotation = Vector3(_pitch, _yaw, 0.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_last_mouse_position = event.position
		return
	if event is InputEventMouseMotion and _dragging:
		var motion_event := event as InputEventMouseMotion
		var delta: Vector2 = motion_event.position - _last_mouse_position
		_last_mouse_position = motion_event.position
		_yaw -= delta.x * mouse_sensitivity
		_pitch = clampf(
			_pitch - delta.y * mouse_sensitivity,
			deg_to_rad(min_pitch_degrees),
			deg_to_rad(max_pitch_degrees)
		)
		rotation = Vector3(_pitch, _yaw, 0.0)
