extends RigidBody3D

@export var umbral_velocidad: float = 0.8
@export var tiempo_cooldown: float = 0.1
@export var duracion_hit_stop: float = 1.0

var puede_sonar: bool = true
var audio: GameAudioBase

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(_cuerpo: Node) -> void:
	if not puede_sonar:
		return
		
	if _cuerpo.has_meta("max_shot") and _cuerpo.get_meta("max_shot"):
		_cuerpo.remove_meta("max_shot")
		hit_stop()

	if linear_velocity.length() > umbral_velocidad:
		puede_sonar = false
		
		# Llamada limpia y directa
		if audio:
			audio.play_lata()

		get_tree().create_timer(tiempo_cooldown).timeout.connect(
			func(): puede_sonar = true
		)

func hit_stop() -> void:
	Engine.time_scale = 0.05

	await get_tree().create_timer(
		duracion_hit_stop,
		true,
		false,
		true
	).timeout

	Engine.time_scale = 1.0
