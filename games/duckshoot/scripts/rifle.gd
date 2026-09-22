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

@export_group("Geometría y Cuadrante del Rifle")

@export_group("Geometría y Cuadrante del Rifle")
## Posición neutra central del tablero
@export var board_center: Vector3 = Vector3(0.0, 0.0, 0.0)

## Distancia Z a la que se coloca el rifle por detrás del tablero
@export var rifle_z_distance: float = 4.0

## Rango de traslación horizontal del rifle (cuadrante central)
@export var rifle_move_range_x: float = 0.2

## Rango de traslación vertical del rifle (cuadrante central)
@export var rifle_move_range_y: float = 1

## Cuánto puede subir el rifle desde el centro
@export var rifle_move_up_limit: float = 0.8

## Cuánto puede bajar el rifle desde el centro (ajústalo a un valor menor, ej. 0.3)
@export var rifle_move_down_limit: float = 0.2


@export_group("Ángulos de Inclinación (Grados)")
## Ángulo máximo de rotación horizontal al ir a los extremos (Yaw)
@export var max_aim_yaw_degrees: float = 25.0

## Ángulo máximo de rotación vertical al ir a los extremos (Pitch)
@export var max_aim_pitch_degrees: float = 20.0

enum State { IDLE, DRAGGING, WAITING_FOR_SHOT }
var current_state: State = State.IDLE

var is_touching: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var rifle_start_pos: Vector3 = Vector3.ZERO

var last_release_time: float = -10.0
var idle_timer: float = 0.0
var time_passed: float = 0.0

var base_position: Vector3 = Vector3.ZERO

# --- Audio: patrón GameAudioBase (ver games/goldcanalley/scripts/lata.gd y core/scripts/game_audio_base.gd) ---
var audio: GameAudioBase

# Límites de desplazamiento local del rifle
var min_rifle_x: float
var max_rifle_x: float
var min_rifle_y: float
var max_rifle_y: float

func _ready() -> void:
	if not muzzle and has_node("Muzzle"):
		muzzle = $Muzzle as Node3D

	base_position = Vector3(board_center.x, board_center.y, board_center.z + rifle_z_distance)
	position = base_position

	min_rifle_x = base_position.x - rifle_move_range_x
	max_rifle_x = base_position.x + rifle_move_range_x
	
	# Límites verticales independientes:
	min_rifle_y = base_position.y - rifle_move_down_limit  # Límite hacia abajo
	max_rifle_y = base_position.y + rifle_move_up_limit    # Límite hacia arriba

	_update_rifle_transform()

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
		
		if event.is_pressed():
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

	# Mapeo del arrastre en pantalla al movimiento 3D del rifle
	var move_sensitivity_x = (rifle_move_range_x * 2.0) / viewport_size.x
	var move_sensitivity_y = (rifle_move_range_y * 2.0) / viewport_size.y

	var target_x = rifle_start_pos.x + (drag_delta.x * move_sensitivity_x)
	var target_y = rifle_start_pos.y - (drag_delta.y * move_sensitivity_y)

	# 1. MOVER EL RIFLE (Traslación dentro del cuadrante)
	position.x = clamp(target_x, min_rifle_x, max_rifle_x)
	position.y = clamp(target_y, min_rifle_y, max_rifle_y)
	base_position = position

	# 2. CALCULAR ROTACIÓN SEGÚN LA POSICIÓN
	_update_rifle_transform()

func _on_touch_up() -> void:
	if not is_touching:
		return
		
	is_touching = false
	last_release_time = Time.get_ticks_msec() / 1000.0
	current_state = State.WAITING_FOR_SHOT
	idle_timer = 0.0

func _transition_to_idle() -> void:
	current_state = State.IDLE


func _update_rifle_transform() -> void:
	var norm_x: float = 0.0
	var norm_y: float = 0.0

	if rifle_move_range_x > 0.0:
		norm_x = (position.x - board_center.x) / rifle_move_range_x

	# Normalización asimétrica según si sube o baja
	var delta_y = position.y - board_center.y
	if delta_y > 0.0 and rifle_move_up_limit > 0.0:
		norm_y = delta_y / rifle_move_up_limit
	elif delta_y < 0.0 and rifle_move_down_limit > 0.0:
		norm_y = delta_y / rifle_move_down_limit

	var target_yaw = deg_to_rad(-norm_x * max_aim_yaw_degrees)
	var target_pitch = deg_to_rad(norm_y * max_aim_pitch_degrees)

	rotation.y = target_yaw
	rotation.x = target_pitch

func shoot() -> void:
	if not bullet_scene or not muzzle:
		return

	if audio:
		audio.play_rifle()

	var bullet_instance = bullet_scene.instantiate()

	# Inyección de audio: patrón GameAudioBase (ver games/goldcanalley/scripts/main.gd:141)
	if audio:
		bullet_instance.audio = audio
	
	# Usar el vector de dirección global real desde la culata hasta la boquilla (Muzzle)
	var real_rifle_direction = (muzzle.global_position - global_position).normalized()
	
	if real_rifle_direction == Vector3.ZERO:
		real_rifle_direction = -global_transform.basis.z

	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.global_position = muzzle.global_position
	
	# IMPORTANTE: Llamar a setup DESPUÉS de establecer global_position y añadir a la escena
	if bullet_instance.has_method("setup"):
		bullet_instance.setup(real_rifle_direction)
		
func _apply_sway(delta: float, intensity: float = 1.0) -> void:
	var offset_y = sin(time_passed * sway_speed) * sway_amount_y * intensity
	var offset_x = cos(time_passed * sway_speed * 0.5) * sway_amount_x * intensity
	
	position.x = clamp(base_position.x + offset_x, min_rifle_x, max_rifle_x)
	position.y = clamp(base_position.y + offset_y, min_rifle_y, max_rifle_y)

	_update_rifle_transform()
