class_name LayoutTrack
extends Node

var x_idx
var y_idx
var slot0
var slot1
var pos0
var pos1
var connections = {}
var slots = ["N", "S", "E", "W"]
var route_lock=false
var hover=false
var hover_switch=null
var selected_solo=false
var selected=false

var switches = {}

var metadata = {}
var default_meta = {"selected": false, "hover": false}

var TrackInspector = preload("res://track_inspector.tscn")

const STATE_SELECTED = 1
const STATE_HOVER = 2
const STATE_LOCKED = 4
const STATE_BLOCK = 8
const STATE_BLOCK_OCCUPIED = 16
const STATE_BLOCK_HOVER = 32
const STATE_BLOCK_SELECTED = 64
const STATE_CONNECTED = 128
const STATE_SWITCH = 256
const STATE_SWITCH_PRIORITY = 512

signal connections_changed(orientation)
signal states_changed(orientation)
signal connections_cleared
signal route_lock_changed(lock)
signal switch_added(switch)
signal switch_position_changed(pos)
signal selected(obj)
signal unselected(obj)
signal removing(orientation)

func _init(p_slot0, p_slot1, i, j):
	slot0 = p_slot0
	slot1 = p_slot1

	assert_slot_degeneracy()
	connections[slot0] = {}
	connections[slot1] = {}
	pos0 = LayoutInfo.slot_positions[slot0]
	pos1 = LayoutInfo.slot_positions[slot1]
	switches[slot0] = null
	switches[slot1] = null
	metadata[slot0] = {"none": default_meta.duplicate()}
	metadata[slot1] = {"none": default_meta.duplicate()}
	
	x_idx = i
	y_idx = j
	
	assert(slot0 != slot1)
	assert(slot0 in slots and slot1 in slots)

func serialize():
	var result = {}
	result["x_idx"] = x_idx
	result["y_idx"] = y_idx
	result["slot0"] = slot0
	result["slot1"] = slot1
	var connections_result = {}
	for slot in connections:
		connections_result[slot] = []
		for turn in connections[slot]:
			connections_result[slot].append(turn)
	result["connections"] = connections_result
	return result

func get_cell():
	return LayoutInfo.cells[x_idx][y_idx]

func get_center():
	return (pos0 + pos1)*0.5

func get_tangent():
	return (pos1-pos0).normalized()

func load_connections(struct):
	for slot in struct:
		for turn in struct[slot]:
			var track = get_slot_cell(slot).get_turn_track_from(get_neighbour_slot(slot), turn)
			if track in connections[slot].values():
				continue
			connect_track(slot, track)
		
func get_slot_cell(slot):
	if slot=="N":
		return LayoutInfo.cells[x_idx][y_idx-1]
	if slot=="S":
		return LayoutInfo.cells[x_idx][y_idx+1]
	if slot=="W":
		return LayoutInfo.cells[x_idx-1][y_idx]
	if slot=="E":
		return LayoutInfo.cells[x_idx+1][y_idx]

func remove():
	clear_connections()
	emit_signal("removing", get_orientation())
	queue_free()

func is_switch(slot=null):
	if slot != null:
		return len(connections[slot]) > 1
	
	return len(connections[slot0]) > 1 or len(connections[slot1]) > 1

func get_turn_from(slot):
	var center_tangent = LayoutInfo.slot_positions[get_neighbour_slot(slot)] - LayoutInfo.slot_positions[slot]
	var tangent = get_slot_tangent(get_opposite_slot(slot))
	var turn_angle = center_tangent.angle_to(tangent)
	if turn_angle > PI:
		turn_angle -= 2*PI
	if is_equal_approx(turn_angle, 0.0):
		return "center"
	if turn_angle > 0.0:
		return "right"
	return "left"

func assert_slot_degeneracy():
	var orientations = ["NS", "NE", "NW", "SE", "SW", "EW"]
	if not get_orientation() in orientations:
		var temp = slot0
		slot0 = slot1
		slot1 = temp

func get_orientation():
	return slot0+slot1

func get_direction():
	if get_orientation() in ["NS", "SN"]:
		return 0
	if get_orientation() in ["SE", "ES", "NW", "WN"]:
		return 1
	if get_orientation() in ["EW", "WE"]:
		return 2
	if get_orientation() in ["NE", "EN", "SW", "WS"]:
		return 3

func distance_to(pos):
	var point = Geometry.get_closest_point_to_segment_2d(pos, pos0, pos1)
	return (point-pos).length()

func can_connect_track(slot, track):
	if not slot in connections:
		return false
	if not get_neighbour_slot(slot) in track.connections:
		return false
	if track == self:
		return false
	if track in connections[slot].values():
		return false
	return true

func connect_track(slot, track, initial=true):
	if not slot in connections:
		push_error("[LayoutTrack] can't connect track to a nonexistent slot!")
		return
	if not get_neighbour_slot(slot) in track.connections:
		push_error("[LayoutTrack] can't connect track with a incompatible orientation!")
		return
	if track == self:
		push_error("[LayoutTrack] can't connect track to itself!")
		return
	if track in connections[slot].values():
		push_error("[LayoutTrack] track is already connected at this slot!")
		return
	# prints("connected a track", track.get_orientation(), "with this track", get_orientation())
	var turn = track.get_turn_from(get_neighbour_slot(slot))
	connections[slot][turn] = track
	metadata[slot][turn] = default_meta.duplicate()
	# prints("added connection, turning:", turn)
	track.connect("connections_cleared", self, "_on_track_connections_cleared")
	if len(connections[slot])>1:
		update_switch(slot)
	if initial:
		track.connect_track(get_neighbour_slot(slot), self, false)
	emit_signal("connections_changed", get_orientation())
	emit_signal("states_changed", get_orientation())

func update_switch(slot):
	if len(connections[slot])>1:
		if switches[slot] != null:
			switches[slot].queue_free()
			switches[slot] = null
		switches[slot] = LayoutSwitch.new(slot, connections[slot].keys())
		switches[slot].connect("position_changed", self, "_on_switch_position_changed")
		switches[slot].connect("state_changed", self, "_on_switch_state_changed")
		emit_signal("switch_added", switches[slot])
		_on_switch_position_changed(slot, switches[slot].get_position())
		add_child(switches[slot])
	else:
		if switches[slot] != null:
			switches[slot].queue_free()
			if hover_switch == switches[slot]:
				hover_switch.stop_hover()
				hover_switch = null
			switches[slot] = null
	
func has_switch():
	return switches[slot0] != null or switches[slot1] != null

func borders_switch():
	for slot in connections:
		for track in connections[slot].values():
			if track.is_switch(get_neighbour_slot(slot)):
				return true
	return false

func _on_switch_state_changed(slot):
	emit_signal("states_changed", get_orientation())
	for track in connections[slot].values():
		track.emit_signal("states_changed", track.get_orientation())

func _on_switch_position_changed(slot, pos):
	emit_signal("connections_changed", get_orientation())
	for track in connections[slot].values():
		track.emit_signal("connections_changed", track.get_orientation())

func get_switch(slot):
	return switches[slot]

func get_opposite_switch(slot, turn):
	var to_track = connections[slot][turn]
	return to_track.switches[to_track.get_neighbour_slot(slot)]

func get_connection_switches(slot, turn):
	var switch_list = []
	if switches[slot] != null:
		switch_list.append(switches[slot])
	var opposite_switch = get_opposite_switch(slot, turn)
	if opposite_switch != null:
		switch_list.append(opposite_switch)
	return switch_list

func _on_track_connections_cleared(track):
	disconnect_track(track)

func disconnect_track(track):
	for slot in [slot0, slot1]:
		for turn in connections[slot]:
			if connections[slot][turn] == track:
				disconnect_turn(slot, turn)

func disconnect_turn(slot, turn):
	connections[slot].erase(turn)
	metadata[slot].erase(turn)
	if len(connections[slot]) > 0:
		update_switch(slot)
	emit_signal("connections_changed", get_orientation())

func clear_connections():
	for slot in [slot0, slot1]:
		for turn in connections[slot]:
			disconnect_turn(slot, turn)
	emit_signal("connections_cleared", self)

func get_neighbour_slot(slot):
	if slot == "N":
		return "S"
	if slot == "S":
		return "N"
	if slot == "E":
		return "W"
	if slot == "W":
		return "E"

func get_opposite_slot(slot):
	if slot0 == slot:
		return slot1
	elif slot1 == slot:
		return slot0
	push_error("[LayoutTrack.get_opposite_slot] track doesn't contain " + slot)

func get_connected_slot(track):
	for slot in connections:
		if track in connections[slot].values():
			return slot
	return null

func get_connection_to(track):
	for slot in connections:
		if track in connections[slot].values():
			var turn = track.get_turn_from(get_neighbour_slot(slot))
			return {"slot": slot, "turn": turn}
	assert(false)

func get_next_tracks_from(slot):
	return get_next_tracks_at(get_opposite_slot(slot))

func directed_iter(neighbour_to):
	var to_slot = get_opposite_slot(get_neighbour_slot(neighbour_to))
	return [to_slot, connections[to_slot]]
	
func get_next_tracks_at(slot):
	return connections[slot]
	push_error("[LayoutTrack.get_next_tracks_at] track doesn't contain " + slot)

func get_slot_tangent(slot):
	if slot == slot1:
		return pos1-pos0
	return pos0-pos1

func get_slot_pos(slot):
	return LayoutInfo.slot_positions[slot]

func has_point(pos):
	pass
	
func get_switch_at(pos):
	for slot in switches:
		if switches[slot] != null:
			if (LayoutInfo.slot_positions[slot]-pos).length() < 0.3:
				return switches[slot]
	return null

func hover(pos):

	var hover_candidate = get_switch_at(pos)
	if LayoutInfo.input_mode == "draw":
		hover_candidate = null
	
	if hover_candidate != hover_switch:
		if hover_switch != null:
			hover_switch.stop_hover()
		hover_switch = hover_candidate
		if hover_switch != null:
			set_connection_attribute(slot0, "none", "hover", false)
			set_connection_attribute(slot1, "none", "hover", false)
			emit_signal("states_changed", get_orientation())
			hover_switch.hover()
	if hover_candidate != null:
		return

	set_connection_attribute(slot0, "none", "hover", true)
	set_connection_attribute(slot1, "none", "hover", true)
	emit_signal("states_changed", get_orientation())

func stop_hover():
	set_connection_attribute(slot0, "none", "hover", false)
	set_connection_attribute(slot1, "none", "hover", false)
	if hover_switch != null:
		hover_switch.stop_hover()
		hover_switch = null
	emit_signal("states_changed", get_orientation())

func select():
	selected_solo=true
	emit_signal("selected", self)
	visual_select()
	LayoutInfo.select(self)

func visual_select():
	set_connection_attribute(slot0, "none", "selected", true)
	set_connection_attribute(slot1, "none", "selected", true)
	emit_signal("states_changed", get_orientation())

func unselect():
	selected_solo=false
	visual_unselect()
	emit_signal("unselected", self)
	
func visual_unselect():
	set_connection_attribute(slot1, "none", "selected", false)
	emit_signal("states_changed", get_orientation())

func _unhandled_input(event):
	if event is InputEventKey:
		if event.scancode == KEY_DELETE and event.pressed:
			if selected_solo:
				for slot in connections:
					for track in connections[slot].values():
						track.call_deferred("select")
				remove()

func process_mouse_button(event, pos):
	if event.button_index == BUTTON_LEFT and event.pressed:
		var switch = get_switch_at(pos)
		if LayoutInfo.input_mode == "draw":
			switch = null
		if switch != null:
			switch.process_mouse_button(event, pos)
			return
		
		if LayoutInfo.input_mode == "select":
			LayoutInfo.init_drag_select(self)
		
		if LayoutInfo.input_mode == "draw":
			LayoutInfo.init_connected_draw_track(self)

func get_inspector():
	var inspector = TrackInspector.instance()
	inspector.set_track(self)
	return inspector

func set_connection_attribute(slot, turn, key, value):
	if value == null:
		metadata[slot][turn].erase(key)
	else:
		metadata[slot][turn][key] = value
	emit_signal("states_changed", get_orientation())

func set_track_connection_attribute(track, key, value):
	var connection = get_connection_to(track)
	set_connection_attribute(connection.slot, connection.turn, key, value)

func get_shader_states(to_slot):
	var states = {"left": 0, "right": 0, "center": 0, "none": 0}
	for turn in metadata[to_slot]:
		states[turn] = get_shader_state(to_slot, turn)
	return states

func get_shader_state(to_slot, turn):
	var state = 0
	if "block" in metadata[to_slot][turn]:
		state |= STATE_BLOCK
	if turn in connections[to_slot]:
		state |= STATE_CONNECTED
	if turn == "none" and len(connections[to_slot])==0:
		state |= STATE_CONNECTED
	if turn != "none" and turn in connections[to_slot]:
		var opposite_switch = get_opposite_switch(to_slot, turn)
		var opposite_turn = get_turn_from(to_slot)
		if opposite_switch != null:
			if opposite_switch.selected:
				state |= STATE_SELECTED
			if opposite_switch.hover:
				state |= STATE_HOVER
			if opposite_turn == opposite_switch.get_position():
				state |= STATE_SWITCH

		if switches[to_slot] != null:
			if switches[to_slot].selected:
				state |= STATE_SELECTED
			if switches[to_slot].hover:
				state |= STATE_HOVER
			if not switches[to_slot].disabled and switches[to_slot].get_position() == turn:
				state |= STATE_SWITCH
				state |= STATE_SWITCH_PRIORITY
		
	if metadata[to_slot][turn]["selected"]:
		state |= STATE_SELECTED
	if metadata[to_slot][turn]["hover"]:
		state |= STATE_HOVER
	return state

func get_tangent_to(slot):
	if slot == slot1:
		return get_tangent()
	return -get_tangent()

func get_turn_angle(slot, turn):
	var next_track = connections[slot][turn]
	var tangent = get_tangent_to(slot)
	var neighbour_slot = get_neighbour_slot(slot)
	var next_tangent = -next_track.get_tangent_to(neighbour_slot)
	var angle = tangent.angle_to(next_tangent)
	while angle>PI:
		angle-=2*PI
	while angle<-PI:
		angle += 2*PI
	return angle
	
func get_turn_radius(angle):
	if is_equal_approx(angle, 0.0):
		return 0.0
	if is_equal_approx(abs(angle), 0.25*PI):
		return 0.5+0.25*sqrt(2.0)
	if is_equal_approx(abs(angle),PI*0.5):
		return 0.25*sqrt(2.0)
	push_error("[get_connection_radius] invalid angle to next track!")

func get_interpolation_parameters(slot, turn):
	var angle = get_turn_angle(slot, turn)
	var turn_sign = sign(angle)
	var neigbour_slot = get_neighbour_slot(slot)
	var from_slot = slot0
	if slot == slot0:
		from_slot = slot1
	var from_pos = get_slot_pos(from_slot)
	var to_pos = get_slot_pos(slot)
	var aligned_vector = get_slot_pos(slot)-get_slot_pos(neigbour_slot)
	var tangent = get_tangent_to(slot)
	var arc_start
	var straight_start
	if tangent.dot(aligned_vector)>0.99:
		arc_start = to_pos-aligned_vector*(0.25*sqrt(2))
		straight_start = 0.5*(to_pos+from_pos)
	else:
		arc_start = 0.5*(to_pos+from_pos)
		straight_start = arc_start
	var radius = get_turn_radius(angle)
	var center = arc_start + tangent.rotated(0.5*PI*turn_sign)*radius
	var start_angle = tangent.angle()-0.5*PI*turn_sign
	var stop_angle = start_angle + 0.5*angle
	var arc_length = abs(0.5*radius*angle)
	if is_equal_approx(radius, 0.0):
		arc_length = (to_pos-arc_start).length()
	var straight_length = (arc_start - straight_start).length()
	var connection_length = arc_length + straight_length
	
	return {"from_pos": from_pos,
			"to_pos": to_pos,
			"center": center,
			"radius": radius,
			"start_angle": start_angle,
			"stop_angle": stop_angle,
			"angle": angle,
			"straight_start": straight_start,
			"arc_start": arc_start,
			"arc_length": arc_length,
			"straight_length": straight_length,
			"connection_length": connection_length}

func get_connection_length(slot, turn):
	return get_interpolation_parameters(slot, turn).connection_length

func interpolate_connection(to_slot, turn, t, normalized=false):
	var params = get_interpolation_parameters(to_slot, turn)
	var x = t
	if normalized:
		x = t*params.connection_length
	if is_equal_approx(params.radius, 0.0):
		return lerp(params.straight_start, params.to_pos, x/params.connection_length)
	if x<params.straight_length:
		return lerp(params.straight_start, params.arc_start, x/params.straight_length)
	var angle = lerp(params.start_angle, params.stop_angle, (x-params.straight_length)/params.arc_length)
	return params.center + params.radius*Vector2(1.0,0.0).rotated(angle)

func interpolate_track_connection(track, t, normalized=false):
	var connection = get_connection_to(track)
	var reverse_connection = track.get_connection_to(self)
	var this_length = get_connection_length(connection.slot, connection.turn)
	var reverse_length = track.get_connection_length(reverse_connection.slot, reverse_connection.turn)
	var total_length = this_length + reverse_length
	var x = t
	if normalized:
		x = t*total_length
	printt(total_length, this_length, reverse_length, x)
	if x<this_length:
		return interpolate_connection(connection.slot, connection.turn, x, false)
	var pos = track.interpolate_connection(reverse_connection.slot, reverse_connection.turn, total_length-x, false)
	pos += Vector2(track.x_idx-x_idx, track.y_idx-y_idx)
	return pos

func interpolate_position_linear(from_slot, t):
	var to_slot = get_opposite_slot(from_slot)
	var from_pos = get_slot_pos(from_slot)
	var to_pos = get_slot_pos(to_slot)
	if t>=1.0:
		return to_pos
	if t<=0.0:
		return from_pos
	return from_pos + (to_pos-from_pos)*t

