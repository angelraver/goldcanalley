extends Node3D

@export_file("*.json") var ruta_niveles_json: String = "res://games/goldcanalley/data/niveles.json"
@export_file("*.json") var ruta_valores_json: String = "res://games/goldcanalley/data/valores.json"
@export var catalogo_objetos: Dictionary = {
	"lata_aluminio": preload("res://games/goldcanalley/scenes/lata.tscn")
}
@export var escena_pelota: PackedScene = preload("res://games/goldcanalley/scenes/pelota.tscn")
@export var nivel_actual: int = 1
@export var origen_mesa: Vector3 = Vector3(0.0, 0.8, -4.0)
@export var tamano_celda: Vector3 = Vector3(0.22, 0.31, 0.22)
@export var fuerza_minima: float = 5.0
@export var fuerza_maxima: float = 30.0
@export var velocidad_oscilacion: float = 0.8
@export var pelotas_maximas: int = 3

@onready var camara: Camera3D = $Camera3D
@onready var raycast_apuntado: RayCast3D = $RayCastApuntado
@onready var ui_puntaje: UIPuntaje = $UI/Puntaje as UIPuntaje
@onready var ui_level_number: UILevelNumber = $UI/LevelNumber as UILevelNumber
@onready var ui_level_title: Label = $UI/LevelTitle
@onready var ui_label_pelotas: Label = $UI/ContenedorPelotasUI/LabelPelotas
@onready var barra_energia: Control = $UI/BarraEnergia
@onready var indicador_circulo: Control = $UI/BarraEnergia/IndicadorCirculo
@onready var pelota_ui_3d: Node3D = $UI/ContenedorPelotasUI/SubViewportContainer/SubViewport/PelotaUI
@onready var contenedor_pelotas_ui: Control = $UI/ContenedorPelotasUI
@onready var panel_resultados: PanelResultados = $UI/PanelResultados as PanelResultados
@onready var audio_juego: GameAudioBase = $AudioJuego

const CARPETA_CANS = "res://games/goldcanalley/assets/images/cans/"
var valores_objetos: Dictionary = {}
var puntaje_nivel: int = 0
var contenedor_latas: Node3D
var contenedor_pelotas: Node3D
var tiempo_barra: float = 0.0
var pelotas_restantes: int = 3
var esperando_fin_nivel: bool = false
var puntaje_maximo_nivel: int = 0
var pos_final_camara: Vector3 = Vector3(0.0, 1.443, -0.31)
var rot_final_camara: Vector3 = Vector3(deg_to_rad(-0.5), 0.0, 0.0)
var pos_inicial_camara: Vector3 = Vector3(0.0, 3.8, -3.8)
var rot_inicial_camara: Vector3 = Vector3(deg_to_rad(-85.0), 0.0, 0.0)
var controles_activos: bool = false
var ctrl_resultados: ControladorResultados

func _ready() -> void:
	contenedor_latas = Node3D.new()
	contenedor_latas.name = "ContenedorLatas"
	add_child(contenedor_latas)

	contenedor_pelotas = Node3D.new()
	contenedor_pelotas.name = "ContenedorPelotas"
	add_child(contenedor_pelotas)
	
	cargar_valores()
	nivel_actual = save_manager.nivel_actual_seleccionado

	ctrl_resultados = ControladorResultados.new()
	add_child(ctrl_resultados)
	var hud: Array = [barra_energia, ui_puntaje, ui_level_number, contenedor_pelotas_ui]
	ctrl_resultados.configurar(panel_resultados, hud, ui_puntaje, ui_level_number, reiniciar_nivel)

	cargar_nivel(nivel_actual)

func _physics_process(_delta: float) -> void:
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
	ctrl_resultados.reset()

	esperando_fin_nivel = false
	pelotas_restantes = pelotas_maximas
	actualizar_ui_pelotas()
	puntaje_nivel = 0
	puntaje_maximo_nivel = 0
	actualizar_ui_puntaje()
	actualizar_ui_level()

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

		var factor_ancho: float = float(datos_tipo.get("ancho", 1.0))
		var factor_alto: float = float(datos_tipo.get("alto", 1.0))
		var masa_objeto: float = float(datos_tipo.get("masa", 1.0))
		var puntos_objeto: int = int(datos_tipo.get("pts", 100))

		var escala_vector = Vector3(factor_ancho, factor_alto, factor_ancho)

		var paso_celda = Vector3(
			tamano_celda.x * escala_vector.x,
			tamano_celda.y * escala_vector.y,
			tamano_celda.z * escala_vector.z
		)

		puntaje_maximo_nivel += puntos_objeto
		var pos_x = origen_mesa.x + (grid_x - 5.0) * paso_celda.x
		var pos_y = origen_mesa.y + (grid_y - 0.5) * paso_celda.y + 0.005
		var pos_z = origen_mesa.z - (grid_z - 1.0) * paso_celda.z

		var nuevo_objeto = escena_objetivo.instantiate() as RigidBody3D
		nuevo_objeto.scale = escala_vector
		nuevo_objeto.mass = masa_objeto
		nuevo_objeto.audio = audio_juego
		nuevo_objeto.set_meta("tipo", clave_tipo)
		nuevo_objeto.set_meta("derribado", false)

		aplicar_material_lata(nuevo_objeto, datos_tipo)

		contenedor_latas.add_child(nuevo_objeto)
		nuevo_objeto.global_position = Vector3(pos_x, pos_y, pos_z)

	anunciar_nivel(numero_nivel)
	animar_camara_entrada()

func verificar_latas_derribadas() -> void:
	for obj in contenedor_latas.get_children():
		if not (obj is RigidBody3D):
			continue

		if obj.get_meta("derribado", false):
			continue

		var tipo: String = obj.get_meta("tipo", "lata_aluminio")
		var esta_derribada: bool = false

		var esta_caida: bool = obj.global_position.y < (origen_mesa.y - 0.15)

		var vector_arriba_lata = obj.global_transform.basis.y
		var inclinacion = vector_arriba_lata.dot(Vector3.UP)
		var esta_tumbada: bool = inclinacion < 0.707

		if esta_caida or esta_tumbada:
			esta_derribada = true

		if esta_derribada:
			obj.set_meta("derribado", true)

			var datos_tipo = valores_objetos.get(tipo, {})
			var puntos_ganados: int = int(datos_tipo.get("pts", 0))

			puntaje_nivel += puntos_ganados
			actualizar_ui_puntaje()
			EfectosUI.crear_efecto_puntos(obj.global_position, puntos_ganados)

			if not esperando_fin_nivel and puntaje_nivel >= puntaje_maximo_nivel:
				esperando_fin_nivel = true
				get_tree().create_timer(2.0).timeout.connect(_finalizar_por_victoria_perfecta)

func _finalizar_por_victoria_perfecta() -> void:
	if esperando_fin_nivel:
		mostrar_panel_resultados()

func animar_camara_entrada() -> void:
	if barra_energia: barra_energia.visible = false
	if ui_puntaje: ui_puntaje.visible = false
	if ui_level_number: ui_level_number.visible = true
	if contenedor_pelotas_ui: contenedor_pelotas_ui.visible = false
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
		if ui_puntaje: ui_puntaje.visible = true
		if ui_level_number: ui_level_number.visible = true
		if contenedor_pelotas_ui: contenedor_pelotas_ui.visible = true
	)

func _unhandled_input(event: InputEvent) -> void:
	if not controles_activos:
		return

	if OS.has_feature("mobile"):
		if event is InputEventScreenTouch and event.pressed:
			lanzar_nueva_pelota(event.position)
	else:
		if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
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

	if pelotas_restantes > 0:
		audio_juego.play_shot()

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
		get_tree().create_timer(3.0).timeout.connect(_on_tiempo_fin_nivel_agotado)

func _on_tiempo_fin_nivel_agotado() -> void:
	if esperando_fin_nivel:
		mostrar_panel_resultados()

func reiniciar_nivel() -> void:
	cargar_nivel(nivel_actual)

func actualizar_ui_pelotas() -> void:
	if ui_label_pelotas:
		ui_label_pelotas.text = "x %d" % pelotas_restantes

func actualizar_ui_puntaje() -> void:
	ctrl_resultados.actualizar_puntaje(puntaje_nivel)

func actualizar_ui_level() -> void:
	ctrl_resultados.actualizar_nivel(nivel_actual)

func mostrar_panel_resultados() -> void:
	ctrl_resultados.mostrar(nivel_actual, puntaje_nivel, puntaje_maximo_nivel)

func aplicar_material_lata(nuevo_objeto: Node3D, datos_tipo: Dictionary) -> void:
	var mesh_instance = nuevo_objeto.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance or not mesh_instance.mesh:
		return
		
	var cylinder_mesh = mesh_instance.mesh as CylinderMesh
	var r_top: float = 0.5
	var r_bottom: float = 0.5
	
	if cylinder_mesh:
		r_top = cylinder_mesh.top_radius
		r_bottom = cylinder_mesh.bottom_radius

	var mat_base = mesh_instance.get_active_material(0)
	if not mat_base:
		mat_base = mesh_instance.material_override
		
	if mat_base is ShaderMaterial:
		var mat_instancia = mat_base.duplicate() as ShaderMaterial
		
		mat_instancia.set_shader_parameter("top_radius", r_top)
		mat_instancia.set_shader_parameter("bottom_radius", r_bottom)
		
		var ruta_top = CARPETA_CANS + "can_top.png"
		var ruta_bottom = CARPETA_CANS + "can_bottom.png"
		
		if not ResourceLoader.exists(ruta_bottom):
			ruta_bottom = CARPETA_CANS + "can_bottom.jpg"
			
		if ResourceLoader.exists(ruta_top):
			mat_instancia.set_shader_parameter("tex_top", load(ruta_top))
		if ResourceLoader.exists(ruta_bottom):
			mat_instancia.set_shader_parameter("tex_bottom", load(ruta_bottom))
			
		var nombre_textura = datos_tipo.get("textura", "")
		if nombre_textura != "":
			var ruta_cuerpo = CARPETA_CANS + nombre_textura
			if ResourceLoader.exists(ruta_cuerpo):
				mat_instancia.set_shader_parameter("tex_side", load(ruta_cuerpo))
		
		var scale_arr = datos_tipo.get("uv_scale_side", [1.0, 1.0])
		var offset_arr = datos_tipo.get("uv_offset_side", [0.0, 0.0])
		
		mat_instancia.set_shader_parameter("uv_scale_side", Vector2(scale_arr[0], scale_arr[1]))
		mat_instancia.set_shader_parameter("uv_offset_side", Vector2(offset_arr[0], offset_arr[1]))
		
		mesh_instance.material_override = mat_instancia

func anunciar_nivel(numero_nivel: int) -> void:
	ui_level_title.text = game_manager.obtener_titulo_nivel(str(numero_nivel))
	ui_level_title.modulate.a = 1.0
	ui_level_title.visible = true
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(ui_level_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): ui_level_title.visible = false)
