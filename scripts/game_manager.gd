extends Node

# Variable global con el idioma hardcodeado por ahora ("es", "en", "pt")
var idioma_actual: String = "es"

# Diccionario o referencia a tu JSON cargado
var titulos_niveles: Dictionary = {}

func _ready() -> void:
	idioma_actual = save_manager.obtener_idioma_guardado()
	cargar_titulos()

func cambiar_idioma(nuevo_idioma: String) -> void:
	idioma_actual = nuevo_idioma
	save_manager.guardar_idioma(nuevo_idioma)

func cargar_titulos() -> void:
	# Carga del JSON con las traducciones de títulos
	if FileAccess.file_exists("res://data/titulos_niveles.json"):
		var file = FileAccess.open("res://data/titulos_niveles.json", FileAccess.READ)
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			titulos_niveles = parsed

# Función global para obtener el título en el idioma activo
func obtener_titulo_nivel(id_nivel: String) -> String:
	if titulos_niveles.has(id_nivel):
		var nivel_data = titulos_niveles[id_nivel]
		# Retorna el idioma activo, si no existe cae en español por defecto
		return nivel_data.get(idioma_actual, nivel_data.get("es", ""))
	return ""
