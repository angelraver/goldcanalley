extends Node3D

const RING_SCENE: PackedScene = preload("res://games/ringtoss/scenes/ring.tscn")
# Altura real del cono en metros: GLB 155 * escala 0.0018 = 0.279.
const ALTURA_CONO_M: float = 0.279

@export_file("*.json") var ruta_niveles_json: String = "res://games/ringtoss/data/niveles.json"
@export var escena_cono: PackedScene = preload("res://games/ringtoss/scenes/cone.tscn")
@export var nivel_actual: int = 1

# El GLB del cono mide ~75x155x75, por eso se escala acá.
@export var origen_conos: Vector3 = Vector3(0.0, 0.775, -4.0)
@export var escala_cono: Vector3 = Vector3(0.0018, 0.0018, 0.0018)
@export var rotacion_y_conos: float = 0.0

@export_group("Aro")
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
@export var compensacion_perspectiva: float = 0.35

@export_group("Deteccion de score")
@export var radio_embocado: float = 0.095
@export var penetracion_minima_score: float = 0.02
@export var horizontalidad_minima_score: float = 0.6
@export var tiempo_maximo_tiro: float = 3.0
@export var demora_fin_por_objetivo: float = 0.8

@onready var ring_spawn: Marker3D = get_node_or_null("RingSpawn") as Marker3D
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var barra_energia: CanvasItem = get_node_or_null("UI/BarraEnergia") as CanvasItem
@onready var contenedor_lanzamientos_ui: CanvasItem = get_node_or_null("UI/ContenedorPelotasUI") as CanvasItem

var contenedor_conos: Node3D
var ctrl_resultados: ControladorResultados
var nivel_data: Dictionary = {}
var anillos_en_escena: Array[RigidBody3D] = []
var current_ring: RigidBody3D = null

var puntaje_nivel: int = 0
var puntaje_maximo_nivel: int = 0
var anillos_totales: int = 3
var anillos_lanzados: int = 0
var anillos_resueltos: int = 0
var esperando_fin_nivel: bool = false

var drag_start: Vector2 = Vector2.ZERO
var last_drag_position: Vector2 = Vector2.ZERO
var dragging: bool = false
var ring_launched: bool = false
var movio_horizontalmente: bool = false


func _ready() -> void:
	contenedor_conos = Node3D.new()
	contenedor_conos.name = "ConosGenerados"
	add_child(contenedor_conos)

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	ctrl_resultados.configurar(panel_resultados, [ui_puntaje, ui_level_number], ui_puntaje, ui_level_number, reiniciar_nivel)

	# Restos de la escena base: se ocultan hasta agregar el aro.
	for resto in [barra_energia, contenedor_lanzamientos_ui]:
		if resto:
			resto.visible = false

	nivel_actual = max(1, save_manager.nivel_actual_seleccionado)
	cargar_nivel(nivel_actual)
	_spawn_ring()


func _input(event: InputEvent) -> void:
	var posicion := Vector2.ZERO
	var fase := ""
	if event is InputEventScreenTouch:
		posicion = event.position
		fase = "inicio" if event.pressed else "fin"
	elif event is InputEventScreenDrag:
		posicion = event.position
		fase = "mover"
	elif event is InputEventMouseButton:
		var boton := event as InputEventMouseButton
		if boton.button_index != MOUSE_BUTTON_LEFT:
			return
		posicion = boton.position
		fase = "inicio" if boton.pressed else "fin"
	elif event is InputEventMouseMotion and dragging:
		posicion = event.position
		fase = "mover"
	else:
		return

	# El aro debe existir y seguir en la mano para cualquier gesto.
	if current_ring == null or ring_launched:
		if fase == "fin":
			dragging = false
		return

	match fase:
		"inicio":
			drag_start = posicion
			last_drag_position = posicion
			dragging = true
			movio_horizontalmente = false
		"mover":
			if not dragging:
				return
			var delta: Vector2 = posicion - last_drag_position
			last_drag_position = posicion
			if absf(delta.x) > absf(delta.y):
				var nueva_pos: Vector3 = current_ring.global_position
				nueva_pos.x = clampf(nueva_pos.x + delta.x * sensibilidad_drag_horizontal, limite_ring_izquierda, limite_ring_derecha)
				current_ring.global_position = nueva_pos
				movio_horizontalmente = true
		"fin":
			if not dragging:
				return
			dragging = false
			var swipe: Vector2 = drag_start - posicion
			# Gesto horizontal: solo reposiciona, no lanza.
			if movio_horizontalmente and absf(swipe.x) > absf(swipe.y):
				return
			if swipe.y >= swipe_minimo_ring:
				lanzar_aro(swipe)


func lanzar_aro(swipe: Vector2) -> void:
	if current_ring == null or ring_launched or esperando_fin_nivel:
		return
	if ctrl_resultados.esta_mostrado() or anillos_lanzados >= anillos_totales:
		return
	if swipe.length() < swipe_minimo_ring:
		return

	var fuerza: float = clampf(swipe.length() * multiplicador_fuerza_ring, fuerza_minima_ring, fuerza_maxima_ring)
	var offset_x: float = current_ring.global_position.x
	if ring_spawn:
		offset_x -= ring_spawn.global_position.x
	var horizontal_swipe: float = clampf(-swipe.x / maxf(absf(swipe.y), 1.0), -0.8, 0.8)
	var direccion: Vector3 = Vector3(offset_x * compensacion_perspectiva + horizontal_swipe * 0.5, impulso_vertical_ring, -1.0).normalized()

	var ring_lanzado: RigidBody3D = current_ring
	ring_launched = true
	anillos_lanzados += 1
	ring_lanzado.set_meta("resolved", false)
	ring_lanzado.set_meta("launch_number", anillos_lanzados)
	ring_lanzado.freeze = false
	ring_lanzado.sleeping = false
	ring_lanzado.angular_velocity = Vector3.ZERO
	ring_lanzado.angular_damp = 8.0
	ring_lanzado.apply_central_impulse(direccion * fuerza)
	ring_lanzado.apply_torque_impulse(Vector3(8.0, 0.0, 0.0))

	_programar_miss(ring_lanzado)
	await get_tree().create_timer(demora_siguiente_ring).timeout
	if is_inside_tree() and not esperando_fin_nivel and not ctrl_resultados.esta_mostrado() and anillos_lanzados < anillos_totales:
		_spawn_ring()


func _spawn_ring() -> void:
	# Si el anterior sigue en la mano se reemplaza; si ya voló se deja caer.
	if current_ring != null and is_instance_valid(current_ring) and not ring_launched:
		current_ring.queue_free()
	current_ring = null

	var ring_body := RING_SCENE.instantiate() as RigidBody3D
	if ring_body == null:
		push_error("Ring Toss: el root de Ring.tscn debe ser un RigidBody3D")
		return
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
	current_ring.set_meta("resolved", false)
	anillos_en_escena.append(current_ring)
	ring_launched = false
	dragging = false


func cargar_nivel(numero_nivel: int) -> void:
	ctrl_resultados.reset()
	_limpiar_escena()
	nivel_actual = numero_nivel
	puntaje_nivel = 0
	puntaje_maximo_nivel = 0
	anillos_lanzados = 0
	anillos_resueltos = 0
	esperando_fin_nivel = false
	nivel_data = {}
	ctrl_resultados.actualizar_puntaje(0)
	ctrl_resultados.actualizar_nivel(nivel_actual)

	if not FileAccess.file_exists(ruta_niveles_json):
		push_error("Ring Toss: no existe " + ruta_niveles_json)
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta_niveles_json))
	if not (datos is Dictionary) or not datos.has(str(numero_nivel)):
		push_error("Ring Toss: nivel inválido " + str(numero_nivel))
		return

	nivel_data = datos[str(numero_nivel)] as Dictionary
	anillos_totales = int(nivel_data.get("rings", 3))
	puntaje_maximo_nivel = int(nivel_data.get("puntaje_maximo", 0))
	var separacion_x := float(nivel_data.get("separacion_x", 0.30))
	var separacion_z := float(nivel_data.get("separacion_z", 0.30))
	var conos: Array = nivel_data.get("cones", [])
	var max_por_cono := 0

	for cone_data in conos:
		if escena_cono == null:
			continue
		var cono := escena_cono.instantiate() as Node3D
		if cono == null:
			continue
		var cone_id := str(cone_data.get("id", "cone"))
		var puntos := int(cone_data.get("points", 100))
		var escala_extra := float(cone_data.get("scale", 1.0))
		max_por_cono = max(max_por_cono, puntos)
		contenedor_conos.add_child(cono)
		cono.position = origen_conos + Vector3(float(cone_data.get("x", 0.0)) * separacion_x, 0.0, float(cone_data.get("z", 0.0)) * separacion_z)
		cono.scale = escala_cono * escala_extra
		cono.rotation_degrees.y = float(cone_data.get("rot_y", rotacion_y_conos))
		cono.set_meta("cone_id", cone_id)
		cono.set_meta("points", puntos)
		cono.set_meta("altura_mundo", ALTURA_CONO_M * escala_extra)

	# Fallback: cada tiro podría acertar el cono de mayor valor.
	if puntaje_maximo_nivel <= 0:
		puntaje_maximo_nivel = max_por_cono * anillos_totales

	ctrl_resultados.actualizar_puntaje(puntaje_nivel)
	ctrl_resultados.actualizar_nivel(nivel_actual)
	if ui_level_title:
		ui_level_title.text = game_manager.obtener_titulo_nivel(str(numero_nivel), "ringtoss")
		ui_level_title.modulate.a = 1.0
		ui_level_title.visible = true
		var tween := create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): ui_level_title.visible = false)


func reiniciar_nivel() -> void:
	cargar_nivel(nivel_actual)
	_spawn_ring()


func _limpiar_escena() -> void:
	if contenedor_conos:
		for child in contenedor_conos.get_children():
			child.queue_free()
	for ring in anillos_en_escena:
		if is_instance_valid(ring):
			ring.queue_free()
	anillos_en_escena.clear()
	current_ring = null
	ring_launched = false
	dragging = false


func _physics_process(_delta: float) -> void:
	if esperando_fin_nivel or contenedor_conos == null:
		return
	if ctrl_resultados and ctrl_resultados.esta_mostrado():
		return
	if contenedor_conos.get_child_count() == 0 or anillos_en_escena.is_empty():
		return
	for ring in anillos_en_escena:
		if not is_instance_valid(ring):
			continue
		# Solo los aros ya lanzados y aún no resueltos pueden puntuar.
		if not bool(ring.get_meta("launch_number", 0)):
			continue
		if bool(ring.get_meta("resolved", false)):
			continue
		if ring.freeze:
			continue
		for cono in contenedor_conos.get_children():
			if not is_instance_valid(cono):
				continue
			if _es_embocado(ring, cono as Node3D):
				_cobrar_punto(ring, cono as Node3D)
				break


# El cono puntúa solo si su eje atraviesa el hueco del aro:
# el segmento base->punta corta el plano del aro dentro del radio interior,
# con la punta por encima del plano y la base por debajo.
func _es_embocado(ring: RigidBody3D, cono: Node3D) -> bool:
	var up: Vector3 = ring.global_transform.basis.orthonormalized().y
	if up.y < 0.0:
		up = -up
	# El aro debe estar razonablemente horizontal; si va de canto no cuenta.
	if up.y < horizontalidad_minima_score:
		return false
	var altura: float = float(cono.get_meta("altura_mundo", ALTURA_CONO_M))
	var base: Vector3 = cono.global_position
	var punta: Vector3 = base + Vector3(0.0, altura, 0.0)
	var centro: Vector3 = ring.global_position
	var y_base: float = (base - centro).dot(up)
	var y_punta: float = (punta - centro).dot(up)
	# Straddle: base abajo, punta arriba con penetración mínima.
	if y_base >= 0.0:
		return false
	if y_punta <= penetracion_minima_score:
		return false
	# Intersección del eje del cono con el plano del aro.
	var s: float = y_base / (y_base - y_punta)
	var inter: Vector3 = base + (punta - base) * s
	var radial: float = (inter - centro).cross(up).length()
	return radial <= radio_embocado


func _cobrar_punto(ring: RigidBody3D, cono: Node3D) -> void:
	if bool(ring.get_meta("resolved", false)):
		return
	if esperando_fin_nivel or ctrl_resultados.esta_mostrado():
		return
	ring.set_meta("resolved", true)
	var points := int(cono.get_meta("points", 100))
	puntaje_nivel += points
	ctrl_resultados.actualizar_puntaje(puntaje_nivel)
	EfectosUI.crear_efecto_puntos(cono.global_position + Vector3(0.0, float(cono.get_meta("altura_mundo", ALTURA_CONO_M)), 0.0), points)
	anillos_resueltos += 1
	if puntaje_maximo_nivel > 0 and puntaje_nivel >= puntaje_maximo_nivel:
		esperando_fin_nivel = true
		await get_tree().create_timer(demora_fin_por_objetivo).timeout
		if is_inside_tree():
			finalizar_nivel()
	elif anillos_lanzados >= anillos_totales and anillos_resueltos >= anillos_lanzados:
		finalizar_nivel()


# Si el aro no emboca dentro del timeout, el tiro cuenta como fallado.
func _programar_miss(ring: RigidBody3D) -> void:
	await get_tree().create_timer(tiempo_maximo_tiro).timeout
	if not is_instance_valid(ring) or bool(ring.get_meta("resolved", false)):
		return
	if esperando_fin_nivel or ctrl_resultados.esta_mostrado():
		return
	ring.set_meta("resolved", true)
	anillos_resueltos += 1
	if anillos_lanzados >= anillos_totales and anillos_resueltos >= anillos_lanzados:
		finalizar_nivel()


func finalizar_nivel() -> void:
	if ctrl_resultados.esta_mostrado():
		return
	esperando_fin_nivel = true
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)
