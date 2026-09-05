@tool
class_name CelestialBody
extends Node3D

@export var radius: float = 1.0:
	set(value):
		radius = value
		_apply_radius()

@export var orbit_radius: float = 0.0:
	set(value):
		orbit_radius = value
		_apply_orbit_position()

@export var orbit_speed: float = 0.0 # radians per second

@export_range(0.0, 360.0, 0.1, "degrees") var orbit_start_angle: float = 0.0:
	set(value):
		orbit_start_angle = value
		_orbit_angle = deg_to_rad(value)
		_apply_orbit_position()

@export var is_light_source: bool = false:
	set(value):
		is_light_source = value
		_apply_light_source_material()

@export var glow_color: Color = Color(1.0, 0.85, 0.6):
	set(value):
		glow_color = value
		_apply_light_source_material()

@export var glow_energy: float = 4.0:
	set(value):
		glow_energy = value
		_apply_light_source_material()

@onready var mesh_instance: MeshInstance3D = $Mesh

# Orbit angle in radians. The body's own `position` is derived from this
# each frame rather than rotating the node, so a child CelestialBody (a
# moon) parented directly under this one orbits this body's actual
# position instead of inheriting a spin around this body's own parent.
var _orbit_angle: float = 0.0

func _ready() -> void:
	_orbit_angle = deg_to_rad(orbit_start_angle)
	rotation = Vector3.ZERO
	_apply_radius()
	_apply_orbit_position()
	_apply_light_source_material()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_orbit_angle += orbit_speed * delta
	_apply_orbit_position()

func _apply_radius() -> void:
	if not is_node_ready():
		return
	mesh_instance.scale = Vector3.ONE * radius

func _apply_orbit_position() -> void:
	if not is_node_ready():
		return
	position = Vector3(orbit_radius * cos(_orbit_angle), 0.0, -orbit_radius * sin(_orbit_angle))

func _apply_light_source_material() -> void:
	if not is_node_ready():
		return
	if not is_light_source:
		mesh_instance.material_override = null
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = glow_energy
	mesh_instance.material_override = material
