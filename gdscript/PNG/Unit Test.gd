extends Node

#Import the PNG library
onready var PNG = load("res://PNG.gd")

#PNG to try
export(String, FILE) var target_png = "./icon.png"


func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	#Attempt to parse the png file
	var png_information = PNG.Parse_PNG(target_png)
	if png_information != null:
		#We are successful!
		print("Test passed!")