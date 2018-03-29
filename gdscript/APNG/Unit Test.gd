extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

var APNG = load("res://APNG/APNG.gd")

var png_sequence = ["./icon.png", "./noci.png"]
export(String, FILE) var output_apng = "./APNG/unit_test.apng"

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	
	#Load the first image
	var first_image = Image.new()
	first_image.load(png_sequence[0])
	
	#Get some details
	var width = first_image.get_width()
	var height = first_image.get_height()
	
	#Try to do it
	var success = APNG.Build_APNG_From_Sequence(output_apng, png_sequence, width, height)
	if success:
		print("APNG Creation successful")
