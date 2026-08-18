extends Control

@onready var boton_prev: TextureButton = $Frente/BotonPrev
@onready var boton_next: TextureButton = $Frente/BotonNext
@onready var select_level: Label = $Frente/LevelSelection

var pagina_actual: int = 1
var total_niveles: int = 0
const NIVELES_POR_PAGINA: int = 9

# Ruta a tu archivo de configuración de niveles
var ruta_niveles_json: String = "res://games/goldcanalley/data/niveles.json"


func _ready() -> void:
	# 1. Obtener la cantidad total de niveles definidos en el JSON
	total_niveles = obtener_total_niveles()

	# 2. Determinar la página inicial basada en el último nivel seleccionado
	if save_manager and save_manager.nivel_actual_seleccionado > 0:
		pagina_actual = int(ceil(float(save_manager.nivel_actual_seleccionado) / float(NIVELES_POR_PAGINA)))
		if pagina_actual < 1:
			pagina_actual = 1

	# 3. Conectar señales de los botones si existen
	if boton_prev and not boton_prev.pressed.is_connected(_on_boton_prev_pressed):
		boton_prev.pressed.connect(_on_boton_prev_pressed)

	if boton_next and not boton_next.pressed.is_connected(_on_boton_next_pressed):
		boton_next.pressed.connect(_on_boton_next_pressed)

	# 4. Renderizar la vista inicial
	if select_level:
		select_level.text = game_manager.obtener_texto("seleccion_nivel")
	refrescar_pantalla_niveles()


func obtener_total_niveles() -> int:
	if not FileAccess.file_exists(ruta_niveles_json):
		print("ERROR: No se encontró el archivo de niveles en: ", ruta_niveles_json)
		return 0

	var texto_json = FileAccess.get_file_as_string(ruta_niveles_json)
	var datos_niveles = JSON.parse_string(texto_json)

	if datos_niveles is Dictionary:
		return datos_niveles.keys().size()

	return 0


func refrescar_pantalla_niveles() -> void:
	actualizar_visibilidad_botones()

	var contenedor_slots = $Frente/Slots  # O $Slots si Frente fuera transparente
	# Recorrer los 9 slots físicos en pantalla
	for i in range(1, NIVELES_POR_PAGINA + 1):
		var nombre_nodo = "Slot" + str(i)

		if contenedor_slots.has_node(nombre_nodo):
			var slot = contenedor_slots.get_node(nombre_nodo)
			# Calcular el número de nivel real para este slot en la página actual
			var numero_nivel_real = (pagina_actual - 1) * NIVELES_POR_PAGINA + i

			# Si el nivel existe en el JSON, lo mostramos y configuramos
			if numero_nivel_real <= total_niveles:
				slot.visible = true
				slot.configurar(numero_nivel_real)

				if not slot.nivel_seleccionado.is_connected(_on_nivel_seleccionado):
					slot.nivel_seleccionado.connect(_on_nivel_seleccionado)
			else:
				# Si la última página tiene menos de 9 niveles (ej. 12 niveles en total),
				# ocultamos los slots sobrantes (13 a 18)
				slot.visible = false

func actualizar_visibilidad_botones() -> void:
	# Calcular la cantidad total de páginas necesarias
	var total_paginas: int = int(ceil(float(total_niveles) / float(NIVELES_POR_PAGINA)))
	if total_paginas < 1:
		total_paginas = 1

	# Regra 1: BotonPrev SIEMPRE oculto en página 1, visible de página 2 en adelante
	if boton_prev:
		boton_prev.visible = (pagina_actual > 1)

	# Regla 2: BotonNext solo es visible si la página actual es menor al total de páginas
	if boton_next:
		boton_next.visible = (pagina_actual < total_paginas)

func _on_boton_prev_pressed() -> void:
	if pagina_actual > 1:
		pagina_actual -= 1
		refrescar_pantalla_niveles()


func _on_boton_next_pressed() -> void:
	var total_paginas: int = int(ceil(float(total_niveles) / float(NIVELES_POR_PAGINA)))
	if pagina_actual < total_paginas:
		pagina_actual += 1
		refrescar_pantalla_niveles()


func _on_nivel_seleccionado(numero_nivel: int) -> void:
	save_manager.nivel_actual_seleccionado = numero_nivel
	get_tree().change_scene_to_file("res://games/goldcanalley/scenes/main.tscn")

func _on_boton_home_pressed() -> void:
	get_tree().change_scene_to_file("res://core/scenes/title.tscn")
