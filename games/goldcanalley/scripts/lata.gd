extends RigidBody3D

@export var umbral_velocidad: float = 0.8
@export var tiempo_cooldown: float = 0.1

var puede_sonar: bool = true
var audio: GameAudioBase

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(_cuerpo: Node) -> void:
	if not puede_sonar:
		return

	if linear_velocity.length() > umbral_velocidad:
		puede_sonar = false
		
		# Llamada limpia y directa
		if audio:
			audio.play_lata()

		get_tree().create_timer(tiempo_cooldown).timeout.connect(
			func(): puede_sonar = true
		)
