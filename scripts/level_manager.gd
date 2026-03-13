extends Node2D

@export var light_start: Vector2i = Vector2i(0, 5)
@export var max_trenches: int = 5
@export var max_turns: int = 10
@export var next_level_scene: PackedScene

@onready var button_click: AudioStreamPlayer = $ButtonClick
@onready var losing_sound: AudioStreamPlayer = $LosingSound
@onready var winning_sound: AudioStreamPlayer = $WinningSound
@onready var sfx_dig = $SfxDig
@onready var sfx_fill = $SfxFill
@onready var sfx_zap = $SfxZap
@onready var sfx_error = $SfxError
@onready var sfx_plantgrowth: AudioStreamPlayer = $Sparkle
@onready var sfx_scarecrow_rotating: AudioStreamPlayer = $ScarecrowRotating
@onready var sfx_chomp: AudioStreamPlayer = $SfxChomp
@onready var win_screen: Control = $UILayer/WinScreen
@onready var loss_screen: Control = $UILayer/LossScreen
@onready var win_anim: AnimatedSprite2D = $UILayer/WinScreen/AnimatedSprite2D
@onready var trench_label: Label = $UILayer/HUD/TrenchLabel
@onready var end_turn_button: Button = $UILayer/HUD/EndTurnButton
@onready var turn_label: Label = $UILayer/HUD/TurnLabel


var trenches_used: int = 0
var turns_taken: int = 0
var is_game_over: bool = false

const GRID_WIDTH = 12
const GRID_HEIGHT = 10

const ID_SCARECROW_HEAD_FORWARD = 40 
const ID_SCARECROW_HEAD_BACKWARD = 41
const ID_SCARECROW_SKIRT = 43

const ID_DIRT1 = 2
const ID_DIRT2 = 3
const ID_CROP = 39
const ID_MIRROR_SLASH = 5
const ID_MIRROR_BACKSLASH = 6
const ID_PUMP = 37
const ID_PEST = 38

enum TileState {
	DIRT = 0,             # Dirt 1 and Dirt 2 both map to this!
	CROP = 1,
	MIRROR_SLASH = 2,
	TRENCH = 3,
	OBSTACLE = 4,
	PUMP = 5,
	WATERED_TRENCH = 6,
	MIRROR_BACKSLASH = 7,
	PEST = 8
}
var trench_graphics_map = {
	0: 9,  # No connections (Standalone dot)
	1: 30,  # Only Up (End piece)
	2: 29,  # Only Right (End piece)
	3: 12,  # Up + Right (Bottom-Left Corner) -> Your "B-L_cor"
	4: 27,  # Only Down (End piece)
	5: 9,  # Up + Down (Vertical Straight)
	6: 13,  # Right + Down (Top-Left Corner) -> Your "T-L_cor"
	7: 14,  # Up + Right + Down (T-Junction)
	8: 28,  # Only Left (End piece)
	9: 10,  # Up + Left (Bottom-Right Corner) -> Your "B-R_cor"
	10: 31, # Right + Left (Horizontal Straight)
	11: 32, # Up + Right + Left (T-Junction)
	12: 11, # Down + Left (Top-Right Corner) -> Your "T-R_cor"
	13: 15, # Up + Down + Left (T-Junction)
	14: 33, # Right + Down + Left (T-Junction)
	15: 36  # All 4 directions (Crossroads)
}
var watered_trench_graphics_map = {
	0: 1,  # No connections (Standalone dot)
	1: 26,  # Only Up (End piece)
	2: 25,  # Only Right (End piece)
	3: 20,  # Up + Right (Bottom-Left Corner)
	4: 23,  # Only Down (End piece)
	5: 0,  # Up + Down (Vertical Straight)
	6: 22,  # Right + Down (Top-Left Corner)
	7: 17,  # Up + Right + Down (T-Junction)
	8: 24,  # Only Left (End piece)
	9: 19,  # Up + Left (Bottom-Right Corner)
	10: 1, # Right + Left (Horizontal Straight)
	11: 4, # Up + Right + Left (T-Junction)
	12: 21, # Down + Left (Top-Right Corner)
	13: 16, # Up + Down + Left (T-Junction)
	14: 18, # Right + Down + Left (T-Junction)
	15: 34  # All 4 directions (Crossroads)
}

# Our 2D matrix
var grid_data = []
@onready var hover_cursor: Sprite2D = $HoverCursor
@onready var hover_shadow: Sprite2D = $HoverCursor/Shadow
@onready var tilemap = $TileMapLayer
@onready var light_layer = $LightLayer
@onready var objects_layer: TileMapLayer = $TileMapLayer3

var light_direction = Vector2i(1, 0) # Moving right (x: 1, y: 0)

var pump_pos = Vector2i(2, 0)

@onready var highlight_layer = $HighlightLayer

var active_pests = []
var active_crops = []
var crop_anim_frame = 0

var active_scarecrows = []
# Map the logical state directly to your specific Head IDs!
var scarecrow_head_map = {
	TileState.MIRROR_SLASH: ID_SCARECROW_HEAD_FORWARD,
	TileState.MIRROR_BACKSLASH: ID_SCARECROW_HEAD_BACKWARD
}

func _ready():
	print("Building the farm...") # <--- ADD THIS LINE
	_initialize_grid()
	calculate_water_flow()
	calculate_light_beam()
	calculate_pest_intents()
	update_trench_visuals()
	update_scarecrow_visuals()
	update_hud()

func _process(delta): 
	var mouse_pos = get_global_mouse_position()
	var grid_pos = tilemap.local_to_map(mouse_pos)
	
	if _is_within_bounds(grid_pos.x, grid_pos.y):
		
		var target_layer = objects_layer
		var source_id = target_layer.get_cell_source_id(grid_pos)
		
		# If the object layer is empty, check the ground layer
		if source_id == -1:
			target_layer = tilemap
			source_id = target_layer.get_cell_source_id(grid_pos)
			
		if source_id != -1:
			var atlas_coords = target_layer.get_cell_atlas_coords(grid_pos)
			var tile_source = target_layer.tile_set.get_source(source_id) as TileSetAtlasSource
			
			if tile_source:
				hover_cursor.texture = tile_source.texture
				hover_shadow.texture = tile_source.texture
				hover_cursor.region_enabled = true
				hover_shadow.region_enabled = true
				var region = tile_source.get_tile_texture_region(atlas_coords)
				hover_cursor.region_rect = region
				hover_shadow.region_rect = region
				
				# --- THE SMOOTHNESS & JUICE ---
				var ground_pos = target_layer.map_to_local(grid_pos)
				var lifted_pos = ground_pos + Vector2(0, -6) # Target height
				
				# If it just appeared, snap it to the ground so it visibly "pops" up
				if not hover_cursor.visible:
					hover_cursor.global_position = ground_pos
					hover_cursor.scale = Vector2(1.0, 1.0)
					hover_cursor.visible = true
					
				# Smoothly glide the position and scale
				hover_cursor.global_position = hover_cursor.global_position.lerp(lifted_pos, 20.0 * delta)
				hover_cursor.scale = hover_cursor.scale.lerp(Vector2(1.15, 1.15), 15.0 * delta)
				
				# --- THE VISUAL DISTINCTNESS ---
				# Overdrive the RGB values past 1.0 to make it glow and look distinct!
				hover_cursor.modulate = Color(1.3, 1.3, 1.3, 1.0) 
				
				# Lock the shadow safely to the ground beneath it
				hover_shadow.global_position = ground_pos + Vector2(0, 4)
				hover_shadow.scale = Vector2(1.0, 1.0) / hover_cursor.scale 
				
	else:
		hover_cursor.visible = false

func _initialize_grid():
	# 1. Clear out any old data (great for when you add a "Restart Level" button later!)
	grid_data.clear()
	trenches_used = 0
	turns_taken = 0
	is_game_over = false
	active_pests.clear()
	active_crops.clear()
	
	# 2. Sweep the entire board from top-left to bottom-right
	for x in range(GRID_WIDTH):
		var column = []
		for y in range(GRID_HEIGHT):
			var cell_pos = Vector2i(x, y)
			var object_id = objects_layer.get_cell_source_id(cell_pos)
			var source_id = tilemap.get_cell_source_id(cell_pos)
			
			# Default logical state is Dirt
			var state = TileState.DIRT
			
			# Check the Source ID to figure out what object this is
			if object_id == ID_CROP:
				state = TileState.CROP
				active_crops.append({
					"pos": cell_pos,
					"stage": 0,          # Starts at Stage 0 (Frames 0 to 5)
					"is_watered": false,
					"is_lit": false
				})
				
			elif source_id == ID_MIRROR_SLASH:
				state = TileState.MIRROR_SLASH
				active_scarecrows.append(cell_pos)
				
			elif source_id == ID_MIRROR_BACKSLASH:
				state = TileState.MIRROR_BACKSLASH
				active_scarecrows.append(cell_pos)
				
			elif object_id == ID_PEST:
				state = TileState.PEST
				active_pests.append({
					"current_pos": cell_pos,
					"next_pos": cell_pos, 
					"alive": true
				})
				
			elif source_id == ID_PUMP:
				state = TileState.PUMP
				pump_pos = cell_pos 
			
			# NEW: The scanner doesn't need to change the visual for dirt! 
			# It just needs to record it logically.
				
			column.append(state)
			
			# Safety net: If you left a cell completely blank (-1), paint Dirt 1 there as a fallback
			if source_id == -1:
				tilemap.set_cell(cell_pos, ID_DIRT1, Vector2i(0, 0))
				
		grid_data.append(column)
	
func _unhandled_input(event):
	if is_game_over: return
	
	if event.is_action_pressed("ui_accept"): 
		execute_enemy_turn()
	
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = tilemap.local_to_map(mouse_pos)
		
		if _is_within_bounds(grid_pos.x, grid_pos.y):
			# LEFT CLICK = Dig Trench
			if event.button_index == MOUSE_BUTTON_LEFT:
				interact_with_cell(grid_pos.x, grid_pos.y)
			# RIGHT CLICK = Fill Trench
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				fill_trench(grid_pos.x, grid_pos.y)
func _is_within_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

func interact_with_cell(x: int, y: int):
	# If the cell is dirt, dig a trench!
	if grid_data[x][y] == TileState.DIRT:
		if trenches_used < max_trenches:
			grid_data[x][y] = TileState.TRENCH
			trenches_used += 1 # Consume a trench
			update_hud()
			sfx_dig.play()
			print("Dug a trench. Trenches used: ", trenches_used, "/", max_trenches)
			
			calculate_water_flow()
			calculate_light_beam()
		else:
			sfx_error.play()
			print("You are out of trenches!")
	
	
	elif grid_data[x][y] == TileState.MIRROR_SLASH:
		grid_data[x][y] = TileState.MIRROR_BACKSLASH
		sfx_scarecrow_rotating.play()
		print("Rotated mirror to \\")
		calculate_light_beam() # Recalculate the laser!
		update_scarecrow_visuals()
	elif grid_data[x][y] == TileState.MIRROR_BACKSLASH:
		grid_data[x][y] = TileState.MIRROR_SLASH
		sfx_scarecrow_rotating.play()
		print("Rotated mirror to /")
		calculate_light_beam()
		update_scarecrow_visuals()
	
	
func calculate_water_flow():
	# 1. THE RESET: Dry up all existing water first
	var old_water_count = 0
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid_data[x][y] == TileState.WATERED_TRENCH:
				old_water_count += 1
				grid_data[x][y] = TileState.TRENCH
				

	# 2. THE SETUP: Create a queue for our BFS, starting at the pump
	var queue = []
	queue.append(pump_pos)
	var new_water_count = 0
	# Directions we can flow: Right, Left, Down, Up
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), 
		Vector2i(0, 1), Vector2i(0, -1)
	]

	# 3. THE SPREAD: Loop until the queue is empty
	while queue.size() > 0:
		var current_cell = queue.pop_front() # Get the first item in line
		
		# Check all 4 neighbors around the current cell
		for dir in directions:
			var neighbor_x = current_cell.x + dir.x
			var neighbor_y = current_cell.y + dir.y
			
			# Ensure we don't check outside the map boundaries
			if _is_within_bounds(neighbor_x, neighbor_y):
				
				# If the neighbor is a dry trench, fill it!
				if grid_data[neighbor_x][neighbor_y] == TileState.TRENCH:
					# Update the logic
					new_water_count += 1
					grid_data[neighbor_x][neighbor_y] = TileState.WATERED_TRENCH
					# Add this newly wet trench to the queue so water can spread FROM it
					queue.append(Vector2i(neighbor_x, neighbor_y))
	if new_water_count > old_water_count:
		sfx_fill.play()
	update_crops()
	update_trench_visuals()

func fill_trench(x: int, y: int):
	# Make sure we are only filling in trenches, not the pump or existing dirt
	if grid_data[x][y] == TileState.TRENCH or grid_data[x][y] == TileState.WATERED_TRENCH:
		# 1. Update the logic array back to DIRT
		grid_data[x][y] = TileState.DIRT
		
		# 2. Update the visual back to the Red Square (Atlas 0,0). 
		# Note: Make sure the Source ID here (the middle number) matches the '1' you used to fix the invisible tiles!
		sfx_dig.play()
		tilemap.set_cell(Vector2i(x, y), ID_DIRT1, Vector2i(0, 0))
		trenches_used -= 1
		update_hud()
		print("Filled trench at: ", x, ", ", y)
		
		# 3. Recalculate! This will instantly dry up any yellow trenches that are no longer connected to the pump.
		calculate_water_flow()
		calculate_light_beam()
		update_trench_visuals()

func update_crops():
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for crop in active_crops:
		crop["is_watered"] = false # Reset first
		for dir in directions:
			var neighbor = crop["pos"] + dir
			if _is_within_bounds(neighbor.x, neighbor.y):
				if grid_data[neighbor.x][neighbor.y] == TileState.WATERED_TRENCH:
					crop["is_watered"] = true
					break

func calculate_light_beam():
	# 1. THE RESET: Clear all old light from the glass layer
	light_layer.clear()
	for crop in active_crops:
		crop["is_lit"] = false
	light_layer.modulate = Color(1.2, 1.1, 0.2, 0.6)
	
	var current_pos = light_start
	var current_dir = light_direction
	
	# 3. THE BEAM: Keep moving forward until we hit the edge of the map
	while _is_within_bounds(current_pos.x, current_pos.y):
		
		light_layer.set_cell(current_pos, 2, Vector2i(3, 0))
		var cell_under_light = grid_data[current_pos.x][current_pos.y]
		
		# If it hits a '/' mirror
		if cell_under_light == TileState.MIRROR_SLASH:
			if is_powered(current_pos.x, current_pos.y):
				current_dir = Vector2i(-current_dir.y, -current_dir.x) 
				print("Powered / mirror reflected light!")
			else:
				print("Unpowered / mirror ignored light.")
		
		# If it hits a '\' mirror
		elif cell_under_light == TileState.MIRROR_BACKSLASH:
			if is_powered(current_pos.x, current_pos.y):
				current_dir = Vector2i(current_dir.y, current_dir.x)
				print("Powered \\ mirror reflected light!")
			else:
				print("Unpowered \\ mirror ignored light.")
		
		# If it hits a Crop
		elif cell_under_light == TileState.CROP:
			for crop in active_crops:
				if crop["pos"] == current_pos:
					crop["is_lit"] = true
		
		elif cell_under_light == TileState.PEST:
			print("ZAPPED A PEST at: ", current_pos, "!")
			sfx_zap.play()
			grid_data[current_pos.x][current_pos.y] = TileState.DIRT
			objects_layer.set_cell(current_pos, -1)
			tilemap.set_cell(current_pos, ID_DIRT1, Vector2i(0, 0))
			for pest in active_pests:
				if pest["current_pos"] == current_pos:
					pest["alive"] = false
			calculate_pest_intents()
			break
		# Take one step forward in whatever the current direction is
		current_pos += current_dir

func is_powered(x: int, y: int) -> bool:
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), 
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	# Check all 4 neighbors
	for dir in directions:
		var neighbor_x = x + dir.x
		var neighbor_y = y + dir.y
		
		if _is_within_bounds(neighbor_x, neighbor_y):
			if grid_data[neighbor_x][neighbor_y] == TileState.WATERED_TRENCH:
				return true # Found water!
				
	return false # No water found
	

func calculate_pest_intents():
	highlight_layer.clear()
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for pest in active_pests:
		if not pest["alive"]:
			continue
		var current = pest["current_pos"]
		var best_move = current

		
		var target_crop = current 
		var min_crop_dist = 99999
		for crop_data in active_crops:
			var crop_pos = crop_data["pos"]
			var d = abs(crop_pos.x - current.x) + abs(crop_pos.y - current.y)
			if d < min_crop_dist:
				min_crop_dist = d
				target_crop = crop_pos
		var shortest_dist = min_crop_dist
		for dir in directions:
			var neighbor = current + dir
			if _is_within_bounds(neighbor.x, neighbor.y):
				if grid_data[neighbor.x][neighbor.y] == TileState.DIRT:
					var dist_to_crop = abs(target_crop.x - neighbor.x) + abs(target_crop.y - neighbor.y)
					
					if dist_to_crop < shortest_dist:
						shortest_dist = dist_to_crop
						best_move = neighbor
		pest["next_pos"] = best_move
		if best_move != current:
			highlight_layer.set_cell(best_move, 0, Vector2i(0, 0))
	


func _on_timer_timeout() -> void:
	highlight_layer.visible = !highlight_layer.visible
	crop_anim_frame = (crop_anim_frame + 1) % 6
	for crop in active_crops:
		# Calculate the exact X coordinate on your partner's long sprite strip
		# Stage 0 = frames 0-5. Stage 1 = frames 6-11, etc.
		var exact_x_coordinate = (crop["stage"] * 6) + crop_anim_frame
		
		# Draw that specific slice onto the TileMap!
		objects_layer.set_cell(crop["pos"], ID_CROP, Vector2i(exact_x_coordinate, 0))

func execute_enemy_turn():
	print("--- ENEMY TURN EXECUTING ---")
	turns_taken += 1
	update_hud()
	for pest in active_pests:
		if not pest["alive"]:
			continue
		var current = pest["current_pos"]
		var next = pest["next_pos"]
		if current != next:
			grid_data[current.x][current.y] = TileState.DIRT
			objects_layer.set_cell(current, -1)
			grid_data[next.x][next.y] = TileState.PEST
			objects_layer.set_cell(next, ID_PEST, Vector2i(0, 0))
			pest["current_pos"] = next
	for crop in active_crops:
		if crop["is_watered"] and crop["is_lit"]:
			# Max stage is 3 (Stages 0, 1, 2, 3)
			if crop["stage"] < 3: 
				crop["stage"] += 1
				sfx_plantgrowth.play()
				print("Crop at ", crop["pos"], " grew to stage ", crop["stage"])
	attack_crops() 
	calculate_pest_intents()
	calculate_light_beam()
	check_game_state()
	if is_game_over:
		end_turn_button.visible = false

func _is_trench_connection(x: int, y: int) -> bool:
	if not _is_within_bounds(x, y): return false
	var cell = grid_data[x][y]
	# Connect to dry trenches, wet trenches, and the Pump!
	return cell == TileState.TRENCH or cell == TileState.WATERED_TRENCH or cell == TileState.PUMP

func get_trench_bitmask(x: int, y: int) -> int:
	var mask = 0
	if _is_trench_connection(x, y - 1): mask += 1 # Up
	if _is_trench_connection(x + 1, y): mask += 2 # Right
	if _is_trench_connection(x, y + 1): mask += 4 # Down
	if _is_trench_connection(x - 1, y): mask += 8 # Left
	return mask

func update_trench_visuals():
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var state = grid_data[x][y]
			
			if state == TileState.TRENCH or state == TileState.WATERED_TRENCH:
				var mask = get_trench_bitmask(x, y)
				
				# If Dry, use the Dry Dictionary IDs
				if state == TileState.TRENCH:
					var correct_png_id = trench_graphics_map[mask]
					tilemap.set_cell(Vector2i(x, y), correct_png_id, Vector2i(0, 0))
					
				# If Wet, use the Pink Water Dictionary IDs
				elif state == TileState.WATERED_TRENCH:
					tilemap.modulate = Color(0.1, 2.0, 2.0, 1.0) # Bright neon cyan
					var correct_png_id = watered_trench_graphics_map[mask]
					tilemap.set_cell(Vector2i(x, y), correct_png_id, Vector2i(0, 0))

func attack_crops():
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for pest in active_pests:
		if not pest["alive"]:
			continue
			
		var p_pos = pest["current_pos"]
		
		# Check all 4 sides of the bug
		for dir in directions:
			var neighbor = p_pos + dir
			if _is_within_bounds(neighbor.x, neighbor.y):
				
				# Did we find a crop?
				if grid_data[neighbor.x][neighbor.y] == TileState.CROP:
					print("CHOMP! Pest at ", p_pos, " ate the crop at ", neighbor, "!")
					sfx_chomp.play()
					
					# 1. Turn the crop back into dirt logically
					grid_data[neighbor.x][neighbor.y] = TileState.DIRT
					
					# 2. Paint over the crop visual with normal dirt (ID_DIRT1)
					objects_layer.set_cell(neighbor, -1)
					
					# 3. Remove the crop from our tracking list so bugs stop chasing it
					active_crops = active_crops.filter(func(c): return c["pos"] != neighbor)
					
					# We only eat one crop per turn, so break the inner loop
					break
func update_scarecrow_visuals():
	for base_pos in active_scarecrows:
		var state = grid_data[base_pos.x][base_pos.y]
		var head_pos = base_pos + Vector2i(0, -1) # One tile UP!
		tilemap.set_cell(base_pos, ID_DIRT1, Vector2i(0, 0))
		if _is_within_bounds(head_pos.x, head_pos.y):
			var head_state = grid_data[head_pos.x][head_pos.y]
			if head_state != TileState.TRENCH and head_state != TileState.WATERED_TRENCH:
				tilemap.set_cell(head_pos, ID_DIRT1, Vector2i(0, 0))
		if scarecrow_head_map.has(state):
			var correct_head_id = scarecrow_head_map[state]
			
			# 1. Paint the correct Head one spot up
			objects_layer.set_cell(head_pos, correct_head_id, Vector2i(0, 0))
			
			# 2. Paint the Animated Skirt on the base spot
			objects_layer.set_cell(base_pos, ID_SCARECROW_SKIRT, Vector2i(0, 0))
func check_game_state():
	# 1. THE LOSE CONDITION
	# If the bugs ate everything and the list is empty...
	if active_crops.size() == 0:
		print("GAME OVER! The pests ate all your crops!")
		is_game_over = true
		losing_sound.play()
		loss_screen.visible = true
		# We can add a "Restart Level" popup here later!
		return
		
	# 2. THE WIN CONDITION
	var all_crops_grown = true
	
	for crop in active_crops:
		if crop["stage"] < 3:
			all_crops_grown = false
			break # Found a small crop, no need to keep checking!
			
	if all_crops_grown:
		is_game_over = true
		win_screen.visible = true
		win_anim.play("WinScreen")
		winning_sound.play()
		print("LEVEL COMPLETE! All crops are fully grown!")
	if turns_taken >= max_turns:
		print("GAME OVER! You ran out of turns!")
		is_game_over = true
		losing_sound.play()
		loss_screen.visible = true


func _on_quit_button_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().quit()


func _on_restart_button_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	get_tree().reload_current_scene()


func _on_next_level_button_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	if next_level_scene != null:
		print("Loading next level...")
		get_tree().change_scene_to_packed(next_level_scene)
	else:
		print("YOU BEAT THE GAME! (Or you forgot to slot the next level in the Inspector!)")
func update_hud():
	var trenches_left = max_trenches - trenches_used
	var turns_left = max_turns - turns_taken
	
	trench_label.text = "Trenches: " + str(trenches_left)
	turn_label.text = "Turns Left: " + str(turns_left)

func _on_end_turn_button_pressed() -> void:
	button_click.play()
	await get_tree().create_timer(1).timeout
	execute_enemy_turn()
