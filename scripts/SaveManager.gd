extends Node

const RUTA_GUARDADO = "user://progreso.json"

# Estructura interna: {"1": {"score": 90, "max": 90}, "2": {"score": 40, "max": 100}}
var datos_progreso: Dictionary = {}
var nivel_actual_seleccionado: int = 1

func _ready() -> void:
	cargar_progreso()


func cargar_progreso() -> void:
	if not FileAccess.file_exists(RUTA_GUARDADO):
		datos_progreso = {}
		guardar_a_disco()
		return

	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if archivo:
		var texto = archivo.get_as_text()
		archivo.close()
		var resultado = JSON.parse_string(texto)
		if resultado is Dictionary:
			datos_progreso = resultado


func guardar_a_disco() -> void:
	var archivo = FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if archivo:
		var json_texto = JSON.stringify(datos_progreso, "\t")
		archivo.store_string(json_texto)
		archivo.close()


# Guarda o actualiza el nivel SOLO SI el nuevo puntaje es mayor al registrado
func registrar_puntaje_nivel(numero_nivel: int, nuevo_puntaje: int, puntaje_maximo: int) -> bool:
	var clave = str(numero_nivel)
	var puntaje_previo = obtener_puntaje_nivel(numero_nivel)

	if nuevo_puntaje > puntaje_previo:
		datos_progreso[clave] = {
			"score": nuevo_puntaje,
			"max": puntaje_maximo
		}
		guardar_a_disco()
		return true # Indica que se superó el récord
	
	return false


func obtener_puntaje_nivel(numero_nivel: int) -> int:
	var clave = str(numero_nivel)
	if datos_progreso.has(clave):
		return int(datos_progreso[clave].get("score", 0))
	return 0


func obtener_maximo_nivel(numero_nivel: int) -> int:
	var clave = str(numero_nivel)
	if datos_progreso.has(clave):
		return int(datos_progreso[clave].get("max", 0))
	return 0


# Un nivel N está desbloqueado si es el Nivel 1 O si el Nivel N-1 tiene al menos 1 ribbon
func es_nivel_desbloqueado(numero_nivel: int) -> bool:
	if numero_nivel == 1:
		return true

	var clave_anterior = str(numero_nivel - 1)
	if not datos_progreso.has(clave_anterior):
		return false

	var datos_prev = datos_progreso[clave_anterior]
	var score_prev = float(datos_prev.get("score", 0))
	var max_prev = float(datos_prev.get("max", 1))

	# 1/3 (33.3%) equivale a conseguir al menos la Ribbon Amarilla
	return (score_prev / max_prev) >= (1.0 / 3.0)
