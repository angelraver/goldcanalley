extends RigidBody3D

# Configuración de oscilación superior
var is_active: bool = false
var sweep_speed: float = 2.5
var min_x: float = -0.8
var max_x: float = 0.8
var spawn_y: float = 1.3

var time_passed: float = 0.0

func _ready() -> void:
	# Congelar la física inicialmente para que no caiga
	freeze = true
	position = Vector3(0.0, spawn_y, 0.2)

func _process(delta: float) -> void:
	if not is_active:
		time_passed += delta * sweep_speed
		# Movimiento suavizado de lado a lado usando Seno (-1 a 1)
		var ping_pong: float = (sin(time_passed) + 1.0) / 2.0 # Normalizado entre 0 y 1
		var current_x: float = lerp(min_x, max_x, ping_pong)
		position = Vector3(current_x, spawn_y, 0.2)

func release_ball() -> void:
	if not is_active:
		is_active = true
		freeze = false # Activa la gravedad y la física 3D
		# Le damos un pequeño impulso aleatorio o nulo hacia abajo
		linear_velocity = Vector3(0.0, -0.5, 0.0)
