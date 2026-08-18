extends Node

# Señal para notificar a la UI que el idioma cambió en tiempo de ejecución
signal idioma_cambiado(nuevo_idioma: String)

var idioma_actual: String = "es"

const DICCIONARIOS_LOCALIZACION: Array[Dictionary] = [
	{
		"ruta": "res://core/data/textos.json",
		"prefijo": ""
	},
	{
		"ruta": "res://games/goldcanalley/data/textos.json",
		"prefijo": "latas_"
	}
]

var textos_locales: Dictionary = {}

func _ready() -> void:
	idioma_actual = save_manager.obtener_idioma_guardado()
	cargar_todos_los_textos()

func cambiar_idioma(nuevo_idioma: String) -> void:
	if idioma_actual != nuevo_idioma:
		idioma_actual = nuevo_idioma
		save_manager.guardar_idioma(nuevo_idioma)
		idioma_cambiado.emit(nuevo_idioma)

func cargar_todos_los_textos() -> void:
	textos_locales.clear()
	
	for config in DICCIONARIOS_LOCALIZACION:
		var ruta: String = config.get("ruta", "")
		var prefijo: String = config.get("prefijo", "")
		
		if FileAccess.file_exists(ruta):
			var texto_json = FileAccess.get_file_as_string(ruta)
			var resultado = JSON.parse_string(texto_json)
			
			if resultado is Dictionary:
				for clave in resultado.keys():
					var clave_final = prefijo + str(clave)
					textos_locales[clave_final] = resultado[clave]

func obtener_texto(clave: String, texto_defecto: String = "") -> String:
	var clave_str = str(clave)
	if textos_locales.has(clave_str):
		var data_clave = textos_locales[clave_str]
		if data_clave is Dictionary:
			if data_clave.has(idioma_actual) and str(data_clave[idioma_actual]).strip_edges() != "":
				return str(data_clave[idioma_actual])
			elif data_clave.has("es") and str(data_clave["es"]).strip_edges() != "":
				return str(data_clave["es"])
				
	return texto_defecto if texto_defecto != "" else clave_str

func obtener_titulo_nivel(id_nivel: Variant, id_game: String = "latas") -> String:
	var num_str = str(id_nivel)
	var fallback_titulo = "Nivel " + num_str
	
	# 1. Intenta buscar con el prefijo asignado (ej: "latas_1")
	var clave_con_prefijo = "%s_%s" % [id_game, num_str]
	if textos_locales.has(clave_con_prefijo):
		return obtener_texto(clave_con_prefijo, fallback_titulo)
		
	# 2. Intenta buscar la clave directa sin prefijo por si acaso (ej: "1")
	if textos_locales.has(num_str):
		return obtener_texto(num_str, fallback_titulo)
		
	return fallback_titulo
