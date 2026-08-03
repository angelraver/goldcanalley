extends Node3D

# Escenas exportadas
@export var escena_pelota: PackedScene = preload("res://Pelota.tscn")

# 1. CATÁLOGO DE OBJETOS: Mapeamos los textos del JSON a sus archivos .tscn
@export var catalogo_objetos: Dictionary = {
	"lata_aluminio": preload("res://lata.tscn"),
	"caja_madera": preload("res://caja_madera.tscn")
}

# Gestión de niveles mediante JSON
@export_file("*.json") var ruta_niveles_json: String = "res://niveles.json"
@export var nivel_actual: int = 1

# Configuración de la grilla imaginaria sobre la mesa
# Ajusta origen_mesa en el Inspector a la posición del centro de la superficie de tu mesa 3D
@export var origen_mesa: Vector3 = Vector3(0.0, 0.8, -4.0)

# Tamaño de paso de cada casillero [Ancho, Alto, Profundidad]
# (Ligeramente superior a las dimensiones de la lata para evitar solapamientos al arrancar)
@export var tamano_celda: Vector3 = Vector3(0.22, 0.31, 0.22)

@onready var camara: Camera3D = $Camera3D
var contenedor_latas: Node3D
var contenedor_pelotas: Node3D

@onready var raycast_apuntado: RayCast3D = $RayCastApuntado

# Configuración de la barra de fuerza
@export var fuerza_minima: float = 5.0
@export var fuerza_maxima: float = 30.0
@export var velocidad_oscilacion: float = 0.8 # Ajusta qué tan rápido va y viene el indicador

@onready var barra_energia: Control = $UI/BarraEnergia
@onready var indicador_circulo: Control = $UI/BarraEnergia/IndicadorCirculo
var tiempo_barra: float = 0.0

# --- CONFIGURACIÓN DE CÁMARA CINEMÁTICA ---
# Posición y rotación finales (Tomadas directamente de tu Inspector)
var pos_final_camara: Vector3 = Vector3(0.0, 1.443, -0.31)
var rot_final_camara: Vector3 = Vector3(deg_to_rad(-0.5), 0.0, 0.0)

# Posición y rotación iniciales (Cenital: sobre la mesa mirando hacia abajo)
var pos_inicial_camara: Vector3 = Vector3(0.0, 3.8, -3.8) 
var rot_inicial_camara: Vector3 = Vector3(deg_to_rad(-85.0), 0.0, 0.0)

# Control para no disparar mientras la cámara se está moviendo
var controles_activos: bool = false

func animar_camara_entrada() -> void:
	controles_activos = false # Bloqueamos el disparo
	
	# 1. Colocamos la cámara en su punto inicial (arriba)
	camara.global_position = pos_inicial_camara
	camara.global_rotation = rot_inicial_camara

	# 2. Creamos el Tween (el parámetro set_parallel hace que mueva posición y rotación a la vez)
	var tween = create_tween().set_parallel(true)

	# 3. Animación de posición y rotación en 2 segundos con curva suave (EASE_OUT)
	tween.tween_property(camara, "global_position", pos_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(camara, "global_rotation", rot_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# 4. Al finalizar la animación, activamos los controles del jugador
	tween.chain().tween_callback(func(): controles_activos = true)

func _unhandled_input(event: InputEvent) -> void:
	# Si la cámara se está moviendo, ignoramos los toques en pantalla
	if not controles_activos:
		return

	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		lanzar_nueva_pelota(event.position)

func _ready() -> void:
	contenedor_latas = Node3D.new()
	contenedor_latas.name = "ContenedorLatas"
	add_child(contenedor_latas)

	contenedor_pelotas = Node3D.new()
	contenedor_pelotas.name = "ContenedorPelotas"
	add_child(contenedor_pelotas)

	# Cargar el nivel configurado al iniciar el juego
	cargar_nivel(nivel_actual)
	
func _process(delta: float) -> void:
	# Animación del vaivén horizontal
	if barra_energia and indicador_circulo:
		tiempo_barra += delta * velocidad_oscilacion
		
		# pingpong(tiempo, 1.0) genera un valor que va de 0.0 a 1.0 y regresa a 0.0 de forma continua
		var progreso: float = pingpong(tiempo_barra, 1.0)
		
		# Calculamos el límite máximo horizontal descontando el ancho del círculo
		var margen_horizontal: float = barra_energia.size.x - indicador_circulo.size.x
		indicador_circulo.position.x = progreso * margen_horizontal

# Devuelve la fuerza calculada en el instante del disparo
func obtener_fuerza_actual() -> float:
	var progreso: float = pingpong(tiempo_barra, 1.0) # 0.0 = Izquierda (Verde), 1.0 = Derecha (Rojo)
	return lerp(fuerza_minima, fuerza_maxima, progreso)
	
func cargar_nivel(numero_nivel: int) -> void:
	# Limpiar objetos anteriores
	for obj in contenedor_latas.get_children():
		obj.queue_free()

	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No existe el archivo de niveles")
		return

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles = JSON.parse_string(texto_json)

	if not datos_niveles or not datos_niveles.has(str(numero_nivel)):
		print("ERROR: No existe el nivel ", numero_nivel)
		return

	var lista_objetos = datos_niveles[str(numero_nivel)]

	for item in lista_objetos:
		var grid_x: float = float(item[0])
		var grid_y: float = float(item[1])
		var grid_z: float = float(item[2])
		
		# Leer la clave del tipo de objeto (o usar lata_aluminio como respaldo si se omite)
		var clave_tipo: String = item[3] if item.size() > 3 else "lata_aluminio"

		# Buscar la escena correspondiente en el catálogo
		var escena_objetivo: PackedScene = catalogo_objetos.get(clave_tipo, catalogo_objetos["lata_aluminio"])

		# Posicionamiento en coordenadas 3D reales
		var pos_x = origen_mesa.x + (grid_x - 5.0) * tamano_celda.x
		var pos_y = origen_mesa.y + (grid_y - 0.5) * tamano_celda.y
		var pos_z = origen_mesa.z - (grid_z - 1.0) * tamano_celda.z

		# Instanciar e insertar en la escena
		var nuevo_objeto = escena_objetivo.instantiate() as RigidBody3D
		contenedor_latas.add_child(nuevo_objeto)
		nuevo_objeto.global_position = Vector3(pos_x, pos_y, pos_z)
	animar_camara_entrada()

func lanzar_nueva_pelota(posicion_pantalla: Vector2) -> void:
	if not camara or not escena_pelota or not raycast_apuntado:
		return

	# 1. Obtener la fuerza calculada de la barra en este preciso milisegundo
	var fuerza_calculada: float = obtener_fuerza_actual()

	# 2. Instanciar pelota
	var nueva_pelota = escena_pelota.instantiate() as RigidBody3D
	contenedor_pelotas.add_child(nueva_pelota)

	var punto_salida = camara.global_position - camara.global_transform.basis.z * 1.0
	nueva_pelota.global_position = punto_salida
	nueva_pelota.freeze = false

	# 3. Raycast para calcular trayectoria hacia la posición del toque
	var origen_rayo = camara.project_ray_origin(posicion_pantalla)
	var direccion_rayo = camara.project_ray_normal(posicion_pantalla)

	raycast_apuntado.global_position = origen_rayo
	raycast_apuntado.target_position = direccion_rayo * 100.0
	raycast_apuntado.force_raycast_update()

	var punto_objetivo_real: Vector3 = origen_rayo + direccion_rayo * 100.0
	if raycast_apuntado.is_colliding():
		punto_objetivo_real = raycast_apuntado.get_collision_point()

	var direccion_final = (punto_objetivo_real - nueva_pelota.global_position).normalized()

	# 4. Impulso proporcional a la masa y a la fuerza de la barra
	nueva_pelota.apply_central_impulse(direccion_final * fuerza_calculada * nueva_pelota.mass)
	
	get_tree().create_timer(6.0).timeout.connect(nueva_pelota.queue_free)

func reiniciar_nivel() -> void:
	# 1. Eliminar todas las pelotas que estén en pantalla
	for pelota in contenedor_pelotas.get_children():
		pelota.queue_free()

	# 2. Volver a instanciar todas las latas/cajas en sus posiciones iniciales
	cargar_nivel(nivel_actual)
	animar_camara_entrada()


func _on_boton_try_again_pressed() -> void:
	reiniciar_nivel()
