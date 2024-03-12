extends Node

# class member variables go here, for example:
# var a = 2
# var b = "textvar"
var minimum = 0
var maximum = 360
var current = 0

var angle_minimum = 0
var angle_maximum = 360

var needleAngle = 0

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	$Scale.texture = load("res://Images/DialCompass.png")

func _process(_delta):
	# Called every frame. Delta is time since last frame.
	# Update game logic here.
	needleAngle = angle_minimum + (angle_maximum - angle_minimum) * (current - minimum) / (maximum - minimum)
	if(needleAngle<angle_minimum):
		needleAngle=angle_minimum
	elif(needleAngle>angle_maximum):
		needleAngle=angle_maximum
	
	$Needle.rotation = needleAngle * PI / 180
