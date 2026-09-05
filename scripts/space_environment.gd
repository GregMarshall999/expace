@tool
extends WorldEnvironment

@export var ambient_light_energy: float = 0.05:
	set(value):
		ambient_light_energy = value
		_apply_ambient()

@export var glow_intensity: float = 1.2
@export var glow_bloom: float = 0.3

func _ready() -> void:
	_build_environment()

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_energy = ambient_light_energy
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_bloom = glow_bloom
	env.glow_hdr_threshold = 1.0
	environment = env

func _apply_ambient() -> void:
	if environment != null:
		environment.ambient_light_energy = ambient_light_energy
