extends Node3D
class_name Bullet

@export var speed: float = 10.0
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
		ray_cast.collide_with_areas = true # <--- ¡ESTO ES CRUCIAL!
		ray_cast.collide_with_bodies = true

func _process(delta: float) -> void:
	# Autodestrucción por tiempo
	life_timer += delta
	if life_timer >= max_lifetime:
		queue_free()
		return

	# Calcular desplazamiento de este frame
	var move_distance = speed * delta
	
	if ray_cast:
		# Apuntar el raycast exactamente a la distancia que va a recorrer la bala en este cuadro
		ray_cast.target_position = Vector3(0, 0, -move_distance)
		ray_cast.force_raycast_update()

		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			print("1. RayCast colisionó con: ", collider.name) # Checkear si el raycast detecta algo

			var hit_point = ray_cast.get_collision_point()
			var normal = ray_cast.get_collision_normal()

			var target_instance = collider
			if not collider.has_method("on_hit") and collider.get_parent() and collider.get_parent().has_method("on_hit"):
				target_instance = collider.get_parent()

			if target_instance.has_method("on_hit"):
				print("2. IMPACTO EN PATO CONFIRMADO!") # <--- ESTE ES EL PRINT CLAVE
				target_instance.on_hit()
			else:
				print("3. Colisionó con algo pero NO tiene on_hit(): ", target_instance.name)

			if current_bounces < max_bounces:
				_bounce(hit_point, normal)
			else:
				queue_free()
			return

	# Si no colisiona, avanza en la posición global
	global_position += direction * move_distance

func _bounce(hit_point: Vector3, normal: Vector3) -> void:
	current_bounces += 1
	global_position = hit_point + (normal * 0.05) # Pequeño offset para evitar atascos
	
	# Fórmula de reflexión 3D
	direction = direction.bounce(normal).normalized()
	
	# Reorientar la bala y su RayCast hacia su nueva dirección de rebote
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)
