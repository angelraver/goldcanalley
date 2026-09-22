extends Node3D
class_name Target

var puntos: int = 0
signal target_despawned(target: Target)

@export var pulley_radius: float = 0.25
@export var underground_distance: float = 0.6 # Distancia extra que recorre de cabeza tras bambalinas
@export var fall_speed: float = 0.15 # Tiempo en segundos que tarda en caer
@export var fall_angle_degrees: float = 85.0 # Qué tan acostado queda al ser disparado

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
var is_hit: bool = false
var hit_fold_angle: float = 0.0 # Progresión del ángulo de caída (0.0 a 1.0)

# --- Audio: patrón GameAudioBase (ver games/goldcanalley/scripts/lata.gd y core/scripts/game_audio_base.gd) ---
var audio: GameAudioBase

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
	is_hit = false
	hit_fold_angle = 0.0
	
	current_state = State.ENTERING
	_update_entering_position()

func on_hit() -> void:
	if is_hit:
		return
	is_hit = true

	if audio and not is_special:
		audio.play_duck()
	
	# Desactivar colisiones si las tiene para evitar múltiples disparos
	var area = get_node_or_null("Area3D")
	if area:
		area.monitoring = false
		area.monitorable = false
	
	# Animación suave hacia los 90° (PI / 2)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "hit_fold_angle", 1.0, fall_speed)

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
	global_position.y = base_y - (2.0 * pulley_radius)
	global_position.x = x_limit - (exit_underground_progress * direction)

	_orient_base_model()
	rotate_object_local(Vector3.FORWARD, -PI)

func _orient_base_model() -> void:
	rotation = Vector3.ZERO
	if direction == 1:
		rotation_degrees.y = 180.0
	elif direction == -1:
		rotation_degrees.y = 0.0

	# Aplicar caída lateral al impactar:
	if hit_fold_angle > 0.0:
		var fold_radians = (PI / 2.0) * hit_fold_angle
		
		# Si va a la derecha (direction == 1), rotamos en un sentido; si va a la izquierda, en el opuesto
		var axis_dir = Vector3.RIGHT if direction == 1 else Vector3.LEFT
		rotate_object_local(axis_dir, fold_radians)

func set_target_data(p_puntos: int, p_color: Color) -> void:
	puntos = p_puntos
	
	if not is_inside_tree():
		await ready

	_apply_color(p_color)

func _apply_color(p_color: Color) -> void:
	# Buscamos el nodo MeshInstance3D dentro del subnodo $duck
	var mesh_node: MeshInstance3D = _find_mesh_instance(self)
	if not mesh_node:
		return

	# Obtenemos o duplicamos el material para no teñir todos los patos juntos
	var surface_count = mesh_node.get_surface_override_material_count()
	
	if surface_count > 0:
		for i in range(surface_count):
			_set_mesh_surface_color(mesh_node, i, p_color)
	else:
		# Si la malla no expone superficies múltiples, aplicamos a la superficie 0
		_set_mesh_surface_color(mesh_node, 0, p_color)

func _set_mesh_surface_color(mesh_node: MeshInstance3D, surface_idx: int, p_color: Color) -> void:
	var mat = mesh_node.get_surface_override_material(surface_idx)
	
	if not mat:
		var active_mat = mesh_node.get_active_material(surface_idx)
		if active_mat:
			mat = active_mat.duplicate() as StandardMaterial3D
			mesh_node.set_surface_override_material(surface_idx, mat)

	if mat is StandardMaterial3D:
		mat.albedo_color = p_color

# Función aux para recorrer los hijos y encontrar el MeshInstance3D importado
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
		
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found
			
	return null