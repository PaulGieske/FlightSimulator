var _pitch
var _yaw
var _roll
var _euler_matrix

func _init():
	_pitch = 0
	_yaw = 0
	_roll = 0
	_euler_matrix = _update_matrix()

func _update_matrix():
	# updates the matrix based on the current angles
	var v1 = Vector3(cos(_pitch)*cos(_yaw),sin(_pitch)*sin(_roll)*cos(_yaw)-cos(_roll)*sin(_yaw),sin(_roll)*sin(_yaw)+cos(_roll)*sin(_pitch)*cos(_yaw))
	var v2 = Vector3(cos(_pitch)*sin(_yaw),cos(_roll)*cos(_yaw)+sin(_roll)*sin(_pitch)*sin(_yaw),cos(_roll)*sin(_pitch)*sin(_yaw)-sin(_roll)*cos(_yaw))
	var v3 = Vector3(-sin(_pitch),sin(_roll)*cos(_pitch),cos(_roll)*cos(_pitch))
#	var v1 = Vector3(cos(_pitch)*cos(_yaw),cos(_pitch)*sin(_yaw),-sin(_pitch))
#	var v2 = Vector3(sin(_roll)*sin(_pitch)*cos(_yaw)-cos(_roll)*sin(_yaw),sin(_roll)*sin(_pitch)*sin(_yaw)+cos(_roll)*cos(_yaw),sin(_roll)*cos(_pitch))
#	var v3 = Vector3(cos(_roll)*sin(_pitch)*cos(_yaw)+sin(_roll)*sin(_yaw),cos(_roll)*sin(_pitch)*sin(_yaw)-sin(_roll)*cos(_yaw),cos(_roll)*cos(_pitch))
	
	_euler_matrix = Basis(v1,v2,v3)

func get_matrix():
	# updates and returns
	_update_matrix()
	return _euler_matrix

func get_inverse_matrix():
	# returns the inverse matrix
	_update_matrix()
	return _euler_matrix.inverse()

func set_attitude(input_roll,input_pitch,input_yaw):
	# sets the value of the yaw, roll and pitch
	# input null to leave it unchanged
	if (input_roll!=null):
		_roll=input_roll
	
	if (input_pitch!=null):
		_pitch=input_pitch
	
	if (input_yaw!=null):
		_yaw=input_yaw

func fixed_to_rotated(input_vector):
	# transforms a vector in the fixed axes to the rotated axes
	_update_matrix()
	return _euler_matrix.xform(input_vector)

func rotated_to_fixed(input_vector):
	# transforms a vector in the rotated axes back to the fixed axes
	_update_matrix()
	return (_euler_matrix.inverse()).xform(input_vector)