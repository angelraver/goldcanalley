extends Node

const RUTA_GUARDADO = "user://progreso.json"
const RUTA_NIVELES_JSON = "res://data/niveles.json" # Ajusta tu ruta de niveles.json

# Lista global única de premios en el orden correcto
const LISTA_PREMIOS: Array[String] = [
	"aros", "dino", "drum",
	"doll", "robot", "duck",
	"auto2", "tricep", "horse",
	"bunny", "plane", "train",
	"rocket", "robot2", "teddy",
	"auto", "astro", "rex"
]

var datos_progreso: Dictionary = {}
var nivel_actual_seleccionado: int = 1

# Guardará el nombre del premio si se desbloqueó uno nuevo en esta partida
var premio_recien_desbloqueado: String = ""


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
	# 1. Contar premios desbloqueados ANTES de actualizar
	var premios_antes = calcular_cantidad_premios_desbloqueados()

	if nuevo_puntaje > puntaje_previo:
		datos_progreso[clave] = {
			"score": nuevo_puntaje,
			"max": puntaje_maximo
		}
		guardar_a_disco()

		# 2. Contar premios desbloqueados DESPUÉS de actualizar
		var premios_despues = calcular_cantidad_premios_desbloqueados()

		# 3. Si incrementó la cantidad, guardamos cuál fue el nuevo premio desbloqueado
		if premios_despues > premios_antes and premios_despues <= LISTA_PREMIOS.size():
			premio_recien_desbloqueado = LISTA_PREMIOS[premios_despues - 1]

		return true

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


func contar_ribbons_azules() -> int:
	var conteo: int = 0
	for clave in datos_progreso.keys():
		var info = datos_progreso[clave]
		var score = int(info.get("score", 0))
		var max_score = int(info.get("max", 0))
		if max_score > 0 and score >= max_score:
			conteo += 1
	return conteo


func obtener_total_niveles() -> int:
	if FileAccess.file_exists(RUTA_NIVELES_JSON):
		var texto = FileAccess.get_file_as_string(RUTA_NIVELES_JSON)
		var datos = JSON.parse_string(texto)
		if datos is Dictionary:
			return datos.keys().size()
	return 18


func calcular_cantidad_premios_desbloqueados() -> int:
	var azules = contar_ribbons_azules()
	var total_niveles = obtener_total_niveles()
	var cantidad_desbloqueada: int = 0

	for i in range(LISTA_PREMIOS.size()):
		var numero_premio = i + 1
		var requeridas: int = int(ceil(float(numero_premio) * float(total_niveles) / 18.0))
		if azules >= requeridas:
			cantidad_desbloqueada += 1

	return cantidad_desbloqueada

# --- GESTIÓN DE CONFIGURACIÓN Y PREFERENCIAS ---

# Retorna la configuración guardada o un valor por defecto si no existe aún
func obtener_opcion_audio(clave: String, valor_defecto: bool = true) -> bool:
	if datos_progreso.has("opciones") and datos_progreso["opciones"] is Dictionary:
		return datos_progreso["opciones"].get(clave, valor_defecto)
	return valor_defecto

# Guarda una opción específica y escribe inmediatamente a disco
func guardar_opcion_audio(clave: String, valor: bool) -> void:
	if not datos_progreso.has("opciones") or not (datos_progreso["opciones"] is Dictionary):
		datos_progreso["opciones"] = {}
		
	datos_progreso["opciones"][clave] = valor
	guardar_a_disco()
