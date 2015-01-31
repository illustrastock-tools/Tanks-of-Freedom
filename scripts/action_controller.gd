
var root_node
var abstract_map = preload('abstract_map.gd').new()
var ysort
var selector
var active_field = null
var active_indicator = preload('res://gui/selector.xscn').instance()
var battle_controller = preload('battle_controller.gd').new()
var movement_controller = preload('movement_controller.gd').new()
var hud_controller = preload('hud_controller.gd').new()
var sample_player

var current_player = 1
var player_ap = 10
var player_ap_max = 15
var turn = 1
var title
var camera
var camera_zoom_range = [1,6]

var game_ended = false

func handle_action(position):
	if game_ended:
		return
	
	var field = abstract_map.get_field(position)
	
	if field.object != null:
		if active_field != null:
			if field.object.group == 'unit' && active_field.object.group == 'unit':
				if active_field.is_adjacent(field) && field.object.player != current_player && self.has_ap():
					self.use_ap()
					if (battle_controller.can_attack(active_field.object, field.object)):
						if (battle_controller.resolve_fight(active_field.object, field.object)):
							if (field.object.type == 0):
								sample_player.play('hurt')
							else:
								sample_player.play('explosion')
							self.despawn_unit(field)
							hud_controller.update_unit_card(active_field.object)
							return
						else:
							sample_player.play('not_dead')
					else:
						sample_player.play('no_attack')
						return
				else:
					sample_player.play('no_move')
					
					hud_controller.update_unit_card(active_field.object)
			if active_field.object.group == 'unit' && active_field.object.type == 0 && field.object.group == 'building' && field.object.player != current_player:
				if active_field.is_adjacent(field) && movement_controller.can_move(active_field, field) && self.has_ap():
					self.use_ap()
					field.object.claim(current_player)
					sample_player.play('pickup_box')
					self.despawn_unit(active_field)
					self.activate_field(field)
					if field.object.type == 0:
						self.end_game()
						return
		if (field.object.group == 'unit' || field.object.group == 'building') && field.object.player == current_player:
			self.activate_field(field)
	else:
		if active_field != null && active_field.object != null && field != active_field && field.object == null:
			if active_field.object.group == 'unit' && active_field.is_adjacent(field) && field.terrain_type != -1 && self.has_ap():
				if movement_controller.move_object(active_field, field):
					sample_player.play('move')
					self.activate_field(field)
					self.use_ap()
				else:
					sample_player.play('no_moves')

func init_root(root):
	root_node = root
	abstract_map.tilemap = root.get_node("/root/game/pixel_scale/map")
	camera = root.get_node('/root/game/pixel_scale')
	ysort = root.get_node('/root/game/pixel_scale/map/YSort')
	selector = root.get_node('/root/game/pixel_scale/map/selector')
	sample_player = root.get_node("/root/game/SamplePlayer")
	self.import_objects()
	hud_controller.init_root(root, self)
	hud_controller.set_turn(turn)
	hud_controller.show_in_game_card(["New mission!","Buy your first unit in the bunker and send it to take control of the barracks."])

func activate_field(field):
	self.clear_active_field()
	active_field = field
	abstract_map.tilemap.add_child(active_indicator)
	abstract_map.tilemap.move_child(active_indicator,0)
	var position = Vector2(abstract_map.tilemap.map_to_world(field.position))
	position.y += 2
	active_indicator.set_pos(position)
	sample_player.play('select')
	if field.object.group == 'unit':
		hud_controller.show_unit_card(field.object)
	if field.object.group == 'building':
		hud_controller.show_building_card(field.object)

func clear_active_field():
	active_field = null
	abstract_map.tilemap.remove_child(active_indicator)
	hud_controller.clear_unit_card()
	hud_controller.clear_building_card()

func despawn_unit(field):
	ysort.remove_child(field.object)
	field.object.queue_free()
	field.object = null

func spawn_unit_from_active_building():
	if active_field == null || active_field.object.group != 'building':
		return
	var spawn_point = abstract_map.get_field(active_field.object.spawn_point)
	var required_ap = active_field.object.get_required_ap()
	if spawn_point.object == null && self.has_enough_ap(required_ap):
		var unit = active_field.object.spawn_unit(current_player)
		ysort.add_child(unit)
		unit.set_pos_map(spawn_point.position)
		spawn_point.object = unit
		self.deduct_ap(required_ap)
		sample_player.play('spawn')

func import_objects():
	self.attach_objects(root_node.get_tree().get_nodes_in_group("units"))
	self.attach_objects(root_node.get_tree().get_nodes_in_group("buildings"))
	self.attach_objects(root_node.get_tree().get_nodes_in_group("terrain"))

func attach_objects(collection):
	for entity in collection:
		abstract_map.get_field(entity.get_initial_pos()).object = entity
		
func end_turn():
	sample_player.play('end_turn')
	if current_player == 0:
		self.switch_to_player(1)
		abstract_map.tilemap.move_to_map(Vector2(22,3)) # <- podac prawdziwa pozycje bunkra
	else:
		self.switch_to_player(0)
		abstract_map.tilemap.move_to_map(Vector2(1,12)) # <- podac prawdziwa pozycje bunkra
		turn += 1
	hud_controller.set_turn(turn)
	if current_player == 0:
		title = "Blue turn"
	else:
		title = "Red turn"
	hud_controller.show_in_game_card([title, "Take the control of the enemy bunker!"])
func in_game_menu_pressed():
	hud_controller.close_in_game_card()

func has_ap():
	if player_ap > 0:
		return true
	
	sample_player.play('no_moves')
	return false
	
func has_enough_ap(ap):
	if player_ap >= ap:
		return true
	return false

func use_ap():
	self.deduct_ap(1)

func deduct_ap(ap):
	self.update_ap(player_ap - ap)
	
func update_ap(ap):
	player_ap = ap
	hud_controller.update_ap(player_ap)
	if player_ap == 0:
		hud_controller.warn_end_turn()

func switch_to_player(player):
	self.clear_active_field()
	current_player = player
	self.reset_player_units(player)
	selector.set_player(player);
	self.update_ap(player_ap_max)

func reset_player_units(player):
	var units = root_node.get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.player == player:
			unit.reset_ap()
			
func end_game():
	self.clear_active_field()
	game_ended = true
	hud_controller.show_win(current_player)
	selector.hide()
	
func camera_zoom_in():
	var scale = camera.get_scale()
	if scale.x < camera_zoom_range[1]:
		camera.set_scale(scale + Vector2(1,1))
	
func camera_zoom_out():
	var scale = camera.get_scale()
	if scale.x > camera_zoom_range[0]:
		camera.set_scale(scale - Vector2(1,1))