

class_name LayoutCrossing
extends Node2D

var motor1 = null
var motor2 = null

var pos = "down"

func _init():
	pass

func remove():
	queue_free()

func toggle_pos():
	if pos == "up":
		set_pos("down")
	else:
		set_pos("up")

func set_pos(p_pos):
	if motor1 != null and LayoutInfo.control_devices != LayoutInfo.CONTROL_OFF:
		motor1.set_pos(p_pos)
	if motor2 != null and LayoutInfo.control_devices != LayoutInfo.CONTROL_OFF:
		motor2.set_pos(p_pos)
	pos = p_pos
	update()

func set_motor1(device):
	motor1 = device

func set_motor2(device):
	motor2 = device

func _draw():
	var col = Settings.colors["white"]
	var width = LayoutInfo.spacing*0.05
	var spacing = LayoutInfo.spacing * 0.5
	var pivot1 = spacing*Vector2(-0.5, -0.5)
	var pivot2 = spacing*Vector2(0.5, 0.5)
	var angle = 0.0
	if pos == "up":
		angle = -PI*0.4
	var end1 = pivot1 + spacing*Vector2(1.0, 0.0).rotated(angle)
	var end2 = pivot2 + spacing*Vector2(-1.0, 0.0).rotated(angle)
	draw_line(pivot1, end1, col, width)
	draw_line(pivot2, end2, col, width)
	