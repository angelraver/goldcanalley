extends Node3D
class_name Bullet

@export var speed: float = 10.0
@export var max_lifetime: float = 4.0
@export var bullet_hole_scene: PackedScene = preload("res://games/duckshoot/scenes/bala_agujero.tscn")

var direction: Vector3 = Vector3.FORWARD
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
		ray_cast.collide_with_areas = true
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
		# Apuntar el raycast a la distancia que recorre la bala en este cuadro
		ray_cast.target_position = Vector3(0, 0, -move_distance)
		ray_cast.force_raycast_update()

		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			var hit_point = ray_cast.get_collision_point()
			var normal = ray_cast.get_collision_normal()

			var target_instance = collider
			if not collider.has_method("on_hit") and collider.get_parent() and collider.get_parent().has_method("on_hit"):
				target_instance = collider.get_parent()

			if target_instance.has_method("on_hit"):
				target_instance.on_hit()
			else:
				# Pasamos el collider a la función para emparentar el agujero a él
				_spawn_bullet_hole(hit_point, normal, collider)

			queue_free()
			return

	# Si no colisiona, avanza en la posición global
	global_position += direction * move_distance

func _spawn_bullet_hole(hit_point: Vector3, normal: Vector3, parent_node: Node3D) -> void:
	if not bullet_hole_scene:
		return

	var hole = bullet_hole_scene.instantiate() as Node3D
	
	# Emparentamos el agujero
	if is_instance_valid(parent_node):
		parent_node.add_child(hole)
		# Anulamos la escala del padre dividiendo su escala actual
		hole.scale = Vector3.ONE / parent_node.global_transform.basis.get_scale()
	else:
		get_tree().current_scene.add_child(hole)

	# Asignamos la posición global tras haberlo agregado al árbol
	hole.global_position = hit_point + (normal * 0.005)
	
	# Orientación de la cara plana
	if normal != Vector3.ZERO:
		if abs(normal.dot(Vector3.UP)) > 0.99:
			hole.look_at(hole.global_position + normal, Vector3.FORWARD)
		else:
			hole.look_at(hole.global_position + normal, Vector3.UP)
		
		hole.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
