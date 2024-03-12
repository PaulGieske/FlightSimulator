extends Node
# Zivko Edge 540

#To do:
# - Test Euler angles							
# - Show tne body in other camera modes
# - Physics engine in 2D mode
# - Complete GUI
#	- Let graph dissappear with checkbox	ok
#	- Dials: Pitch, roll, heading (compass)	ok
#	- HUD: Artificial horizon, Altitude

# State variables
var v_body								#Vector3 velocity in local coordinates
var angularV_body						#Vector3 containing the angular velocity
var alpha								#Angle of incidence wings ( = angle of attack)
var beta								#Angle of incidence rudder

# input variables
var T = 2000		# N
var deflection_elevator = 0
var deflection_rudder = 0
var deflection_aileron = 0

# airplance constants
var MASS = 700							# kg
var S = 9.1								# m^2
var S_RUDDER = 1						# m^2
var T_MAX = 8000						# N
var Dw = 1								# m, distance from cog to wing
var Dt = 5								# m, distance from cog to tail
var DIST_WINGS_Z = 2					# m, distance from one wing's center of lift to centerline 
var Ixx = 3000							# moment of inertia
var Iyy = 5000							# moment of inertia
var Izz = 5000							# moment of inertia
var Ixy = 3000							# moment of inertia
var I = Basis(Vector3(Ixx,-Ixy,0),Vector3(-Ixy,Iyy,0),Vector3(0,0,Izz))
var MIN_DEFL = -0.2						# minimum elevator deflection
var MAX_DEFL = 0.2						# maximum elevator deflection
var MIN_RUDDER = -0.2					# minimum elevator deflection
var MAX_RUDDER = 0.2					# maximum elevator deflection
var MIN_AILERON = -0.1					# minimum elevator deflection
var MAX_AILERON = 0.1					# maximum elevator deflection

var CL_MAX = 1.0						# maximum lift coefficient
var CL0 = 0.5							# lift coefficient at 0 angle of attack
var CDy = 0.5							# drag coefficient in body-y direction
var CDz = 0.5							# drag coefficient in body-z direction
var ALPHA_MAX = 17 * PI / 180			# angle of attack where the maximum lift occurs
var ALPHA_STALL = 25 * PI / 180			# angle of attack where the lift stalls

var CL_TAIL_MAX = 0.1					# maximum lift coefficient for tail
var CL_TAIL0 = - 0.05					# tail lift coefficient at 0 angle of attack
var ALPHA_TAIL_MAX = 17 * PI / 180		# angle of attack where the maximum lift occurs
var ALPHA_TAIL_STALL = 25 * PI / 180	# angle of attack where the lift stalls
#
## physical constants
var GRAVITY = 9.8	# m / s^2
var RHO = 1.225		# kg / m^3

# program control variables
var is_crashed = false
var show_arrows = true
var show_graphs = true
var time = 0
var timeMarker = -1
enum COLOR{
	RED
	GREEN
	BLUE
	BLACK
	GREY
	WHITE
	MAGENTA
	HORIZON
	}

var matHUD = SpatialMaterial.new()

func _ready():
#	Define initial control input
	alpha = 0										# Angle of attack
	deflection_elevator = -CL(alpha)*Dw/Dt-CLtail(alpha,0)
	deflection_rudder = 0
	deflection_aileron = 0
	
	$Cockpit.translation = Vector3(-1500, 100, 400)	# Position
	$Cockpit.rotation = Vector3(0, 0, 0)			# Attitude
	
	# Calculate initial state
	# The initial lift should equal the weight. Calculate velocity accordingly
	var vx = sqrt((2 * MASS * GRAVITY)/((CL(alpha) + CLtail(alpha,deflection_elevator))* RHO * S))
	v_body = Vector3(vx,0,0)
	angularV_body = Vector3(0,0,0)
	
	# The thrust should cancel out the drag
	T = 0.5 * CDx(alpha) * RHO * pow(v_body.x,2) * S
	
	# Set the dials
	$Node2D/Dial.minimum = MIN_RUDDER
	$Node2D/Dial.maximum = MAX_RUDDER
	$Node2D/Dial.current = deflection_rudder
	$Node2D/Compass/Scale.texture = load("res://Images/DialCompass.png")
	$Node2D/Compass.minimum = -180
	$Node2D/Compass.maximum = 180
	$Node2D/Compass.current = 0
	$Node2D/Compass.angle_minimum = -180
	$Node2D/Compass.angle_maximum = 180
	$Node2D/Roll/Needle.texture = load("res://Images/NeedleRoll.png")
	$Node2D/Roll.minimum = -60
	$Node2D/Roll.maximum = 60
	$Node2D/Roll.current = 0
	$Node2D/Roll.angle_minimum = -60
	$Node2D/Roll.angle_maximum = 60
	$Node2D/Pitch/Needle.texture = load("res://Images/NeedlePitch.png")
	$Node2D/Pitch.minimum = -60
	$Node2D/Pitch.maximum = 60
	$Node2D/Pitch.current = 0
	$Node2D/Pitch.angle_minimum = -60
	$Node2D/Pitch.angle_maximum = 60
	
	matHUD.albedo_color = Color(1,0,1)

func _process(_delta):
	_handle_input()
	_update_display()

func _physics_process(delta):
	if (!is_crashed):
		_flight_dynamics(delta)

func _flight_dynamics(_delta):
	# Calculate the acceleration from the current state
	# - 1) Get the angles of incidence
	alpha = $Cockpit.rotation.z - atan(v_body.y/v_body.x)
	beta =  atan(v_body.z/v_body.x)
	
	# - 2) Calculate the magnitudes of the forces
	var Dx = 0.5*CDx(alpha)*RHO*S*pow(v_body.x,2)
	var Dy = 0.5*CDy*RHO*S*pow(v_body.y,2)
	var Dz = 0.5*CDz*RHO*S*pow(v_body.z,2)
	
	var Ltail = 0.5*CLtail(alpha,deflection_elevator)*RHO*S*pow(v_body.x,2)
	var L = 0.5*CL(alpha)*RHO*S*pow(v_body.x,2)
	var Frudder = 0.5*CFrudder(beta,deflection_rudder)*RHO*S_RUDDER*pow(v_body.x,2)
	
	# - 3) Define direction of the forces as vectors in body axes
	var T_body = Vector3(T,0,0)
	var Lwing_body = Vector3(0,L,0)
	var Ltail_body = Vector3(0,Ltail,0)
	var D_body = Vector3(-Dx,-sign(v_body.y)*Dy,-sign(v_body.z)*Dz)
	var Frudder_body = Vector3(0,0,-Frudder)
	
	# - 4) Calculate the moments about the center of gravity in body axes
	var Mwinglift_body = Vector3(0,0,-L * Dw)
	var Mtaillift_body = Vector3(0,0,-Ltail * Dt)
	
	var yawDampingCoefficient = 40000
	var Myaw_damping = Vector3(0,-yawDampingCoefficient*angularV_body.y,0)
	var Mrudder = Vector3(0,-Frudder*Dt,0)
	
	var rollDampingCoefficient = 10000
	var deltaL = 0.05 * L * deflection_aileron / MAX_AILERON
	var Mroll_damping = Vector3(-rollDampingCoefficient*angularV_body.x,0,0)
	var Maileron = Vector3(-2*deltaL*DIST_WINGS_Z,0,0)
	
	# - 5) Define direction of the forces in global axes
	var G_global = Vector3(0,-MASS*GRAVITY,0)
	
	# - 6) Transform G_body to G_global
	var G_body = $Cockpit.transform.basis.inverse() * G_global
	
	# - 7) Add up the forces in the body axes and get acceleration divide by (the mass)
	var F_resultant = T_body + Lwing_body + Ltail_body + D_body + G_body + Frudder_body
	var a_body = F_resultant / MASS
	
	# - 8) Add up the moments and get the angular acceleration
	var M_resultant = Mwinglift_body + Mtaillift_body + Mrudder + Myaw_damping + Maileron + Mroll_damping
	var angularA_body = (I.inverse())*M_resultant
	
	# - 9) Integrate the accelerations to get the velocities
	v_body += a_body * _delta
	angularV_body += angularA_body * _delta
	
	# - 10) Convert the velocity to the global axis and move the plane
	var v_global = $Cockpit.transform.basis * v_body
	var collision = $Cockpit.move_and_collide(v_global * _delta)
	$Cockpit.rotate($Cockpit.transform.basis.x,angularV_body.x * _delta)
	$Cockpit.rotate($Cockpit.transform.basis.y,angularV_body.y * _delta)
	$Cockpit.rotate($Cockpit.transform.basis.z,angularV_body.z * _delta)
	
	if (collision):
		_ready()

	time += _delta
	
	if (time > timeMarker + 0.1):
		timeMarker = time
#		$Graphs.addPoint("L",time,L,Color(1,1,0),MASS * GRAVITY)
#		$Graphs.addPoint("Ltail",time,Ltail,Color(1,0,1),MASS * GRAVITY)
#		$Graphs.addPoint("Mroll",time,M_resultant.x,Color(0,1,1),MASS * GRAVITY * 0.2)
#		$Graphs.addPoint("Pitch Rate",time,angularV_body.z,Color(1,0,0),0.2)
#		$Graphs.addPoint("Pitch",time,$Cockpit.rotation.z,Color(1,0,0),0.2)
#		$Graphs.addPoint("Beta",time,CFrudder(beta,deflection_rudder),Color(1,0,0),1)
#		$Graphs.addPoint("Mroll",time,M_resultant.x,Color(1,0,0),MASS * GRAVITY * Dw * 0.2)
#		$Graphs.addPoint("Myaw",time,M_resultant.y,Color(0,1,0),MASS * GRAVITY * Dw * 0.2)
#		$Graphs.addPoint("Myaw",time,Mrudder.y,Color(0,1,1),MASS * GRAVITY * Dw * 0.2)
#		$Graphs.addPoint("Mpitch",time,M_resultant.z,Color(0,0,1),MASS * GRAVITY * Dw * 0.2)
#		$Graphs.addPoint("Frudder",time,Frudder,Color(1,1,0),T_MAX/4)
		$Graphs.addPoint("Dz",time,Dz,Color(0,1,0),0.1*T_MAX)
		$Graphs.addPoint("Frudder",time,Frudder,Color(1,0,0),0.1*T_MAX)
		$Graphs.addPoint("Vz",time,v_body.z,Color(0,0,1),10)
#		$Graphs.addPoint("az",time,a_body.z,Color(0,1,1),T_MAX/(2*MASS))
	
	if (show_arrows):
		#draw the body arrows
#		_draw_arrow(Vector3(0,0,0),10*Lwing_body/T_MAX,COLOR.BLACK)
#		_draw_arrow(Vector3(-10,0,0),Vector3(-10,0,0)+10*Ltail_body/T_MAX,COLOR.BLUE)
		_draw_arrow(Vector3(0,0,0),Vector3(v_body.x,0,0),COLOR.RED)
		_draw_arrow(Vector3(0,0,0),Vector3(0,v_body.y,0),COLOR.GREEN)
		_draw_arrow(Vector3(0,0,0),Vector3(0,0,v_body.z),COLOR.BLUE)
		_draw_arrow(Vector3(-10,0,0),Vector3(-10,0,0)+100*Frudder_body/T_MAX,COLOR.BLACK)
#		_draw_arrow(Vector3(0,0,0),10*T_body/T_MAX,COLOR.RED)
#		_draw_arrow(Vector3(0,0,0),10*D_body/T_MAX,COLOR.GREEN)
#		_draw_arrow(Vector3(0,0,0),10*G_body/T_MAX,COLOR.GREY)
#		_draw_arrow(Vector3(0,0,0),v_body/5,COLOR.GREY)
#		_draw_arrow(Vector3(0,0,0),a_body,COLOR.RED)
		
		# draw the global arrows
#		_draw_arrow($Cockpit.transform.origin,$Cockpit.transform.origin+10*G_global/T_MAX,COLOR.MAGENTA)

func _handle_input():
	if Input.is_action_pressed("ui_plus"):
		T += 50
		if (T>T_MAX):
			T = T_MAX
	if Input.is_action_pressed("ui_minus"):
		T -= 50
		if (T<0):
			T = 0
	if Input.is_action_pressed("ui_down"):
		deflection_elevator -= 0.001
		if (deflection_elevator < MIN_DEFL):
			deflection_elevator = MIN_DEFL
	if Input.is_action_pressed("ui_up"):
		deflection_elevator += 0.001
		if (deflection_elevator > MAX_DEFL):
			deflection_elevator = MAX_DEFL
	if Input.is_action_pressed("ui_left"):
		deflection_aileron += 0.01
#		deflection_rudder -= 0.01
#		$Cockpit.rotate_x(-0.01)
		if (deflection_aileron > MAX_AILERON):
			deflection_aileron = MAX_AILERON
	if Input.is_action_pressed("ui_right"):
		deflection_aileron -= 0.01
#		deflection_rudder += 0.01
#		$Cockpit.rotate_x(10.01)
		if (deflection_aileron < MIN_AILERON):
			deflection_aileron = MIN_AILERON
	if Input.is_action_pressed("ui_rudder_right"):
		deflection_rudder += 0.01
		if (deflection_rudder < MIN_RUDDER):
			deflection_rudder = MIN_RUDDER
	if Input.is_action_pressed("ui_rudder_left"):
		deflection_rudder -= 0.01
		if (deflection_rudder > MAX_RUDDER):
			deflection_rudder = MAX_RUDDER
	if Input.is_action_pressed("ui_cancel"):
		_ready()
	if Input.is_action_just_pressed("ui_next_camera"):
		_next_camera()
	if Input.is_action_pressed("ui_release_controls"):
		deflection_aileron = 0
		deflection_rudder = 0

func _update_display():
	var COLUMN_MAX = -15
	var COLUMN_MIN = 15
	var WHEEL_MAX = 25
	var WHEEL_MIN = -25
	var THROTTLE_MIN = 90
	var THROTTLE_MAX = -45

	var m = (COLUMN_MAX - COLUMN_MIN) / ( MAX_DEFL - MIN_DEFL)
	var c = COLUMN_MAX - m * MAX_DEFL
	var angle = m * deflection_elevator + c

	$Cockpit/SpatialSteeringColumn.rotation_degrees.z = angle

	m = (WHEEL_MAX - WHEEL_MIN) / (MAX_AILERON - MIN_AILERON)
	c = WHEEL_MAX - m * MAX_AILERON
	angle = m * deflection_aileron + c

	$Cockpit/SpatialSteeringColumn/MeshColumn/MeshWheel.rotation_degrees.x = -angle

	m = (THROTTLE_MAX - THROTTLE_MIN) / float(T_MAX)
	c = THROTTLE_MAX - m * T_MAX
	angle = m * T + c

	$Cockpit/SpatialThrottle.rotation_degrees.z = angle
	$Node2D/Dial.current = deflection_rudder
	
	$Node2D/Roll.current = $Cockpit.rotation_degrees.x
	$Node2D/Compass.current = $Cockpit.rotation_degrees.y
	$Node2D/Pitch.current = -$Cockpit.rotation_degrees.z
	$Node2D/Altimeter.text = String($Cockpit.translation.y) + " m"
	
	$Camera1.translation = $Cockpit.translation - Vector3(25,0,0)
	$Camera2.translation = $Cockpit.translation + Vector3(0,0,25)
	$Camera3.translation = $Cockpit.translation + Vector3(0,100,0)
	
	_update_hud()

func _next_camera():
	if ($Cockpit/CameraCockpit.current):
		$Camera1.make_current()
	elif ($Camera1.current):
		$Camera2.make_current()
	elif ($Camera2.current):
		$Camera3.make_current()
	elif ($Camera3.current):
		$Cockpit/CameraCockpit.make_current()

func _draw_arrow(start, end, color):
	var tmpMesh = Mesh.new()
	var vertices = PoolVector3Array()
	var mat = SpatialMaterial.new()

	vertices.push_back(start)
	vertices.push_back(end)
	
	match color:
		COLOR.BLUE:
			mat.albedo_color = Color(0,0,1)
		COLOR.RED:
			mat.albedo_color = Color(1,0,0)
		COLOR.GREEN:
			mat.albedo_color = Color(0,0.5,0)
		COLOR.WHITE:
			mat.albedo_color = Color(1,1,1)
		COLOR.BLACK:
			mat.albedo_color = Color(0,0,0)
		COLOR.MAGENTA:
			mat.albedo_color = Color(1,0,1)
		COLOR.GREY:
			mat.albedo_color = Color(0.5,0.5,0.5)
		COLOR.HORIZON:
			mat.albedo_color = Color(1,0,1)
			
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_material(mat)
	
	for v in vertices.size():
		st.add_color(color)
		st.add_vertex(vertices[v])
	
	st.commit(tmpMesh)
	
	match color:
		COLOR.BLUE:
			$Cockpit/Arrows/Blue.mesh = tmpMesh
		COLOR.GREEN:
			$Cockpit/Arrows/Green.mesh = tmpMesh
		COLOR.RED:
			$Cockpit/Arrows/Red.mesh = tmpMesh
		COLOR.GREY:
			$Cockpit/Arrows/Grey.mesh = tmpMesh
		COLOR.HORIZON:
			$Arrows_Global/Horizon.mesh = tmpMesh
		COLOR.WHITE:
			$Arrows_Global/White.mesh = tmpMesh
		COLOR.BLACK:
			$Cockpit/Arrows/Black.mesh = tmpMesh
		COLOR.MAGENTA:
			$Arrows_Global/Magenta.mesh = tmpMesh

func CL(alpha):
	var CL

	if (alpha < ALPHA_MAX):
		CL = CL0 + alpha * (CL_MAX - CL0) / ALPHA_MAX
		if (CL < 0):
			CL = 0
	elif (alpha < ALPHA_STALL):
		CL = CL_MAX
	else:
		CL = CL_MAX - (alpha - ALPHA_STALL)
		if (CL < 0):
			CL = 0

	return CL

func CLtail(alpha,deflection_elevator):
	var CLtail

	if (alpha < ALPHA_TAIL_MAX):
		CLtail = CL_TAIL0 + alpha * (CL_TAIL_MAX - CL_TAIL0) / ALPHA_TAIL_MAX
		if (CLtail < -0.25):
			CLtail = -0.25
	elif (alpha < ALPHA_TAIL_STALL):
		CLtail = CL_TAIL_MAX
	else:
		CLtail = CL_TAIL_MAX - (alpha - ALPHA_TAIL_STALL)
		if (CLtail < 0):
			CLtail = 0

	CLtail += deflection_elevator

	return CLtail

func CDx(alpha):
	var CD

	CD = 0.3 + abs(alpha)
	return CD
 
func CFrudder(beta,deflection_rudder):
	var K_deflection = 2.0
	var K_reaction = 5.0
	
	var CLrudder_deflection = K_deflection*deflection_rudder
	var CLrudder_angle = K_reaction*beta
	
	return  CLrudder_angle + CLrudder_deflection
#	
func CMailerons():
	return 0

func _update_hud():
	var l = 10						# Distance to HUD screen
	var m = 1.5						# Distance to line corner
	var theta = -$Cockpit.rotation.y
	
	for gamma_deg in range(-20,31,10):
		var tmpMesh = Mesh.new()
#		var vertices = PoolVector3Array()
		var gamma = gamma_deg * PI / 180
		
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		st.set_material(matHUD)
		
		st.add_vertex($Cockpit.transform.origin + Vector3(l*cos(theta)+m*sin(theta),l*tan(gamma)/2,l*sin(theta)-m*cos(theta)))
		st.add_vertex($Cockpit.transform.origin+Vector3(l*cos(theta)-m*sin(theta),l*tan(gamma)/2,l*sin(theta)+m*cos(theta)))
		
		match gamma_deg:
			-20:
				$HUD/neg20.mesh = tmpMesh
				st.commit(tmpMesh)
			-10:
				$HUD/neg10.mesh = tmpMesh
				st.commit(tmpMesh)
			0:
				$HUD/Horizon.mesh = tmpMesh
				st.add_vertex($Cockpit.transform.origin+Vector3(l*cos(theta)-m*sin(theta),l*tan(gamma)/2+0.05,l*sin(theta)+m*cos(theta)))
				st.add_vertex($Cockpit.transform.origin + Vector3(l*cos(theta)+m*sin(theta),l*tan(gamma)/2+0.05,l*sin(theta)-m*cos(theta)))
				st.commit(tmpMesh)
			10:
				$HUD/pos10.mesh = tmpMesh
				st.commit(tmpMesh)
			20:
				$HUD/pos20.mesh = tmpMesh
				st.commit(tmpMesh)
			30:
				$HUD/pos30.mesh = tmpMesh
				st.commit(tmpMesh)

func _on_Arrow_Checkbox_pressed():
	if(show_arrows):
		show_arrows = false
		$Cockpit/Arrows.visible = false
	else:
		show_arrows = true
		$Cockpit/Arrows.visible = true

func _on_Graph_Checkbox2_pressed():
	if(show_graphs):
		show_graphs = false
		$Graphs.visible = false
	else:
		show_graphs = true
		$Graphs.visible = true
