extends Node3D
class_name Target

signal target_despawned(target: Target)

@export var pulley_radius: float = 0.25
@export var underground_distance: float = 0.6 # Distancia extra que recorre de cabeza tras bambalinas

enum State { ENTERING, MOVING_STRAIGHT, EXITING }
var current_state: State = State.ENTERING

var speed: float = 0.0
var direction: int = 1 # 1 para derecha, -1 para izquierda
var x_start: float = 0.0
var x_limit: float = 0.0
var target_type: String = "A"
var is_special: bool = false

var base_y: float = 0.0
var angle_progress: float = 0.0
var exit_underground_progress: float = 0.0 # Distancia recorrida bajo el escalón

func setup(p_speed: float, p_direction: int, p_x_limit: float, p_type: String, p_is_special: bool) -> void:
	speed = p_speed
	direction = p_direction
	x_limit = p_x_limit
	target_type = p_type
	is_special = p_is_special

	base_y = global_position.y
	x_start = global_position.x

	angle_progress = PI
	exit_underground_progress = 0.0
	current_state = State.ENTERING
	_update_entering_position()

func _process(delta: float) -> void:
	match current_state:
		State.ENTERING:
			angle_progress -= (speed / pulley_radius) * delta
			if angle_progress <= 0.0:
				angle_progress = 0.0
				current_state = State.MOVING_STRAIGHT
				global_position.y = base_y
				global_position.x = x_start
			_update_entering_position()

		State.MOVING_STRAIGHT:
			global_position.x += speed * direction * delta
			global_position.y = base_y
			_orient_base_model()

			var reached_end = false
			if direction == 1 and global_position.x >= x_limit:
				reached_end = true
			elif direction == -1 and global_position.x <= x_limit:
				reached_end = true

			if reached_end:
				global_position.x = x_limit
				angle_progress = 0.0
				exit_underground_progress = 0.0
				current_state = State.EXITING

		State.EXITING:
			if angle_progress < PI:
				# Etapa 1: Giro en la polea de salida
				angle_progress += (speed / pulley_radius) * delta
				if angle_progress > PI:
					angle_progress = PI
				_update_exiting_position()
			else:
				# Etapa 2: Avanzar en recta de cabeza (tras bambalinas)
				exit_underground_progress += speed * delta
				_update_exiting_underground_position()

				if exit_underground_progress >= underground_distance:
					target_despawned.emit(self)
					queue_free()

func _update_entering_position() -> void:
	var offset_y = -pulley_radius * (1.0 - cos(angle_progress))
	var offset_x = 0.0
	
	_orient_base_model()

	if direction == 1:
		offset_x = -sin(angle_progress) * pulley_radius
		global_position.x = x_start + offset_x
		global_position.y = base_y + offset_y
		rotate_object_local(Vector3.FORWARD, angle_progress)
	else:
		offset_x = sin(angle_progress) * pulley_radius
		global_position.x = x_start + offset_x
		global_position.y = base_y + offset_y
		rotate_object_local(Vector3.FORWARD, angle_progress)

func _update_exiting_position() -> void:
	var offset_y = -pulley_radius * (1.0 - cos(angle_progress))
	var offset_x = sin(angle_progress) * pulley_radius if direction == 1 else -sin(angle_progress) * pulley_radius

	global_position.x = x_limit + offset_x
	global_position.y = base_y + offset_y

	_orient_base_model()
	rotate_object_local(Vector3.FORWARD, -angle_progress)

func _update_exiting_underground_position() -> void:
	# Mantiene la altura sumergida (-2 * R) y avanza horizontalmente en el sentido del carril
	global_position.y = base_y - (2.0 * pulley_radius)
	global_position.x = x_limit - (exit_underground_progress * direction)

	_orient_base_model()
	# Se mantiene invertido (PI / 180°) de cabeza
	rotate_object_local(Vector3.FORWARD, -PI)

func _orient_base_model() -> void:
	rotation = Vector3.ZERO
	if direction == 1:
		rotation_degrees.y = 180.0
	elif direction == -1:
		rotation_degrees.y = 0.0
