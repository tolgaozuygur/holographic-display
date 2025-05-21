extends Node3D

# Exported variable to set the Node3D to be rotated in the editor
@export var camera_node: Node3D
@export var target_node: Node3D
@export var websocket_node: WS
@export var light1: Light3D
@export var light2: Light3D
@export var light3: Light3D
@export var light4: Light3D
var configClass: Resource = preload("res://config.gd")
var local_file_path = "user://downloaded_model.glb"
var http_request


var rpm: float = 450  # Revolutions per minute
var fps: int = 120
var phase: float = 0

var start_time = Time.get_unix_time_from_system()
var current_time_ms: int = 0
var frame_counter: int = 0
var frame_drift_detected: int = 0
var frame_drift_treshold: int = 30 #increasing will reduce false positives, but correcting the drift will take longer


var config: Config
var menu: Node
# Speed in radians per second
var angle_per_frame: float = (TAU * rpm) / (60*fps)
# var angle_per_second: float = angle_per_frame * fps
var current_angle: float = 0


func _ready():
	config = configClass.new()
	config.phase_changed.connect(phase_changed)
	config.model_changed.connect(model_changed)
	config.rpm_changed.connect(rpm_changed)
	config.light_changed.connect(light_changed)
	phase_changed(config._phase)
	model_changed(config._model)
	rpm_changed(config._rpm)
	light_changed(config._light)
	websocket_node.start(config.id)
	websocket_node.message_received.connect(on_message_received)
	#Engine.max_fps = fps #pc test
	Engine.max_fps = fps*2 #tablet
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	start_time = Time.get_unix_time_from_system()
	
func model_changed(model):
	print("model changed")
	print(model)
	if (model != null):
		load_model(model)

func rpm_changed(_rpm):
	rpm = _rpm
	angle_per_frame = (TAU * rpm) / (60*fps)
	# angle_per_second = angle_per_frame * fps
	
func light_changed(light):
	light1.light_energy = light
	light2.light_energy = light
	light3.light_energy = light
	light4.light_energy = light

func load_model(url):
	http_request = HTTPRequest.new()
	add_child(http_request)
	print("Starting download of GLB file...")
	http_request.connect("request_completed", model_request_complete)
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request: " + str(error))

	
func model_request_complete(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to download the GLB file. Error code: " + str(result))
		return
	
	if response_code != 200:
		push_error("Failed to download the GLB file. HTTP response code: " + str(response_code))
		return
	
	print("Download completed. Saving file...")
	
	# Save the downloaded file
	var file = FileAccess.open(local_file_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open file for writing: " + str(error))
		return
	
	file.store_buffer(body)
	file.close()
	
	print("File saved. Loading 3D model...")
	instantiate_glb_model()

func instantiate_glb_model():
	# Create a new PackedSceneGLTF importer
	var importer = GLTFDocument.new()
	var state = GLTFState.new()
	
	# Load the GLB file
	print("wat")
	var error = importer.append_from_file(local_file_path, state)
	if error != OK:
		push_error("Failed to parse GLB file: " + str(error))
		return
	
	# Generate the scene
	var scene = importer.generate_scene(state)
	if scene == null:
		push_error("Failed to generate scene from GLB file")
		return
	print("HEllo")
	var children = target_node.get_children()
	for child in children:
		target_node.remove_child(child)
		child.queue_free()

	var instance
	# Instance the scene
	if scene is PackedScene:
		instance = scene.instantiate()
	else:
		instance = scene	

	target_node.add_child(instance)
	if str(get_node("Node3D/downloaded_model/AnimationPlayer")) != "<Object#null>":
		get_node("Node3D/downloaded_model/AnimationPlayer").set_speed_scale(0.9)
		get_node("Node3D/downloaded_model/AnimationPlayer").play("anim-loop")


func on_message_received(msg):
	if msg == "+":
		current_angle += angle_per_frame
	elif msg == "-":
		current_angle -= angle_per_frame
	elif msg == "reset":
		if str(get_node("Node3D/downloaded_model/AnimationPlayer")) != "<Object#null>":
			get_node("Node3D/downloaded_model/AnimationPlayer").stop(true)
			get_node("Node3D/downloaded_model/AnimationPlayer").set_speed_scale(0.9)
			get_node("Node3D/downloaded_model/AnimationPlayer").play("anim-loop")
		current_angle = phase
	elif msg.begins_with("phase "): #derece cinsinden aci
		config.setPhase(int(msg.substr("phase ".length())))
		config.save_config()
	elif msg.begins_with("model "): #modelin urlsi
		config.setModel(msg.substr("model ".length()))
		config.save_config()
	elif msg.begins_with("rpm "): #motorun dondugu rpm
		config.setRpm(float(msg.substr("rpm ".length())))
		config.save_config()
	elif msg.begins_with("light "):
		config.setLight(float(msg.substr("light ".length())))
		config.save_config()

func phase_changed(newPhase: int):
	phase = deg_to_rad(newPhase)

func _process(delta: float) -> void:
	#current_angle += angle_per_second * delta
	current_angle -= angle_per_frame
	frame_counter += 1
	current_time_ms = (Time.get_unix_time_from_system()*1000) - (start_time*1000)
	var calculated_frame: int = (current_time_ms / (1000.0/fps)) + 1
	if frame_counter != calculated_frame:
		if frame_drift_detected >= frame_drift_treshold:
			#actual frame drift, corect it
			if frame_counter < calculated_frame:
				current_angle -= angle_per_frame
				frame_counter += 1
				#print("+")
			else:
				current_angle += angle_per_frame
				frame_counter -= 1
				#print("-")
		frame_drift_detected += 1 #this is for double checking just to make sure it's not a blip
	else:
		frame_drift_detected = 0
	# Rotate the target node around its Y-axis
	camera_node.rotation.y = current_angle
	
