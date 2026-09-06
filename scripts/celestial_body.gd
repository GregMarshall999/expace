@tool
class_name CelestialBody
extends Node3D

const TRAIL_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const TRAIL_MAX_SEGMENTS := 64

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

# How far behind the body the trail extends along the orbit circle,
# as a fraction of the full circle (0 = no trail, 1 = the full circle).
@export_range(0.0, 1.0, 0.01) var trail_length: float = 0.0:
	set(value):
		trail_length = value
		_apply_orbit_position()

# Fraction of the trail's own length (from the body outward) that stays
# fully opaque before it starts fading to transparent at the tail end.
@export_range(0.0, 1.0, 0.01) var trail_fade: float = 0.5:
	set(value):
		trail_fade = value
		_apply_orbit_position()

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var trail_instance: MeshInstance3D = $Trail

# Orbit angle in radians. The body's own `position` is derived from this
# each frame rather than rotating the node, so a child CelestialBody (a
# moon) parented directly under this one orbits this body's actual
# position instead of inheriting a spin around this body's own parent.
var _orbit_angle: float = 0.0
var _trail_material: StandardMaterial3D

func _ready() -> void:
	_orbit_angle = deg_to_rad(orbit_start_angle)
	rotation = Vector3.ZERO
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_instance.material_override = _trail_material
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
	# The trail is authored in the parent's local space (the orbit
	# circle's frame), so cancel out this node's own offset.
	trail_instance.position = -position
	_update_trail_mesh()

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

func _update_trail_mesh() -> void:
	if trail_length <= 0.0 or orbit_radius <= 0.0:
		trail_instance.mesh = null
		return
	var segment_count := maxi(1, roundi(TRAIL_MAX_SEGMENTS * trail_length))
	var sweep := trail_length * TAU
	var direction := -1.0 if orbit_speed >= 0.0 else 1.0
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	points.resize(segment_count + 1)
	colors.resize(segment_count + 1)
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count) # 0 at the body, 1 at the tail end
		var angle := _orbit_angle + direction * t * sweep
		points[i] = Vector3(orbit_radius * cos(angle), 0.0, -orbit_radius * sin(angle))
		var alpha := 1.0
		if t > trail_fade:
			var fade_span := 1.0 - trail_fade
			alpha = 1.0 - (t - trail_fade) / fade_span if fade_span > 0.0 else 0.0
		var color := TRAIL_COLOR
		color.a *= alpha
		colors[i] = color
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	trail_instance.mesh = array_mesh
