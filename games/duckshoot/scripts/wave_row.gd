
#@export var count: int = 6
#@export var step_x: float = 0.6
#@export var speed: float = 2.0          # Velocidad de rotación
#@export var radius_x: float = 0.08      # Radio/Desplazamiento horizontal (Eje X)
#@export var radius_y: float = 0.06      # Radio/Desplazamiento vertical (Eje Y)
#@export var phase_offset: float = 0.0

extends Node3D
class_name WaveRow

# Modelo por defecto (Wave 1)
@export var wave_mesh_scene: PackedScene = preload("res://games/duckshoot/scenes/wave1.tscn")

@export var count: int = 5
@export var step_x: float = 0.6
@export var speed: float = 2.0          # Velocidad de rotación
@export var radius_x: float = 0.08      # Radio/Desplazamiento horizontal (Eje X)
@export var radius_y: float = 0.03      # Radio/Desplazamiento vertical (Eje Y)
@export var phase_offset: float = 0.0

var time_passed: float = 0.0
var initial_x: float = 0.0
var initial_y: float = 0.0
var is_initialized: bool = false

# Método para inyectar el modelo (wave1 o wave2) antes de construir la fila
func set_wave_mesh(p_mesh_scene: PackedScene) -> void:
	if p_mesh_scene:
		wave_mesh_scene = p_mesh_scene
	_build_row()

func setup_initial_pos() -> void:
	initial_x = position.x
	initial_y = position.y
	is_initialized = true

func _build_row() -> void:
	# Eliminar hijos previos si se reconfigura
	for child in get_children():
		child.queue_free()
		
	if not wave_mesh_scene:
		return
		
	var total_width = (count - 1) * step_x
	var start_x = -total_width / 2.0
	
	for i in range(count):
		var wave_instance = wave_mesh_scene.instantiate()
		add_child(wave_instance)
		wave_instance.position = Vector3(start_x + (i * step_x), 0, 0)

func _process(delta: float) -> void:
	if not is_initialized:
		setup_initial_pos()
		
	time_passed += delta * speed
	
	# Giro mecánico en sentido horario (Plano X - Y)
	var offset_x = sin(time_passed + phase_offset) * radius_x
	var offset_y = cos(time_passed + phase_offset) * radius_y
	
	position.x = initial_x + offset_x
	position.y = initial_y + offset_y
