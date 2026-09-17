extends Node3D
class_name Bullet

@export var speed: float = 5.0
@export var max_bounces: int = 3
@export var max_lifetime: float = 4.0

var direction: Vector3 = Vector3.FORWARD
var current_bounces: int = 0
var life_timer: float = 0.0

@onready var ray_cast: RayCast3D = $RayCast3D

func setup(dir: Vector3) -> void:
	direction = dir.normalized()
	# Orientar visualmente el nodo de la bala hacia donde se mueve
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _ready() -> void:
	if ray_cast:
		ray_cast.enabled = true

func _process(delta: float) -> void:
	# Autodestrucción por tiempo
	life_timer += delta
	if life_timer >= max_lifetime:
		queue_free()
		return

	# Calcular desplazamiento de este frame
	var move_distance = speed * delta
	var next_position = global_position + (direction * move_distance)

	# Actualizar dirección y longitud del RayCast usando el vector real de movimiento
	if ray_cast:
		ray_cast.target_position = ray_cast.to_local(next_position)
		ray_cast.force_raycast_update()

		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			var hit_point = ray_cast.get_collision_point()
			var normal = ray_cast.get_collision_normal()

			# Procesar rebote si aún nos quedan intentos
			if current_bounces < max_bounces:
				_bounce(hit_point, normal)
				
				# Si además chocamos contra un target, avisamos
				if collider and collider.is_in_group("targets") and collider.has_method("on_hit"):
					collider.on_hit()
			else:
				# Si superó el límite de rebotes, se destruye
				queue_free()
			return

	# Si no hay colisión, avanzamos
	global_position = next_position

func _bounce(hit_point: Vector3, normal: Vector3) -> void:
	current_bounces += 1
	global_position = hit_point + (normal * 0.05) # Pequeño offset para evitar atascos
	
	# Fórmula de reflexión 3D
	direction = direction.bounce(normal).normalized()
	
	# Reorientar la bala y su RayCast hacia su nueva dirección de rebote
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)
