extends RigidBody3D

@export var umbral_velocidad: float = 0.8
@export var tiempo_cooldown: float = 0.1

var puede_sonar: bool = true

# Lista con los nombres exactos de las funciones en AudioManager
const SONIDOS_LATA: Array[String] = [
	"play_lata1",
	"play_lata2",
	"play_lata3",
	"play_lata4",
	"play_lata5",
	"play_lata6",
	"play_lata7",
	"play_lata8"
]

func _ready() -> void:
	# 1. Configurar físicas para que emitan eventos de contacto
	contact_monitor = true
	max_contacts_reported = 4
	
	# 2. Conectar el evento de choque
	body_entered.connect(_on_body_entered)

func _on_body_entered(_cuerpo: Node) -> void:
	if not puede_sonar:
		return

	# Solo suena si el impacto lleva fuerza/velocidad
	if linear_velocity.length() > umbral_velocidad:
		puede_sonar = false
		reproducir_sonido_azar()

		# Control de cooldown para evitar saturación
		get_tree().create_timer(tiempo_cooldown).timeout.connect(
			func(): puede_sonar = true
		)

func reproducir_sonido_azar() -> void:
	if SONIDOS_LATA.is_empty():
		return
		
	# Pick random selecciona un elemento al azar del Array
	var nombre_funcion: String = SONIDOS_LATA.pick_random()
	
	# Llama a la función dinámicamente en AudioManager si existe
	if AudioManager.has_method(nombre_funcion):
		AudioManager.call(nombre_funcion)
