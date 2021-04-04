class_name LayoutCell
extends Node2D

var x_idx
var y_idx
var spacing
var tracks = {}
var hover_track = null
var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
var pretty_tracks = true

func _init(p_x_idx, p_y_idx, p_spacing):
	x_idx = p_x_idx
	y_idx = p_y_idx
	spacing = p_spacing
	
	position = Vector2(x_idx, y_idx)*spacing

func hover_at(pos, direction=null):
	hover_track = create_track_at(pos, direction)
	update()

func stop_hover():
	hover_track = null
	update()

func create_track_at(pos, direction=null):
	var i = 0
	var closest_dist = spacing+1
	var closest_track = null
	var normalized_pos = pos/spacing
	for orientation in orientations:
		var track = LayoutTrack.new(orientation[0], orientation[1], spacing)
		if direction!= null:
			if track.get_direction()!=direction:
				continue
		var dist = track.distance_to(normalized_pos)
		if dist<closest_dist:
			closest_track = track
			closest_dist = dist
	return closest_track

func get_slot_to_cell(cell):
	if cell.x_idx == x_idx+1 and cell.y_idx == y_idx:
		return "E"
	if cell.x_idx == x_idx-1 and cell.y_idx == y_idx:
		return "W"
	if cell.x_idx == x_idx and cell.y_idx == y_idx+1:
		return "S"
	if cell.x_idx == x_idx and cell.y_idx == y_idx-1:
		return "N"
	
func create_track(slot0, slot1):
	var track = LayoutTrack.new(slot0, slot1, spacing)
	return track
	
func add_track(track):
	if track.get_orientation() in tracks:
		print("can't add track, same orientation already occupied!")
		return tracks[track.get_orientation()]
	tracks[track.get_orientation()] = track
	add_child(track)
	track.connect("connections_changed", self, "_on_track_connections_changed")
	update()
	return track

func _on_track_connections_changed(orientation):
	update()

func _on_grid_view_changed(p_pretty_tracks):
	set_view(p_pretty_tracks)

func set_view(p_pretty_tracks):
	pretty_tracks = p_pretty_tracks
	for child in get_children():
		child.set_view(p_pretty_tracks)
	update()

func _draw():
	if hover_track != null:
		draw_line(hover_track.pos0*spacing, hover_track.pos1*spacing, Color(0.4,0.4,0.4), 4)