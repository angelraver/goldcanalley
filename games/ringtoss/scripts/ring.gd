extends RigidBody3D

# --- Audio: patrón GameAudioBase (ver games/plinko/scripts/ball.gd y
# games/tincanalley/scripts/lata.gd + core/scripts/game_audio_base.gd) ---
# Cada impacto del aro (cono, pared, suelo, caja) reproduce un ringhit
# aleatorio vía audio.play_hit(). El main inyecta la referencia con
# ring.set("audio", audio_juego) al instanciarlo (ver main.gd:_spawn_ring).
var audio: GameAudioBase
@export var umbral_velocidad: float = 0.8
@export var tiempo_cooldown: float = 0.08
var puede_sonar: bool = true


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(_cuerpo: Node) -> void:
	# Solo suena el aro ya lanzado; en la mano está congelado y sin launch_number.
	if not int(get_meta("launch_number", 0)):
		return
	if not puede_sonar:
		return
	if linear_velocity.length() < umbral_velocidad:
		return
	puede_sonar = false
	if audio:
		audio.play_hit()
	get_tree().create_timer(tiempo_cooldown).timeout.connect(
		func():
			if is_instance_valid(self):
				puede_sonar = true
	)
