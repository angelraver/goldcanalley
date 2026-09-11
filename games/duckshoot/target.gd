extends Node3D
class_name Target

signal target_despawned(target: Target)

var speed: float = 0.0
var direction: int = 1
var x_limit: float = 0.0
var target_type: String = "A"
var is_special: bool = false

func setup(p_speed: float, p_direction: int, p_x_limit: float, p_type: String, p_is_special: bool) -> void:
	speed = p_speed
	direction = p_direction
	x_limit = p_x_limit
	target_type = p_type
	is_special = p_is_special
	
	_orient_model()

func _orient_model() -> void:
	if direction == 1:
		# Avanza hacia la derecha
		rotation_degrees.y = 180
	elif direction == -1:
		# Avanza hacia la izquierda
		rotation_degrees.y = 0

func _process(delta: float) -> void:
	global_position.x += speed * direction * delta
	
	var past_limit = false
	if direction == 1 and global_position.x >= x_limit:
		past_limit = true
	elif direction == -1 and global_position.x <= x_limit:
		past_limit = true
		
	if past_limit:
		target_despawned.emit(self)
		queue_free()
