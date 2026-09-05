extends RigidBody3D

@onready var trail: GPUParticles3D = $Trail

func activar_max_shot() -> void:
	trail.emitting = true
