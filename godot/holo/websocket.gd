class_name WS extends Node

@export var websocket_url = "ws://192.168.1.112/ws"
@export var config:Config = null 

signal message_received

const heartbeatSeconds = 5

# Our WebSocketClient instance.
var socket = WebSocketPeer.new()
var id:String = "";
var heartbeat:SceneTreeTimer = null
var connected:bool = false


func start(_id):
	id = _id
	connectws()
	set_heartbeat_timer()


func connectws():
	# Initiate connection to the given URL.
	var err = socket.connect_to_url(websocket_url)
	if err != OK:
		print("Unable to connect")
		set_process(false)
		var timer = get_tree().create_timer(2)
		timer.timeout.connect(connectws)
	else:
		# Wait for the socket to connect.
		await get_tree().create_timer(2).timeout

	connected = true


func set_heartbeat_timer():
		heartbeat = get_tree().create_timer(heartbeatSeconds)
		heartbeat.timeout.connect(on_heartbeat)

func on_heartbeat():
		print("PING "+id)
		socket.send_text("PING "+id)
		set_heartbeat_timer()

func _process(_delta):
	if not connected:
		return
	
	# Call this in _process or _physics_process. Data transfer and state updates
	# will only happen when calling this function.
	socket.poll()

	# get_ready_state() tells you what state the socket is in.
	var state = socket.get_ready_state()

	# WebSocketPeer.STATE_OPEN means the socket is connected and ready
	# to send and receive data.
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var message = socket.get_packet().get_string_from_utf8()
			print("Got data from server: ", message)
			
			if message.begins_with(id + " "):
				# Remove our ID from the message and emit signal
				var content = message.substr(id.length() + 1)
				message_received.emit(content)
			else:
				message_received.emit(message)

	# WebSocketPeer.STATE_CLOSING means the socket is closing.
	# It is important to keep polling for a clean close.
	elif state == WebSocketPeer.STATE_CLOSING:
		pass

	# WebSocketPeer.STATE_CLOSED means the connection has fully closed.
	# It is now safe to stop polling.
	elif state == WebSocketPeer.STATE_CLOSED:
		# The code will be -1 if the disconnection was not properly notified by the remote peer.
		var code = socket.get_close_code()
		print("WebSocket closed with code: %d. Clean: %s" % [code, code != -1])
		connected = false # Stop processing.
		connectws()
