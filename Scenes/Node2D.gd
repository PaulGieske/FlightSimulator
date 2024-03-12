extends Node2D

var _graphsClass = load("res://Scripts/GraphClass.gd")
var _graphInstances = []

func _ready():
	pass

func _addGraph(name,color,scalingValue):
	var _graphInstance = _graphsClass.new(name,color,scalingValue)
	_graphInstances.append(_graphInstance)
	
	print(_graphInstance._name, " added to list of graphs")

func _graphAlreadyExists(name):
	for i in _graphInstances:
		if (i._name == name):
			return(true)
	return(false)

func _getGraphIndex(name):
	var count = -1
	for i in _graphInstances:
		count += 1
		if (i._name == name):
			i.get_index()
			return(count)
			
	return(count)

func addPoint(name,x,y,color,scalingValue):
	if (!_graphAlreadyExists(name)):
		_addGraph(name,color,scalingValue)
	else:
		var i = _getGraphIndex(name)
		_graphInstances[i].addPoint(x,y)
	
	update()


func _draw():
#	For each line
#		draw each data point
#	draw_line(Vector2(0,0), Vector2(100, 100), Color(255, 0, 0), 1)
	
	# Parameters of the plot
	var x0 = 680
	var y0 = 450
	var width = 300
	var height = 200
	
	# Draw the plot area
	draw_line(Vector2(x0,y0+height/2),Vector2(x0,y0-height/2),Color(1, 0.2, 0.2),1)
	draw_line(Vector2(x0+width,y0+height/2),Vector2(x0+width,y0-height/2),Color(1, 0.2, 0.2),1)
	draw_line(Vector2(x0,y0+height/2),Vector2(x0+width,y0+height/2),Color(1, 0.2, 0.2),1)
	draw_line(Vector2(x0,y0-height/2),Vector2(x0+width,y0-height/2),Color(1, 0.2, 0.2),1)
	draw_line(Vector2(x0,y0),Vector2(x0+width,y0),Color(0.1, 0.1, 0.1),1)
	
	# Plot each graph
	for i in _graphInstances:
		for j in range(i._x.size()-2):
			var x1 = x0+(i._x[j+1]-i._xLastReset)*30 
			var x2 = x0+(i._x[j+2]-i._xLastReset)*30
			
			var y1 = y0 - (1.0 * i._y[j+1] / i._scalingFactor) * height / 2
			var y2 = y0 - (1.0 * i._y[j+2] / i._scalingFactor) * height / 2
			
			draw_line(Vector2(x1,y1),Vector2(x2,y2),i._color,1)
