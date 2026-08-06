extends Node3D

# Escenas exportadas
@export var escena_pelota: PackedScene = preload("res://scenes/pelota.tscn")

# 1. CATÁLOGO DE OBJETOS: Mapeamos los textos del JSON a sus archivos .tscn
@export var catalogo_objetos: Dictionary = {
	"lata_aluminio": preload("res://scenes/lata.tscn"),
	"caja_madera": preload("res://scenes/caja_madera.tscn")
}

# Gestión de niveles mediante JSON
@export_file("*.json") var ruta_niveles_json: String = "res://data/niveles.json"
@export_file("*.json") var ruta_valores_json: String = "res://data/valores.json"
const CARPETA_CANS = "res://images/cans/"
@export var nivel_actual: int = 1

@export var escena_puntos_flotantes: PackedScene = preload("res://scenes/puntos_flotantes.tscn")

var valores_objetos: Dictionary = {}
var puntaje_nivel: int = 0

# Configuración de la grilla imaginaria sobre la mesa
@export var origen_mesa: Vector3 = Vector3(0.0, 0.8, -4.0)
@export var tamano_celda: Vector3 = Vector3(0.22, 0.31, 0.22)

@onready var camara: Camera3D = $Camera3D
var contenedor_latas: Node3D
var contenedor_pelotas: Node3D
@onready var label_puntaje_final: Label = $UI/PanelResultados/FondoPanel/LabelPuntajeFinal
@onready var raycast_apuntado: RayCast3D = $RayCastApuntado
@onready var label_puntaje: Label = $UI/LabelPuntaje

@export var fuerza_minima: float = 5.0
@export var fuerza_maxima: float = 30.0
@export var velocidad_oscilacion: float = 0.8

@onready var barra_energia: Control = $UI/BarraEnergia
@onready var indicador_circulo: Control = $UI/BarraEnergia/IndicadorCirculo
var tiempo_barra: float = 0.0

# --- CONFIGURACIÓN DE PELOTAS ---
@export var pelotas_maximas: int = 3
var pelotas_restantes: int = 3
var esperando_fin_nivel: bool = false

# Referencias a la UI de la pelota 3D y el contador
@onready var label_pelotas: Label = $UI/ContenedorPelotasUI/LabelPelotas
@onready var pelota_ui_3d: Node3D = $UI/ContenedorPelotasUI/SubViewportContainer/SubViewport/PelotaUI
@onready var contenedor_pelotas_ui: Control = $UI/ContenedorPelotasUI
@onready var panel_resultados: Control = $UI/PanelResultados
@onready var fondo_desenfoque: Control = $UI/PanelResultados/FondoDesenfoque
@onready var fondo_panel: TextureRect = $UI/PanelResultados/FondoPanel
@onready var ribbon_amarilla: TextureRect = $UI/PanelResultados/FondoPanel/RibbonAmarilla
@onready var ribbon_roja: TextureRect = $UI/PanelResultados/FondoPanel/RibbonRoja
@onready var ribbon_azul: TextureRect = $UI/PanelResultados/FondoPanel/RibbonAzul
var puntaje_maximo_nivel: int = 0
var gano_ribbon_amarilla: bool = false 
var gano_ribbon_roja: bool = false 
var gano_ribbon_azul: bool = false 
var escala_orig_amarilla: Vector2
var escala_orig_roja: Vector2
var escala_orig_azul: Vector2

# --- CONFIGURACIÓN DE CÁMARA CINEMÁTICA ---
var pos_final_camara: Vector3 = Vector3(0.0, 1.443, -0.31)
var rot_final_camara: Vector3 = Vector3(deg_to_rad(-0.5), 0.0, 0.0)

var pos_inicial_camara: Vector3 = Vector3(0.0, 3.8, -3.8) 
var rot_inicial_camara: Vector3 = Vector3(deg_to_rad(-85.0), 0.0, 0.0)

var controles_activos: bool = false

func _ready() -> void:
	contenedor_latas = Node3D.new()
	contenedor_latas.name = "ContenedorLatas"
	add_child(contenedor_latas)

	contenedor_pelotas = Node3D.new()
	contenedor_pelotas.name = "ContenedorPelotas"
	add_child(contenedor_pelotas)
	cargar_valores()
	nivel_actual = SaveManager.nivel_actual_seleccionado
	
	ribbon_amarilla.pivot_offset = ribbon_amarilla.size / 2
	escala_orig_amarilla = ribbon_amarilla.scale

	ribbon_roja.pivot_offset = ribbon_roja.size / 2
	escala_orig_roja = ribbon_roja.scale

	ribbon_azul.pivot_offset = ribbon_azul.size / 2
	escala_orig_azul = ribbon_azul.scale

	cargar_nivel(nivel_actual)

func _physics_process(_delta: float) -> void:
	# Verificamos el estado físico de las latas en cada frame de física
	verificar_latas_derribadas()

func cargar_valores() -> void:
	if not FileAccess.file_exists(ruta_valores_json):
		print("ERROR: No existe el archivo de valores en: ", ruta_valores_json)
		return

	var texto_json = FileAccess.get_file_as_string(ruta_valores_json)
	var datos = JSON.parse_string(texto_json)

	if datos is Dictionary:
		valores_objetos = datos
	else:
		print("ERROR: Formato inválido en valores.json")

func cargar_nivel(numero_nivel: int) -> void:
	esperando_fin_nivel = false	
	pelotas_restantes = pelotas_maximas
	actualizar_ui_pelotas()
	puntaje_nivel = 0
	puntaje_maximo_nivel = 0
	actualizar_ui_puntaje()

	for pelota in contenedor_pelotas.get_children():
		pelota.queue_free()

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

	var clave_por_defecto: String = catalogo_objetos.keys()[0] if not catalogo_objetos.is_empty() else ""
	var escena_por_defecto: PackedScene = catalogo_objetos.get(clave_por_defecto, null)
	var lista_objetos = datos_niveles[str(numero_nivel)]

	for item in lista_objetos:
		var grid_x: float = float(item[0])
		var grid_y: float = float(item[1])
		var grid_z: float = float(item[2])
		var clave_tipo: String = item[3] if item.size() > 3 else clave_por_defecto
		var escena_objetivo: PackedScene = catalogo_objetos.get(clave_tipo, escena_por_defecto)
		var datos_tipo: Dictionary = valores_objetos.get(clave_tipo, {})

		# 1. Lectura de variables desde valores.json
		var factor_escala: float = float(datos_tipo.get("escala", 1.0))
		var factor_ancho: float = float(datos_tipo.get("ancho", 1.0))
		var factor_alto: float = float(datos_tipo.get("alto", 1.0))
		var masa_objeto: float = float(datos_tipo.get("masa", 1.0))
		var puntos_objeto: int = int(datos_tipo.get("pts", 100))

		# 2. Cálculo de escala tridimensional final (X, Z = Ancho / Y = Alto)
		var escala_vector = Vector3(
			factor_ancho * factor_escala,
			factor_alto * factor_escala,
			factor_ancho * factor_escala
		)

		# 3. Cálculo de posición en la grilla
		var paso_celda = Vector3(
			tamano_celda.x * escala_vector.x,
			tamano_celda.y * escala_vector.y,
			tamano_celda.z * escala_vector.z
		)

		puntaje_maximo_nivel += puntos_objeto
		var pos_x = origen_mesa.x + (grid_x - 5.0) * paso_celda.x
		var pos_y = origen_mesa.y + (grid_y - 0.5) * paso_celda.y
		var pos_z = origen_mesa.z - (grid_z - 1.0) * paso_celda.z

		# 4. Instanciación y personalización de la lata
		var nuevo_objeto = escena_objetivo.instantiate() as RigidBody3D
		nuevo_objeto.scale = escala_vector
		nuevo_objeto.mass = masa_objeto
		nuevo_objeto.set_meta("tipo", clave_tipo)
		nuevo_objeto.set_meta("derribado", false)

		# 5. Aplicar texturas y shader desde valores.json
		aplicar_material_lata(nuevo_objeto, datos_tipo)

		contenedor_latas.add_child(nuevo_objeto)
		nuevo_objeto.global_position = Vector3(pos_x, pos_y, pos_z)

	animar_camara_entrada()

func verificar_latas_derribadas() -> void:
	for obj in contenedor_latas.get_children():
		if not (obj is RigidBody3D):
			continue

		if obj.get_meta("derribado", false):
			continue

		var tipo: String = obj.get_meta("tipo", "lata_aluminio")
		var esta_derribada: bool = false

		if obj.global_position.y < (origen_mesa.y - 0.15):
			esta_derribada = true
		else:
			var vector_arriba_lata = obj.global_transform.basis.y
			var inclinacion = vector_arriba_lata.dot(Vector3.UP)
			var esta_tumbada = inclinacion < 0.8
			var esta_quieta = obj.linear_velocity.length() < 0.08 and obj.angular_velocity.length() < 0.08

			if esta_tumbada and esta_quieta:
				esta_derribada = true

		if esta_derribada:
			obj.set_meta("derribado", true)

			var datos_tipo = valores_objetos.get(tipo, {})
			var puntos_ganados: int = int(datos_tipo.get("pts", 0))

			puntaje_nivel += puntos_ganados
			actualizar_ui_puntaje()
			crear_efecto_puntos(obj.global_position, puntos_ganados)
			#	print("💥 ¡Objeto Derribado! Tipo: ", tipo, " | +", puntos_ganados, " pts | Puntaje Nivel: ", puntaje_nivel)

func animar_camara_entrada() -> void:
	if barra_energia: barra_energia.visible = false
	controles_activos = false
	camara.global_position = pos_inicial_camara
	camara.global_rotation = rot_inicial_camara

	var tween = create_tween().set_parallel(true)
	tween.tween_property(camara, "global_position", pos_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(camara, "global_rotation", rot_final_camara, 2.0)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(func(): 
		controles_activos = true
		if barra_energia: barra_energia.visible = true
		if label_puntaje: label_puntaje.visible = true
		if contenedor_pelotas_ui: contenedor_pelotas_ui.visible = true
	)

func _unhandled_input(event: InputEvent) -> void:
	if not controles_activos:
		return

	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		lanzar_nueva_pelota(event.position)

func _process(delta: float) -> void:
	if barra_energia and indicador_circulo:
		tiempo_barra += delta * velocidad_oscilacion
		var progreso: float = pingpong(tiempo_barra, 1.0)
		var margen_horizontal: float = barra_energia.size.x - indicador_circulo.size.x
		indicador_circulo.position.x = progreso * margen_horizontal

	if pelota_ui_3d:
		pelota_ui_3d.rotate_y(delta * 1.5)

func obtener_fuerza_actual() -> float:
	var progreso: float = pingpong(tiempo_barra, 1.0)
	return lerp(fuerza_minima, fuerza_maxima, progreso)

func lanzar_nueva_pelota(posicion_pantalla: Vector2) -> void:
	if pelotas_restantes <= 0:
		return

	if not camara or not escena_pelota or not raycast_apuntado:
		return

	pelotas_restantes -= 1
	actualizar_ui_pelotas()

	var fuerza_calculada: float = obtener_fuerza_actual()

	var nueva_pelota = escena_pelota.instantiate() as RigidBody3D
	contenedor_pelotas.add_child(nueva_pelota)

	var punto_salida = camara.global_position - camara.global_transform.basis.z * 1.0
	nueva_pelota.global_position = punto_salida
	nueva_pelota.freeze = false

	var origen_rayo = camara.project_ray_origin(posicion_pantalla)
	var direccion_rayo = camara.project_ray_normal(posicion_pantalla)

	raycast_apuntado.global_position = origen_rayo
	raycast_apuntado.target_position = direccion_rayo * 100.0
	raycast_apuntado.force_raycast_update()

	var punto_objetivo_real: Vector3 = origen_rayo + direccion_rayo * 100.0
	if raycast_apuntado.is_colliding():
		punto_objetivo_real = raycast_apuntado.get_collision_point()

	var direccion_final = (punto_objetivo_real - nueva_pelota.global_position).normalized()

	nueva_pelota.apply_central_impulse(direccion_final * fuerza_calculada * nueva_pelota.mass)
	get_tree().create_timer(6.0).timeout.connect(nueva_pelota.queue_free)
	
	if pelotas_restantes == 0:
		esperando_fin_nivel = true
		# Esperar 5 segundos exactos desde el lanzamiento de la última pelota
		get_tree().create_timer(3.0).timeout.connect(_on_tiempo_fin_nivel_agotado)

func _on_tiempo_fin_nivel_agotado() -> void:
	# Solo mostramos el panel si seguimos en el mismo intento/nivel (por si el jugador reinició antes)
	if esperando_fin_nivel and pelotas_restantes == 0:
		mostrar_panel_resultados()

func reiniciar_nivel() -> void:
	cargar_nivel(nivel_actual)

func actualizar_ui_pelotas() -> void:
	if label_pelotas:
		label_pelotas.text = "x %d" % pelotas_restantes

func actualizar_ui_puntaje() -> void:
	if label_puntaje:
		# Formato de 4 dígitos (ej: SCORE: 0100)
		label_puntaje.text = "SCORE: " + str(puntaje_nivel)

func crear_efecto_puntos(posicion_lata_3d: Vector3, valor_puntos: int) -> void:
	if not camara or not escena_puntos_flotantes or not barra_energia:
		return

	# A. Instanciar la escena y agregarla al CanvasLayer UI
	var efecto = escena_puntos_flotantes.instantiate()
	var ui_node = barra_energia.get_parent()
	ui_node.add_child(efecto)

	# B. Configurar el texto
	var label = efecto.get_node("Label") as Label
	label.text = "+%d" % valor_puntos
	
	# Opcional: Cambiar color según puntos (ej: amarillo para > 100)
	if valor_puntos > 100:
		label.modulate = Color(1.0, 0.9, 0.0) # Amarillo/Dorado

	# C. Calcular la posición inicial en pantalla
	# Tomamos la posición de la lata e inclinamos el punto inicial un poco hacia arriba en 3D
	var posicion_3d_objetivo = posicion_lata_3d + Vector3(0.0, 0.3, 0.0)
	var posicion_pantalla = camara.unproject_position(posicion_3d_objetivo)
	efecto.position = posicion_pantalla

	# D. CREAR LA ANIMACIÓN CON TWEEN
	# Usamos un solo Tween que se auto-destruye al terminar
	var tween = create_tween()
	
	# Animación 1: Mover hacia arriba (reducir position.y) en 1.5 segundos
	var posicion_final_y = posicion_pantalla.y - 60.0
	tween.tween_property(efecto, "position:y", posicion_final_y, 1.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Animación 2 (en paralelo): Desvanecer (modulate.a -> 0)
	# set_parallel(true) hace que las siguientes animaciones ocurran simultáneamente
	tween.set_parallel(true)
	tween.tween_property(efecto, "modulate:a", 0.0, 1.5)\
		.set_trans(Tween.TRANS_LINEAR)

	# E. Eliminar el nodo de la interfaz cuando la animación termine
	tween.chain().tween_callback(efecto.queue_free)

func mostrar_panel_resultados() -> void:		
	# 1. Ocultar los elementos de la interfaz de juego (HUD)
	if barra_energia: barra_energia.visible = false
	if label_puntaje: label_puntaje.visible = false
	if contenedor_pelotas_ui: contenedor_pelotas_ui.visible = false

	if label_puntaje_final:
		label_puntaje_final.text = "%d / %d" % [puntaje_nivel, puntaje_maximo_nivel]

	var umbral_1: float = puntaje_maximo_nivel * (1.0 / 3.0) # 33.3%
	var umbral_2: float = puntaje_maximo_nivel * (2.0 / 3.0) # 66.6%
	var umbral_3: float = float(puntaje_maximo_nivel)        # 100%
	
	gano_ribbon_amarilla = (puntaje_nivel >= umbral_1)
	gano_ribbon_roja = (puntaje_nivel >= umbral_2)
	gano_ribbon_azul = (puntaje_nivel >= umbral_3)

	ribbon_amarilla.visible = gano_ribbon_amarilla
	ribbon_roja.visible = gano_ribbon_roja
	ribbon_azul.visible = gano_ribbon_azul
	
	SaveManager.registrar_puntaje_nivel(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)
	
	if panel_resultados: 
		panel_resultados.visible = true
		animar_aparicion_panel(panel_resultados)

func _on_boton_reiniciar_pressed() -> void:
	# 1. Ocultar el panel de resultados
	if panel_resultados:
		panel_resultados.visible = false
	
	# 2. Resetear la bandera
	esperando_fin_nivel = false
	
	# 3. Recargar el nivel (esto limpia pelotas, repone latas y resetea el contador a 3)
	cargar_nivel(nivel_actual)

func _on_boton_home_pressed() -> void:
	# Si hay un premio recien desbloqueado, mostramos la pantalla de premio primero
	if SaveManager.premio_recien_desbloqueado != "":
		get_tree().change_scene_to_file("res://scenes/PremioDesbloqueado.tscn")
	else:
		# Si no hay premio, va directamente a la pantalla de niveles
		get_tree().change_scene_to_file("res://scenes/SeleccionNiveles.tscn")

func animar_aparicion_panel(panel: Control) -> void:
	ribbon_amarilla.scale = Vector2.ZERO
	ribbon_roja.scale = Vector2.ZERO
	ribbon_azul.scale = Vector2.ZERO
	
# 1. Animar FondoDesenfoque (Fade-in simple)
	fondo_desenfoque.modulate.a = 0.0
	var tween_desenfoque = create_tween()
	tween_desenfoque.tween_property(fondo_desenfoque, "modulate:a", 1.0, 0.2)

	# --- ANIMACIÓN DE FONDOPANEL ---
	# Esperar 1 frame para que Godot calcule el tamaño y posición exactos del panel
	await get_tree().process_frame

	# Guardar la escala real que configuraste en el editor
	var escala_original = fondo_panel.scale

	# Fijar el pivote en el centro exacto
	fondo_panel.pivot_offset = fondo_panel.size / 2

	# Iniciar al 80% de SU escala original
	fondo_panel.scale = escala_original * 0.8
	fondo_panel.modulate.a = 0.0

	# Animar hacia SU escala original
	var tween_panel = create_tween().set_parallel(true)
	tween_panel.set_trans(Tween.TRANS_BACK) # Rebote sutil
	tween_panel.set_ease(Tween.EASE_OUT)

	tween_panel.tween_property(fondo_panel, "scale", escala_original, 1)
	tween_panel.tween_property(fondo_panel, "modulate:a", 1, 1)
	
	await tween_panel.finished # Espera a que el panel termine de crecer

	if gano_ribbon_amarilla:
		animar_pop_ribbon(ribbon_amarilla, escala_orig_amarilla)
		await get_tree().create_timer(0.12).timeout # Pequeño delay entre ribbons
		
	if gano_ribbon_roja:
		animar_pop_ribbon(ribbon_roja, escala_orig_roja)
		await get_tree().create_timer(0.12).timeout
		
	if gano_ribbon_azul:
		animar_pop_ribbon(ribbon_azul, escala_orig_azul)

func animar_pop_ribbon(ribbon: Control, escala_objetivo: Vector2) -> void:
	# Restablecer posición y asegurar estado inicial
	ribbon.scale = Vector2.ZERO
	ribbon.visible = true
	var tween = create_tween()

	# Paso A: Crece del 0% al 110% de su escala guardada
	tween.tween_property(ribbon, "scale", escala_objetivo * 1.1, 0.18)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# Paso B: Se asienta exactamente en su escala guardada (100%)
	tween.tween_property(ribbon, "scale", escala_objetivo, 0.10)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)

func aplicar_material_lata(nuevo_objeto: Node3D, datos_tipo: Dictionary) -> void:
	var mesh_instance = nuevo_objeto.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance or not mesh_instance.mesh:
		return
		
	# 1. Obtener los radios reales de la malla del objeto (ej. CylinderMesh)
	var cylinder_mesh = mesh_instance.mesh as CylinderMesh
	var r_top: float = 0.5
	var r_bottom: float = 0.5
	
	if cylinder_mesh:
		r_top = cylinder_mesh.top_radius
		r_bottom = cylinder_mesh.bottom_radius

	# 2. Obtener el material Shader
	var mat_base = mesh_instance.get_active_material(0)
	if not mat_base:
		mat_base = mesh_instance.material_override
		
	if mat_base is ShaderMaterial:
		# Duplicar material para que cada lata mantenga sus parámetros independientes
		var mat_instancia = mat_base.duplicate() as ShaderMaterial
		
		# 3. Asignar radios al Shader para centrado perfecto de tapas
		mat_instancia.set_shader_parameter("top_radius", r_top)
		mat_instancia.set_shader_parameter("bottom_radius", r_bottom)
		
		# 4. Cargar tapas globales (PNG o JPG según disponibilidad)
		var ruta_top = CARPETA_CANS + "can_top.png"
		var ruta_bottom = CARPETA_CANS + "can_bottom.png"
		
		if not ResourceLoader.exists(ruta_bottom):
			ruta_bottom = CARPETA_CANS + "can_bottom.jpg"
			
		if ResourceLoader.exists(ruta_top):
			mat_instancia.set_shader_parameter("tex_top", load(ruta_top))
		if ResourceLoader.exists(ruta_bottom):
			mat_instancia.set_shader_parameter("tex_bottom", load(ruta_bottom))
			
		# 5. Cargar la textura lateral configurada en valores.json
		var nombre_textura = datos_tipo.get("textura", "")
		if nombre_textura != "":
			var ruta_cuerpo = CARPETA_CANS + nombre_textura
			if ResourceLoader.exists(ruta_cuerpo):
				mat_instancia.set_shader_parameter("tex_side", load(ruta_cuerpo))
		
		# 6. Mapear escala y desfase lateral desde valores.json
		var scale_arr = datos_tipo.get("uv_scale_side", [1.0, 1.0])
		var offset_arr = datos_tipo.get("uv_offset_side", [0.0, 0.0])
		
		mat_instancia.set_shader_parameter("uv_scale_side", Vector2(scale_arr[0], scale_arr[1]))
		mat_instancia.set_shader_parameter("uv_offset_side", Vector2(offset_arr[0], offset_arr[1]))
		
		mesh_instance.material_override = mat_instancia
