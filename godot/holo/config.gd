class_name Config extends Resource

var config = ConfigFile.new()
var id = null
var _phase = 0
var _model = null
var _rpm = 450
var _light = 1
const configFile = "user://config.cfg"
const configSection = "master"

signal phase_changed
signal model_changed
signal rpm_changed
signal light_changed

func _init() -> void:
	var err = load_config()
	if err != OK:
		new_config()
		return
	print("ID: "+id)
	print("Phase: "+str(_phase))
	if (_model != null):
		print("Model: "+_model)
		
func new_config():
	id = generate_unique_id()
	_phase = 0
	save_config()

func save_config():
	config.set_value(configSection,"id",id)
	config.set_value(configSection,"phase",_phase)
	config.set_value(configSection,"model", _model)
	config.set_value(configSection,"rpm",_rpm)
	config.set_value(configSection,"light", _light)
	config.save(configFile)

func load_config() -> int:
	var err = config.load(configFile)
	if err != OK:
		return err
	id = config.get_value(configSection,"id",null)
	if id == null:
		return ERR_FILE_UNRECOGNIZED
	setPhase(config.get_value(configSection,"phase",0))
	setModel(config.get_value(configSection, "model",null))
	setRpm(float(config.get_value(configSection, "rpm",450)))
	setLight(config.get_value(configSection, "light",1))
	return OK

func setPhase(phase):
	_phase = phase
	phase_changed.emit(phase)

func setModel(model):
	_model = model;
	model_changed.emit(model)

func setRpm(rpm:float):
	_rpm = rpm;
	rpm_changed.emit(rpm)
	
func setLight(light:float):
	_light = light;
	light_changed.emit(light)

# Generate a unique ID with alphanumeric characters
func generate_unique_id(length: int = 16) -> String:
	var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(length):
		var random_index = rng.randi() % characters.length()
		result += characters[random_index]
	
	return result
