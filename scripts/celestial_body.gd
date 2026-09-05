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
		_apply_orbit_radius()

@export var orbit_speed: float = 0.0 # radians per second

@export_range(0.0, 360.0, 0.1, "degrees") var orbit_start_angle: float = 0.0:
	set(value):
		orbit_start_angle = value
		_apply_orbit_start_angle()

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

func _ready() -> void:
	_apply_radius()
	_apply_orbit_radius()
	_apply_orbit_start_angle()
	_apply_light_source_material()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	rotate_y(orbit_speed * delta)

func _apply_radius() -> void:
	if not is_node_ready():
		return
	mesh_instance.scale = Vector3.ONE * radius

func _apply_orbit_radius() -> void:
	if not is_node_ready():
		return
	mesh_instance.position = Vector3(orbit_radius, 0.0, 0.0)

func _apply_orbit_start_angle() -> void:
	if not is_node_ready():
		return
	rotation_degrees.y = orbit_start_angle

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
