extends Node

@onready var start = $Start
@onready var shot = $Shot
@onready var welldone = $Welldone

func play_start():
	start.play()

func play_shot():
	shot.play()

func play_welldone():
	welldone.play()
