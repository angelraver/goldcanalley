extends Control

const CARPETA_PREMIOS = "res://images/prizes/"
const RUTA_NIVELES_JSON = "res://data/niveles.json" # Ajusta tu ruta

@onready var grid_premios: GridContainer = $ScrollContainer/ContenidoEstanteria/GridPremios

func _ready() -> void:
	refrescar_estanteria()


func refrescar_estanteria() -> void:
	# 1. Limpiar slots previos si los hubiera
	for child in grid_premios.get_children():
		child.queue_free()

	# 2. Calcular datos del usuario y del juego
	var total_niveles = SaveManager.obtener_total_niveles()
	var ribbons_azules_obtenidas = SaveManager.contar_ribbons_azules()

	# 3. Generar dinámicamente los 18 premios
	for i in range(SaveManager.LISTA_PREMIOS.size()):
		var numero_premio = i + 1 # De 1 a 18
		var nombre_premio = SaveManager.LISTA_PREMIOS[i]

		# Calcular cuántas ribbons exige este premio específico
		var ribbons_necesarias: int = 1
		if total_niveles > 0:
			ribbons_necesarias = int(ceil(float(numero_premio) * float(total_niveles) / 18.0))

		var desbloqueado: bool = (ribbons_azules_obtenidas >= ribbons_necesarias)

		# Crear el contenedor del premio
		var slot_premio = crear_slot_premio(nombre_premio, desbloqueado, ribbons_azules_obtenidas, ribbons_necesarias)
		grid_premios.add_child(slot_premio)

const RUTA_RIBBON_AZUL = "res://images/ribbon_tiny_blue.png"
func crear_slot_premio(nombre_png: String, desbloqueado: bool, actuales: int, requeridas: int) -> Control:
	var contenedor = Control.new()
	contenedor.custom_minimum_size = Vector2(120, 120)

	var imagen = TextureRect.new()
	var ruta_imagen = CARPETA_PREMIOS + nombre_png + ".png"

	if ResourceLoader.exists(ruta_imagen):
		imagen.texture = load(ruta_imagen)
	
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.set_anchors_preset(Control.PRESET_FULL_RECT)

	contenedor.add_child(imagen)

	if desbloqueado:
		imagen.modulate = Color.WHITE
	else:
		# Premio Bloqueado: Silueta oscura semi-transparente
		imagen.modulate = Color(0.05, 0.05, 0.05, 0.5)

		# --- CONTENEDOR HORIZONTAL (TEXTO + ICONO RIBBON) ---
		var hbox_progreso = HBoxContainer.new()
		hbox_progreso.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox_progreso.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox_progreso.add_theme_constant_override("separation", 6) # Separación entre texto e icono

		# 1. Texto de números (ej. "9/20")
		var label_progreso = Label.new()
		label_progreso.text = "%d/%d" % [actuales, requeridas]
		label_progreso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_progreso.modulate = Color(1.0, 0.85, 0.4, 0.9) # Tono dorado
		label_progreso.add_theme_font_size_override("font_size", 14)

		# 2. Icono PNG de la Ribbon Azul
		var icono_ribbon = TextureRect.new()
		if ResourceLoader.exists(RUTA_RIBBON_AZUL):
			icono_ribbon.texture = load(RUTA_RIBBON_AZUL)
		
		icono_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono_ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono_ribbon.custom_minimum_size = Vector2(22, 22) # Tamaño del icono en la celda

		hbox_progreso.add_child(label_progreso)
		hbox_progreso.add_child(icono_ribbon)
		contenedor.add_child(hbox_progreso)

	return contenedor

func _on_boton_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
