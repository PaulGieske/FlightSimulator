extends Node

var _color
var _name
var _x
var _y
var _maxLength
var _xLastReset
var _scalingFactor

func _init(name,color,scalingFactor):
	_color = color
	_name = name
	_x = [-1]
	_y = [-1]
	_maxLength = 100
	_xLastReset = 0
	_scalingFactor = scalingFactor
	
func setMaxLength(value):
	_maxLength = value

func setColor(color):
	_color = color

func setName(name):
	_name = name

func addPoint(x,y):
	if (_x.size()==_maxLength):
		clearData()
	
	_x.append(x)
	_y.append(y)

func clearData():
	_xLastReset = _x.back()
	_x = [0]
	_y = [0]
