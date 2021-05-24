extends Node2D

export var nx = 60
export var ny = 60
export(Color) var grid_line_color
export(float) var grid_line_width

var cells = []
var hover_cell = null
var drawing_track = false
var direction = 0
var drawing_last = null
var drawing_last2 = null
var drawing_last_track = null
var pretty_tracks = true
var removing_track = false
var dragging_view = false
var dragging_view_reference = null
var dragging_view_camera_reference = null
var mouse_focus=true

signal grid_view_changed(p_pretty_tracks)

func setup_grid():
	for i in range(nx):
		cells.append([])
		for j in range(ny):
			cells[i].append(LayoutCell.new(i, j))
			add_child(cells[i][j])
			connect("grid_view_changed", cells[i][j], "_on_grid_view_changed")

func bresenham_line(startx, starty, stopx, stopy):
	if startx == stopx and starty == stopy:
		return [[startx, starty]]
	var points = []
	var deltax = stopx-startx
	var deltay = stopy-starty
	var px = startx
	var py = starty
	
	if deltax == 0:
		while py!=stopy:
			py+=int(sign(deltay))
			points.append([px,py])
		return points
	
	var ybyx = float(deltay)/float(deltax)
	var dist = 0.0
	
	while px!=stopx:
		px+=int(sign(deltax))
		dist += ybyx*sign(deltax)
		points.append([px, py])
		while abs(dist)>0.5:
			py += int(sign(dist))
			dist -= sign(dist)
			points.append([px, py])
	return points

func _ready():
	setup_grid()

func _draw():
	
	var spacing = LayoutInfo.spacing
	
	for i in range(nx+1):
		var start = Vector2(i*spacing, 0.0)
		var end = Vector2(i*spacing, ny*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)
	
	for j in range(ny+1):
		var start = Vector2(0.0, j*spacing)
		var end = Vector2(nx*spacing, j*spacing)
		draw_line(start, end, grid_line_color, grid_line_width, true)

func draw_track(draw_track):
	if draw_track == drawing_last2:
		drawing_last2 = null
		drawing_last_track = null
	if drawing_last2 != null:
		var slot0 = drawing_last.get_slot_to_cell(drawing_last2)
		var slot1 = drawing_last.get_slot_to_cell(draw_track)
		if slot1 == null or slot0 == null:
			drawing_last = draw_track
			drawing_last2 = null
			drawing_last_track = null
			return
		var track = drawing_last.create_track(slot0, slot1)
		track = drawing_last.add_track(track)
		if drawing_last_track != null:
			track.connect_track(slot0, drawing_last_track)
		drawing_last_track = track 
	drawing_last2 = drawing_last
	drawing_last = draw_track

func _unhandled_input(event):
	process_input(event)

func process_input(event):
	
	if event is InputEventKey and event.pressed:
		process_key_input(event)
	
	if event is InputEventMouse:
		process_mouse_input(event)

func process_key_input(event):
	pass

func process_mouse_input(event):
	var spacing = LayoutInfo.spacing
	var mpos = get_viewport_transform().affine_inverse()*event.position
	var i = int(mpos.x/spacing)
	var j = int(mpos.y/spacing)
	if not (i>=0 and i<nx and j>=0 and j<ny):
		return
	var mpos_cell = mpos-cells[i][j].position
	if event is InputEventMouseMotion:
		process_mouse_motion(event, i, j, mpos_cell)
	if event is InputEventMouseButton:
		process_mouse_button(event, i, j, mpos_cell)

func process_mouse_motion(event, i, j, mpos_cell):
	if hover_cell != null:
		hover_cell.stop_hover()
	if removing_track:
		cells[i][j].clear()
	if dragging_view:
		$Camera2D.position = $Camera2D.zoom*(dragging_view_reference-event.position) + dragging_view_camera_reference
	if drawing_track:
		if not cells[i][j] == drawing_last:
			var line = bresenham_line(drawing_last.x_idx, drawing_last.y_idx, i, j)
			for p in line:
				draw_track(cells[p[0]][p[1]])
	# else:
	# 	hover_cell = cells[i][j]
	# 	hover_cell.hover_at(mpos_cell, direction)

func process_mouse_button(event, i, j, mpos_cell):
	if event.button_index == BUTTON_WHEEL_UP:
		$Camera2D.position += event.position*0.05*$Camera2D.zoom	
		$Camera2D.zoom*=0.95
		return
		
	if event.button_index == BUTTON_WHEEL_DOWN:
		$Camera2D.zoom*=1.05
		$Camera2D.position -= event.position*0.05*$Camera2D.zoom
		return

	if event.button_index == BUTTON_LEFT:
		if event.pressed:
			if LayoutInfo.input_mode == "draw":
				drawing_last = cells[i][j]
				drawing_last2 = null
				drawing_track = true
				drawing_last_track = null #track
		else:
			if drawing_track:
				drawing_track = false
		return
	
	if event.button_index == BUTTON_RIGHT:
		if event.pressed:
			if LayoutInfo.input_mode == "draw":
				removing_track = true
				cells[i][j].clear()
		else:
			if removing_track:
				removing_track = false
		return
	
	if event.button_index == BUTTON_MIDDLE:
		if event.pressed:
			dragging_view = true
			dragging_view_reference = event.position
			dragging_view_camera_reference = $Camera2D.position
		else:
			if dragging_view:
				dragging_view = false
		return
