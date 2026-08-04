extends Control

# Lista fija de los 18 premios en el orden especificado
const LISTA_PREMIOS: Array[String] = [
	"aros", "astro", "auto2", "auto", "bunny", "dino",
	"doll", "drumb", "duck", "horse", "plane", "rex",
	"robot2", "robot", "rocket", "teddy", "tricep", "duck2"
]

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
	var total_niveles = obtener_total_niveles()
	var ribbons_azules_obtenidas = contar_ribbons_azules()

	print("🏆 Ribbons Azules: ", ribbons_azules_obtenidas, " / Total Niveles: ", total_niveles)

	# 3. Generar dinámicamente los 18 premios
	for i in range(LISTA_PREMIOS.size()):
		var numero_premio = i + 1 # De 1 a 18
		var nombre_premio = LISTA_PREMIOS[i]

		# Calcular cuántas ribbons exige este premio específico
		var ribbons_necesarias: int = 1
		if total_niveles > 0:
			ribbons_necesarias = int(ceil(float(numero_premio) * float(total_niveles) / 18.0))

		var desbloqueado: bool = (ribbons_azules_obtenidas >= ribbons_necesarias)

		# Crear el contenedor del premio
		var slot_premio = crear_slot_premio(nombre_premio, desbloqueado, ribbons_azules_obtenidas, ribbons_necesarias)
		grid_premios.add_child(slot_premio)


func contar_ribbons_azules() -> int:
	var conteo: int = 0
	var datos = SaveManager.datos_progreso

	for clave_nivel in datos.keys():
		var info = datos[clave_nivel]
		var score = int(info.get("score", 0))
		var max_score = int(info.get("max", 0))

		# Ribbon azul = Nivel completado con el 100% de los puntos
		if max_score > 0 and score >= max_score:
			conteo += 1

	return conteo


func obtener_total_niveles() -> int:
	if not FileAccess.file_exists(RUTA_NIVELES_JSON):
		return 18 # Valor de respaldo si no encuentra el JSON

	var texto = FileAccess.get_file_as_string(RUTA_NIVELES_JSON)
	var datos = JSON.parse_string(texto)
	if datos is Dictionary:
		return datos.keys().size()

	return 18


func crear_slot_premio(nombre_png: String, desbloqueado: bool, actuales: int, requeridas: int) -> Control:
	# Contenedor individual para cada casillero
	var contenedor = Control.new()
	contenedor.custom_minimum_size = Vector2(120, 120) # Ajusta al tamaño de tus celdas

	var imagen = TextureRect.new()
	var ruta_imagen = CARPETA_PREMIOS + nombre_png + ".png"

	if ResourceLoader.exists(ruta_imagen):
		imagen.texture = load(ruta_imagen)
	
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagen.set_anchors_preset(Control.PRESET_FULL_RECT)

	if desbloqueado:
		# Premio Desbloqueado: Color original brillante
		imagen.modulate = Color.WHITE
	else:
		# Premio Bloqueado: Silueta oscura semi-transparente
		imagen.modulate = Color(0.05, 0.05, 0.05, 0.5)

		# Opcional: Mostrar texto flotante con progreso (ej. "3 / 5")
		var label_progreso = Label.new()
		label_progreso.text = "%d/%d 🏆" % [actuales, requeridas]
		label_progreso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label_progreso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label_progreso.set_anchors_preset(Control.PRESET_FULL_RECT)
		label_progreso.modulate = Color(1.0, 0.85, 0.4, 0.9) # Color dorado
		label_progreso.add_theme_font_size_override("font_size", 14)
		contenedor.add_child(label_progreso)

	contenedor.add_child(imagen)
	return contenedor

func _on_boton_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
