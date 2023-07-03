class_name CrossingInspector
extends VBoxContainer

var crossing
var inspector1
var inspector2

var PortSelector = preload("res://layout/layout_devices/port_selector.tscn")

func _init(p_crossing):
	crossing = p_crossing
	
	inspector1 = PortSelector.instance()
	add_child(inspector1)
	inspector1.setup(crossing.motor1, "crossing_motor", "Motor 1")
	inspector1.connect("device_selected", self, "_on_motor1_selected")
	
	
#	inspector2 = PortSelector.instance()
#	add_child(inspector2)
#	inspector2.setup(crossing.motor2, "crossing_motor", "Motor 2")
#	inspector2.connect("device_selected", self, "_on_motor2_selected")

func _on_motor1_selected(device):
	crossing.set_motor1(device)

func _on_motor2_selected(device):
	crossing.set_motor2(device)