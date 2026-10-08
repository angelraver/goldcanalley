extends GameAudioBase

# Sonidos del ringtoss (ver games/plinko/scripts/audio_manager.gd y
# games/tincanalley/scripts/audio_manager.gd para el patrón).
# Grupos: "RingFly" (lanzamiento), "RingHit" (impactos aleatorios 1-3),
# "RingWin" (aro embocado con puntos).

func play_fly() -> void:
	play("RingFly")


func play_hit() -> void:
	play_aleatorio("RingHit")


func play_win() -> void:
	play("RingWin")
