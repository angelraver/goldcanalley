extends Node

@onready var start = $Start
@onready var shot = $Shot
@onready var welldone = $Welldone
@onready var lata1 = $Lata1
@onready var lata2 = $Lata2
@onready var lata3 = $Lata3
@onready var lata4 = $Lata4
@onready var lata5 = $Lata5
@onready var lata6 = $Lata6
@onready var lata7 = $Lata7
@onready var lata8 = $Lata8

func play_start():
	start.play()

func play_shot():
	shot.play()

func play_welldone():
	welldone.play()

func play_lata1():
	lata1.play()
	
func play_lata2():
	lata2.play()

func play_lata3():
	lata3.play()

func play_lata4():
	lata4.play()
	
func play_lata5():
	lata5.play()
	
func play_lata6():
	lata6.play()
	
func play_lata7():
	lata7.play()
	
func play_lata8():
	lata8.play()
