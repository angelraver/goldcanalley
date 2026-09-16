extends Node3D
class_name Rifle

@export_group("Prefabs & Nodos")
@export var bullet_scene: PackedScene = preload("res://games/duckshoot/scenes/bala.tscn")
@export var muzzle: Node3D

@export_group("Configuración de Disparo")
@export var double_tap_time: float = 0.3
@export var lock_aim_delay: float = 1.0

@export_group("Efecto Respiración (Idle)")
@export var sway_speed: float = 2.0
@export var sway_amount_y: float = 0.03
@export var sway_amount_x: float = 0.015

@export_group("Margen de Seguridad (Padding)")
# Cuánto margen (en unidades 3D) dejamos respecto al borde exacto de la pantalla
@export var margin_x: float = -0.2
@export var margin_y: float = -0.3

@export_group("Orientación y Perspectiva")
# Ángulos máximos (en grados) que rotará el rifle al llegar a los extremos
@export var max_yaw_degrees: float = 12.0   # Rotación horizontal (izquierda/derecha)
@export var max_pitch_degrees: float = 8.0   # Rotación vertical (arriba/abajo)

enum State { IDLE, DRAGGING, WAITING_FOR_SHOT }
var current_state: State = State.IDLE

var is_touching: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var rifle_start_pos: Vector3 = Vector3.ZERO

var last_release_time: float = -10.0
var idle_timer: float = 0.0
var time_passed: float = 0.0

var base_position: Vector3 = Vector3.ZERO

# Límites calculados dinámicamente según la cámara
var limit_min_x: float = -1.0
var limit_max_x: float = 1.0
var limit_min_y: float = -3.0
var limit_max_y: float = 3.0

func _ready() -> void:
	base_position = position
	if not muzzle and has_node("Muzzle"):
		muzzle = $Muzzle as Node3D

	# Calcular los límites visibles al iniciar
	_update_view_bounds()

func _update_view_bounds() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	# Distancia Z desde la cámara hasta la posición actual del rifle
	var depth = abs(camera.global_position.z - global_position.z)
	var viewport_size = get_viewport().get_visible_rect().size

	# Proyectar los esquinas del viewport al mundo 3D en la profundidad del rifle
	var top_left_3d = camera.project_position(Vector2(0, 0), depth)
	var bottom_right_3d = camera.project_position(viewport_size, depth)

	# El límite horizontal va de izquierda a derecha con margen
	limit_min_x = top_left_3d.x + margin_x
	limit_max_x = bottom_right_3d.x - margin_x

	# El límite vertical va desde la parte inferior hasta la MITAD de la pantalla
	limit_min_y = bottom_right_3d.y + margin_y
	limit_max_y = (top_left_3d.y + bottom_right_3d.y) * 0.5 - margin_y

func _process(delta: float) -> void:
	time_passed += delta

	match current_state:
		State.IDLE:
			_apply_sway(delta)

		State.DRAGGING:
			pass

		State.WAITING_FOR_SHOT:
			idle_timer += delta
			_apply_sway(delta, 0.3) 
			
			if idle_timer >= lock_aim_delay:
				_transition_to_idle()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		var touch_pos = event.position
		var viewport_height = get_viewport().get_visible_rect().size.y
		
		if event.is_pressed():
			# Solo permitir iniciar si toca de la mitad hacia abajo o está en modo espera
			if touch_pos.y >= (viewport_height / 2.0) or current_state == State.WAITING_FOR_SHOT:
				_on_touch_down(touch_pos)
		else:
			_on_touch_up()

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and is_touching):
		if is_touching and current_state == State.DRAGGING:
			_on_touch_drag(event.position)

func _on_touch_down(screen_pos: Vector2) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_release = current_time - last_release_time

	if time_since_release <= double_tap_time:
		shoot()
		current_state = State.WAITING_FOR_SHOT
		idle_timer = 0.0
		return

	is_touching = true
	touch_start_pos = screen_pos
	rifle_start_pos = position
	current_state = State.DRAGGING

func _on_touch_drag(screen_pos: Vector2) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var drag_delta = screen_pos - touch_start_pos

	var world_width = limit_max_x - limit_min_x
	var world_height = limit_max_y - limit_min_y

	var move_x = (drag_delta.x / viewport_size.x) * world_width * 2.0
	var move_y = -(drag_delta.y / viewport_size.y) * world_height * 2.0

	var target_x = clamp(rifle_start_pos.x + move_x, limit_min_x, limit_max_x)
	var target_y = clamp(rifle_start_pos.y + move_y, limit_min_y, limit_max_y)

	position.x = target_x
	position.y = target_y
	base_position = position

	# --- AJUSTE DE ROTACIÓN PARA EL LÁSER Y APUNTADO ---
	_update_rifle_rotation()
	
func _update_rifle_rotation() -> void:
	# Normalizar la posición del rifle entre -1.0 y 1.0 según los límites
	var norm_x = (position.x - (limit_min_x + limit_max_x) * 0.5) / ((limit_max_x - limit_min_x) * 0.5)
	var norm_y = (position.y - (limit_min_y + limit_max_y) * 0.5) / ((limit_max_y - limit_min_y) * 0.5)

	# Inclinación progresiva: al ir a la derecha rotamos en Y negativo, etc.
	var target_yaw = deg_to_rad(-norm_x * max_yaw_degrees)
	var target_pitch = deg_to_rad(norm_y * max_pitch_degrees)

	rotation.y = target_yaw
	rotation.x = target_pitch

func _on_touch_up() -> void:
	if not is_touching:
		return
		
	is_touching = false
	last_release_time = Time.get_ticks_msec() / 1000.0
	current_state = State.WAITING_FOR_SHOT
	idle_timer = 0.0

func _transition_to_idle() -> void:
	current_state = State.IDLE

func _apply_sway(delta: float, intensity: float = 1.0) -> void:
	var offset_y = sin(time_passed * sway_speed) * sway_amount_y * intensity
	var offset_x = cos(time_passed * sway_speed * 0.5) * sway_amount_x * intensity
	
	position.x = clamp(base_position.x + offset_x, limit_min_x, limit_max_x)
	position.y = clamp(base_position.y + offset_y, limit_min_y, limit_max_y)

func shoot() -> void:
	if not bullet_scene or not muzzle:
		return
		
	var bullet_instance = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet_instance)
	
	bullet_instance.global_position = muzzle.global_position
	
	var forward_dir = -muzzle.global_transform.basis.z
	if bullet_instance.has_method("setup"):
		bullet_instance.setup(forward_dir)
