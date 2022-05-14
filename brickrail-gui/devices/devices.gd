extends Node2D

var trains = {}
var layout_controllers = {}
var switches = {}
var marker_colors = {}

signal data_received(key,data)
signal train_added(trainname)
signal layout_controller_added(p_name)
signal trains_changed()
signal layout_controllers_changed()

func _ready():
	marker_colors = {"blue": Color.blue, "red": Color.red}

func _on_data_received(key, data):
	prints("[project] received data", key, data)
	emit_signal("data_received", key, data)

func serialize():
	var struct = {}
	
	var traindata = []
	for train in trains.values():
		traindata.append(train.serialize())
	struct["trains"] = traindata

	var controllerdata = []
	for controller in layout_controllers.values():
		controllerdata.append(controller.serialize())
	struct["controllers"] = controllerdata
	
	return struct

func load(struct):
	
	for train_data in struct.trains:
		var train = add_train(train_data.name, train_data.address)
		# train.load(train_data)
	
	for controller_data in struct.controllers:
		var controller = add_layout_controller(controller_data.name, controller_data.address)
		if "devices" in controller_data:
			for port in controller_data.devices:
				controller.set_device(int(port), controller_data.devices[port])
		# controller.load(controller_data)

func add_train(p_name, p_address=null):
	var train = BLETrain.new(p_name, p_address)
	get_node("BLEController").add_hub(train.hub)
	trains[p_name] = train
	train.connect("name_changed", self, "_on_train_name_changed")
	emit_signal("trains_changed")
	emit_signal("train_added", p_name)
	return train

func _on_train_name_changed(p_name, p_new_name):
	var train = trains[p_name]
	trains.erase(p_name)
	trains[p_new_name] = train
	emit_signal("trains_changed")

func add_layout_controller(p_name, p_address=null):
	var controller = LayoutController.new(p_name, p_address)
	$BLEController.add_hub(controller.hub)
	layout_controllers[p_name] = controller
	controller.connect("name_changed", self, "_on_controller_name_changed")
	emit_signal("layout_controllers_changed")
	emit_signal("layout_controller_added", p_name)
	return controller

func _on_controller_name_changed(p_name, p_new_name):
	var controller = layout_controllers[p_name]
	layout_controllers.erase(p_name)
	layout_controllers[p_new_name] = controller
	emit_signal("layout_controllers_changed")

func find_device(return_key):
	$BLEController.send_command(null, "find_device", [], return_key)
