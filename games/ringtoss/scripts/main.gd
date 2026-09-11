extends Node3D

const RING_SCENE: PackedScene = preload("res://games/ringtoss/scenes/ring.tscn")

@export_file("*.json") var ruta_niveles_json: String = "res://games/ringtoss/data/niveles.json"
@export var escena_cono: PackedScene = preload("res://games/ringtoss/scenes/cone.tscn")
@export var nivel_actual: int = 1

# El GLB original del cono mide ~75x155x75 unidades, por eso se escala acá.
# Estos valores quedan exportados para que puedas ajustar la mesa sin tocar el JSON.
@export var origen_conos: Vector3 = Vector3(0.0, 0.775, -4.0)
@export var escala_cono: Vector3 = Vector3(0.0018, 0.0018, 0.0018)
@export var rotacion_y_conos: float = 0.0

@onready var camara: Camera3D = $Camera3D

@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados

# Son restos de la escena base de Gold Can Alley. Se ocultan hasta que agreguemos el aro.
@onready var barra_energia: CanvasItem = get_node_or_null("UI/BarraEnergia") as CanvasItem
@onready var contenedor_lanzamientos_ui: CanvasItem = get_node_or_null("UI/ContenedorPelotasUI") as CanvasItem

@export var compensacion_perspectiva: float = 0.35
@export var sensibilidad_horizontal_ring: float = 0.0002

var pos_inicial_camara: Vector3 = Vector3(0.0, 3.8, -3.8)
var rot_inicial_camara: Vector3 = Vector3(deg_to_rad(-85.0), 0.0, 0.0)
var pos_final_camara: Vector3 = Vector3(0.0, 1.443, -0.31)
var rot_final_camara: Vector3 = Vector3(deg_to_rad(-0.5), 0.0, 0.0)

var contenedor_conos: Node3D
var contenedor_sensores: Node3D
var ctrl_resultados: ControladorResultados
var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var anillos_totales: int = 3
# Lanzados = cantidad de aros que ya salieron de la mano.
# Resueltos = tiros que ya terminaron en score o miss.
var anillos_lanzados: int = 0
var anillos_resueltos: int = 0
var esperando_fin_nivel: bool = false
var anillos_en_escena: Array[RigidBody3D] = []
var nivel_data: Dictionary = {}
var score_locks: Dictionary = {}

# Si existe un Marker3D llamado RingSpawn lo usamos.
# Si no existe, el aro aparece en posicion_spawn_ring.
@onready var ring_spawn: Marker3D = get_node_or_null("RingSpawn") as Marker3D

@export var posicion_spawn_ring: Vector3 = Vector3(0.0, 1.0, -1.7)
@export var fuerza_minima_ring: float = 0.8
@export var fuerza_maxima_ring: float = 1.55
@export var multiplicador_fuerza_ring: float = 0.008
@export var impulso_vertical_ring: float = 0.7
@export var swipe_minimo_ring: float = 20.0
@export var demora_siguiente_ring: float = 1.2

@export var limite_ring_izquierda: float = -1.2
@export var limite_ring_derecha: float = 1.2
@export var sensibilidad_drag_horizontal: float = 0.0015

# Deteccion de aro embocado. Los sensores se crean desde este script para
# mantener cone.tscn y ring.tscn reutilizables.
@export_group("Deteccion de score")
@export var sensor_cono_radio: float = 0.050
@export var sensor_cono_altura: float = 0.20
@export var sensor_cono_offset_y: float = 0.16
@export var sensor_centro_ring_radio_local: float = 0.10
@export var tiempo_confirmacion_score: float = 0.16
@export var tiempo_maximo_tiro: float = 3.0
@export var velocidad_vertical_max_score: float = 0.30
@export var demora_fin_por_objetivo: float = 0.8

const LAYER_RING_CENTER: int = 1 << 10
const LAYER_CONE_SCORE: int = 1 << 11

var drag_start: Vector2 = Vector2.ZERO
var last_drag_position: Vector2 = Vector2.ZERO
var dragging: bool = false
var ring_launched: bool = false
var movio_horizontalmente: bool = false

var current_ring: RigidBody3D = null

func _input(event: InputEvent) -> void:
	# TOUCH
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch

		if touch.pressed:
			_empezar_drag(touch.position)
		else:
			_terminar_drag(touch.position)

		return

	if event is InputEventScreenDrag:
		var touch_drag: InputEventScreenDrag = event as InputEventScreenDrag
		_actualizar_drag(touch_drag.position)
		return

	# MOUSE
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_empezar_drag(mouse_button.position)
			else:
				_terminar_drag(mouse_button.position)

		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion

		if dragging:
			_actualizar_drag(mouse_motion.position)

func _empezar_drag(posicion: Vector2) -> void:
	if current_ring == null:
		return

	if ring_launched:
		return

	drag_start = posicion
	last_drag_position = posicion
	dragging = true
	movio_horizontalmente = false

func _actualizar_drag(posicion: Vector2) -> void:
	if not dragging:
		return

	if current_ring == null:
		return

	if ring_launched:
		return

	var delta: Vector2 = posicion - last_drag_position
	last_drag_position = posicion

	# Sólo consideramos movimiento horizontal suficientemente claro.
	if absf(delta.x) > absf(delta.y):
		var nueva_posicion: Vector3 = current_ring.global_position

		nueva_posicion.x += delta.x * sensibilidad_drag_horizontal

		nueva_posicion.x = clampf(
			nueva_posicion.x,
			limite_ring_izquierda,
			limite_ring_derecha
		)

		current_ring.global_position = nueva_posicion

		movio_horizontalmente = true

func _terminar_drag(posicion: Vector2) -> void:
	if not dragging:
		return

	dragging = false

	if current_ring == null:
		return

	if ring_launched:
		return

	var swipe: Vector2 = drag_start - posicion

	# Si fue principalmente horizontal:
	# solamente dejamos el aro en la nueva posición.
	if movio_horizontalmente and absf(swipe.x) > absf(swipe.y):
		print("Ring reposicionado en X: ", current_ring.global_position.x)
		return

	# Para lanzar tiene que haber un swipe claramente hacia arriba.
	if swipe.y < swipe_minimo_ring:
		return

	lanzar_aro(swipe)
	
func _procesar_input_lanzamiento(presionado: bool, posicion: Vector2) -> void:
	if presionado:
		if current_ring == null or ring_launched:
			return

		drag_start = posicion
		dragging = true
		return

	if not dragging:
		return

	dragging = false

	if current_ring == null or ring_launched:
		return

	var swipe: Vector2 = drag_start - posicion
	print("Ring Toss SWIPE: ", swipe, " | length=", swipe.length())
	lanzar_aro(swipe)


func lanzar_aro(swipe: Vector2) -> void:
	if current_ring == null or ring_launched:	
		return
	if esperando_fin_nivel or ctrl_resultados.esta_mostrado():
		return
	if anillos_lanzados >= anillos_totales:
		return

	var longitud_swipe: float = swipe.length()
	if longitud_swipe < swipe_minimo_ring:
		print("Ring Toss: swipe demasiado corto")
		return

	var fuerza: float = clampf(
		longitud_swipe * multiplicador_fuerza_ring,
		fuerza_minima_ring,
		fuerza_maxima_ring
	)

	var centro_x: float = ring_spawn.global_position.x
	var offset_x: float = current_ring.global_position.x - centro_x

	var horizontal_swipe: float = clampf(
		-swipe.x / maxf(absf(swipe.y), 1.0),
		-0.8,
		0.8
	)

	var direccion: Vector3 = Vector3(
		offset_x * compensacion_perspectiva +
		horizontal_swipe * 0.5,
		impulso_vertical_ring,
		-1.0
	).normalized()

	var ring_lanzado: RigidBody3D = current_ring
	ring_launched = true
	anillos_lanzados += 1
	ring_lanzado.set_meta("resolved", false)
	ring_lanzado.set_meta("launch_number", anillos_lanzados)
	ring_lanzado.freeze = false
	ring_lanzado.sleeping = false
	ring_lanzado.apply_central_impulse(direccion * fuerza)
	ring_lanzado.apply_torque_impulse(Vector3(8.0, 0.0, 0.0))

	print(
		"Ring Toss RING LANZADO ", anillos_lanzados, "/", anillos_totales,
		" | fuerza=", fuerza, " | direccion=", direccion
	)

	# Si no entra en ningun cono dentro de este tiempo, cuenta como tiro fallado.
	_resolver_fallo_despues_de_timeout(ring_lanzado)

	await get_tree().create_timer(demora_siguiente_ring).timeout

	if not is_inside_tree():
		return
	if esperando_fin_nivel or ctrl_resultados.esta_mostrado():
		return
	if anillos_lanzados < anillos_totales:
		_spawn_ring()

func _ready() -> void:
	contenedor_conos = Node3D.new()
	contenedor_conos.name = "ConosGenerados"
	add_child(contenedor_conos)

	contenedor_sensores = Node3D.new()
	contenedor_sensores.name = "SensoresScoreGenerados"
	add_child(contenedor_sensores)

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	var hud: Array = [ui_puntaje, ui_level_number]
	ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)

	if barra_energia:
		barra_energia.visible = false
	if contenedor_lanzamientos_ui:
		contenedor_lanzamientos_ui.visible = false

	nivel_actual = max(1, save_manager.nivel_actual_seleccionado)
	cargar_nivel(nivel_actual)
	
	animar_camara_entrada()
	_spawn_ring()

func _spawn_ring() -> void:
	print("Ring Toss A PUNTO DE CREARSE ")

	# Si el aro anterior todavía estaba esperando ser lanzado, lo reemplazamos.
	# Si ya fue lanzado, lo dejamos en la escena para que pueda terminar de caer
	# y quedar enganchado en un cono.
	if current_ring != null and is_instance_valid(current_ring) and not ring_launched:
		current_ring.queue_free()

	current_ring = null

	var ring_instance: Node = RING_SCENE.instantiate()
	var ring_body: RigidBody3D = ring_instance as RigidBody3D

	if ring_body == null:
		ring_instance.queue_free()
		push_error("Ring Toss: el root de Ring.tscn debe ser un RigidBody3D")
		return

	# Primero hay que agregar el RigidBody3D al árbol y recién después
	# asignarle una posición/global_transform.
	add_child(ring_body)
	current_ring = ring_body

	current_ring.freeze = true
	current_ring.sleeping = false
	current_ring.linear_velocity = Vector3.ZERO
	current_ring.angular_velocity = Vector3.ZERO
		
	if ring_spawn != null:
		current_ring.global_position = ring_spawn.global_position
		current_ring.global_rotation = ring_spawn.global_rotation
	else:
		current_ring.position = posicion_spawn_ring

	current_ring.scale = Vector3(0.15, 0.15, 0.15)
	_configurar_sensor_centro_ring(current_ring)
	current_ring.set_meta("resolved", false)
	anillos_en_escena.append(current_ring)

	ring_launched = false
	dragging = false

	print("Ring Toss RING CREADO EN: ", current_ring.global_position)

func animar_camara_entrada() -> void:
	if barra_energia: barra_energia.visible = false
	if ui_puntaje: ui_puntaje.visible = false
	if ui_level_number: ui_level_number.visible = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(camara, "global_position", pos_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(camara, "global_rotation", rot_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func():
		if barra_energia: barra_energia.visible = true
		if ui_puntaje: ui_puntaje.visible = true
		if ui_level_number: ui_level_number.visible = true
	)

func cargar_nivel(numero_nivel: int) -> void:
	ctrl_resultados.reset()
	limpiar_conos()
	_limpiar_anillos()

	nivel_actual = numero_nivel
	puntaje_nivel = 0
	puntaje_maximo_nivel = 0
	anillos_lanzados = 0
	anillos_resueltos = 0
	esperando_fin_nivel = false
	nivel_data = {}
	actualizar_hud()

	if not FileAccess.file_exists(ruta_niveles_json):
		push_error("Ring Toss: no existe " + ruta_niveles_json)
		return

	var texto_json := FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_parseados: Variant = JSON.parse_string(texto_json)

	if not (datos_parseados is Dictionary):
		push_error("Ring Toss: niveles.json no contiene un Dictionary válido")
		return

	var datos: Dictionary = datos_parseados as Dictionary
	var clave: String = str(numero_nivel)
	if not datos.has(clave):
		push_error("Ring Toss: no existe el nivel " + clave)
		return

	nivel_data = datos[clave] as Dictionary
	anillos_totales = int(nivel_data.get("rings", 3))
	puntaje_maximo_nivel = int(nivel_data.get("puntaje_maximo", 0))

	var separacion_x := float(nivel_data.get("separacion_x", 0.30))
	var separacion_z := float(nivel_data.get("separacion_z", 0.30))
	var conos: Array = nivel_data.get("cones", [])

	for cone_data in conos:
		crear_cono(cone_data, separacion_x, separacion_z)

	# Fallback: si el JSON no trae puntaje máximo, lo calculamos pensando
	# en que cada lanzamiento puede acertar el cono de mayor valor.
	if puntaje_maximo_nivel <= 0:
		var max_por_cono := 0
		for cone_data in conos:
			max_por_cono = max(max_por_cono, int(cone_data.get("points", 100)))
		puntaje_maximo_nivel = max_por_cono * anillos_totales

	actualizar_hud()
	anunciar_nivel(numero_nivel)

func crear_cono(cone_data: Dictionary, separacion_x: float, separacion_z: float) -> Node3D:
	if not escena_cono:
		return null

	var cono := escena_cono.instantiate() as Node3D
	if not cono:
		return null

	var grid_x := float(cone_data.get("x", 0.0))
	var grid_z := float(cone_data.get("z", 0.0))
	var escala_extra := float(cone_data.get("scale", 1.0))
	var rot_y := float(cone_data.get("rot_y", rotacion_y_conos))
	var puntos := int(cone_data.get("points", 100))
	var cone_id := str(cone_data.get("id", "cone"))

	contenedor_conos.add_child(cono)
	cono.position = origen_conos + Vector3(grid_x * separacion_x, 0.0, grid_z * separacion_z)
	cono.scale = escala_cono * escala_extra
	cono.rotation_degrees.y = rot_y

	# El futuro script del aro puede leer estos metadatos directamente.
	cono.set_meta("cone_id", cone_id)
	cono.set_meta("points", puntos)

	_crear_sensor_cono(cono)

	return cono

func limpiar_conos() -> void:
	if contenedor_conos:
		for child in contenedor_conos.get_children():
			child.queue_free()
	if contenedor_sensores:
		for child in contenedor_sensores.get_children():
			child.queue_free()

func actualizar_hud() -> void:
	if ctrl_resultados:
		ctrl_resultados.actualizar_puntaje(puntaje_nivel)
		ctrl_resultados.actualizar_nivel(nivel_actual)

func anunciar_nivel(numero_nivel: int) -> void:
	if not ui_level_title:
		return
	ui_level_title.text = game_manager.obtener_titulo_nivel(str(numero_nivel), "ringtoss")
	ui_level_title.modulate.a = 1.0
	ui_level_title.visible = true
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ui_level_title.visible = false)

# -----------------------------------------------------------------------------
# Deteccion de score y resolucion de tiros
# -----------------------------------------------------------------------------
func _crear_sensor_cono(cono: Node3D) -> void:
	if contenedor_sensores == null:
		return

	var score_area: Area3D = Area3D.new()
	score_area.name = "ScoreArea_" + str(cono.get_meta("cone_id", "cone"))
	score_area.collision_layer = LAYER_CONE_SCORE
	score_area.collision_mask = LAYER_RING_CENTER
	score_area.monitoring = true
	score_area.monitorable = true
	contenedor_sensores.add_child(score_area)
	score_area.global_position = cono.global_position + Vector3(0.0, sensor_cono_offset_y, 0.0)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = sensor_cono_radio
	cylinder.height = sensor_cono_altura
	collision.shape = cylinder
	score_area.add_child(collision)

	var cone_id: String = str(cono.get_meta("cone_id", cono.name))
	var cone_points: int = int(cono.get_meta("points", 100))

	score_area.area_entered.connect(
		_on_score_area_entered.bind(
			score_area,
			cone_id,
			cone_points
		)
	)

	score_area.area_exited.connect(
		_on_score_area_exited.bind(
			score_area,
			cone_id
		)
	)

func _on_score_area_exited(
	area: Area3D,
	score_area: Area3D,
	cone_id: String
) -> void:
	if area.name != "RingCenter":
		return

	var ring: RigidBody3D = area.get_parent() as RigidBody3D
	if ring == null:
		return

	var ring_id: int = ring.get_instance_id()
	var lock_key: String = str(ring_id) + "::" + cone_id

	score_locks.erase(lock_key)
		
func _configurar_sensor_centro_ring(ring: RigidBody3D) -> void:
	var center_area: Area3D = Area3D.new()
	center_area.name = "RingCenter"
	center_area.collision_layer = LAYER_RING_CENTER
	center_area.collision_mask = LAYER_CONE_SCORE
	center_area.monitoring = true
	center_area.monitorable = true
	ring.add_child(center_area)

	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = sensor_centro_ring_radio_local
	collision.shape = sphere
	center_area.add_child(collision)


func _on_score_area_entered(
	area: Area3D,
	score_area: Area3D,
	cone_id: String,
	points: int
) -> void:
	if area.name != "RingCenter":
		return

	var ring: RigidBody3D = area.get_parent() as RigidBody3D
	if ring == null:
		return

	if not is_instance_valid(score_area):
		return

	var ring_id: int = ring.get_instance_id()
	var lock_key: String = str(ring_id) + "::" + cone_id

	# Si esta entrada ya está siendo procesada, NO volver a contar.
	if score_locks.has(lock_key):
		return

	# Se bloquea ANTES del await.
	score_locks[lock_key] = true

	await get_tree().create_timer(tiempo_confirmacion_score).timeout

	if not is_instance_valid(ring):
		score_locks.erase(lock_key)
		return

	if not is_instance_valid(area):
		score_locks.erase(lock_key)
		return

	if not is_instance_valid(score_area):
		score_locks.erase(lock_key)
		return

	# Si ya salió durante la espera, no cuenta.
	if not score_area.overlaps_area(area):
		score_locks.erase(lock_key)
		return

	registrar_score(points, score_area.global_position, cone_id)

func registrar_score(
	points: int,
	posicion: Vector3,
	cone_id: String
) -> void:
	if ctrl_resultados.esta_mostrado() or esperando_fin_nivel:
		return

	puntaje_nivel += points
	actualizar_hud()

	EfectosUI.crear_efecto_puntos(
		posicion,
		points
	)

	print(
		"SCORE | cone=",
		cone_id,
		" | +",
		points,
		" | TOTAL=",
		puntaje_nivel
	)

	if puntaje_maximo_nivel > 0 and puntaje_nivel >= puntaje_maximo_nivel:
		esperando_fin_nivel = true
		_finalizar_por_objetivo()
		
func _resolver_fallo_despues_de_timeout(ring: RigidBody3D) -> void:
	await get_tree().create_timer(tiempo_maximo_tiro).timeout

	if not is_instance_valid(ring):
		return
	if bool(ring.get_meta("resolved", false)):
		return
	if esperando_fin_nivel or ctrl_resultados.esta_mostrado():
		return

	ring.set_meta("resolved", true)
	print("RING TOSS MISS | tiro=", int(ring.get_meta("launch_number", 0)))
	registrar_lanzamiento()

func registrar_lanzamiento() -> void:
	if ctrl_resultados.esta_mostrado() or esperando_fin_nivel:
		return

	anillos_resueltos += 1

	print(
		"TIRO RESUELTO ",
		anillos_resueltos,
		"/",
		anillos_lanzados
	)

	if anillos_lanzados >= anillos_totales \
	and anillos_resueltos >= anillos_lanzados:
		finalizar_nivel()
		
func _finalizar_por_objetivo() -> void:
	await get_tree().create_timer(demora_fin_por_objetivo).timeout
	if is_inside_tree():
		finalizar_nivel()


func finalizar_nivel() -> void:
	if ctrl_resultados.esta_mostrado():
		return
	esperando_fin_nivel = true
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)


func _limpiar_anillos() -> void:
	for ring in anillos_en_escena:
		if is_instance_valid(ring):
			ring.queue_free()
	anillos_en_escena.clear()
	current_ring = null
	ring_launched = false
	dragging = false


func reiniciar_nivel() -> void:
	cargar_nivel(nivel_actual)
	_spawn_ring()
