extends Node2D

const GRID_WIDTH = 12
const GRID_HEIGHT = 10

const ID_DIRT1 = 2
const ID_DIRT2 = 3
const ID_CROP = 7
const ID_MIRROR_SLASH = 5
const ID_MIRROR_BACKSLASH = 6
const ID_PUMP = 8
const ID_PEST = 9

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
	0: 14,  # No connections (Standalone dot)
	1: 14,  # Only Up (End piece)
	2: 14,  # Only Right (End piece)
	3: 10,  # Up + Right (Bottom-Left Corner) -> Your "B-L_cor"
	4: 14,  # Only Down (End piece)
	5: 9,  # Up + Down (Vertical Straight)
	6: 11,  # Right + Down (Top-Left Corner) -> Your "T-L_cor"
	7: 15,  # Up + Right + Down (T-Junction)
	8: 14,  # Only Left (End piece)
	9: 12,  # Up + Left (Bottom-Right Corner) -> Your "B-R_cor"
	10: 9, # Right + Left (Horizontal Straight)
	11: 15, # Up + Right + Left (T-Junction)
	12: 13, # Down + Left (Top-Right Corner) -> Your "T-R_cor"
	13: 15, # Up + Down + Left (T-Junction)
	14: 15, # Right + Down + Left (T-Junction)
	15: 15  # All 4 directions (Crossroads)
}
var watered_trench_graphics_map = {
	0: 1,  # No connections (Standalone dot)
	1: 4,  # Only Up (End piece)
	2: 17,  # Only Right (End piece)
	3: 20,  # Up + Right (Bottom-Left Corner)
	4: 18,  # Only Down (End piece)
	5: 0,  # Up + Down (Vertical Straight)
	6: 22,  # Right + Down (Top-Left Corner)
	7: 99,  # Up + Right + Down (T-Junction)
	8: 99,  # Only Left (End piece)
	9: 99,  # Up + Left (Bottom-Right Corner)
	10: 99, # Right + Left (Horizontal Straight)
	11: 99, # Up + Right + Left (T-Junction)
	12: 99, # Down + Left (Top-Right Corner)
	13: 99, # Up + Down + Left (T-Junction)
	14: 99, # Right + Down + Left (T-Junction)
	15: 99  # All 4 directions (Crossroads)
}

# Our 2D matrix
var grid_data = []

@onready var tilemap = $TileMapLayer
@onready var light_layer = $LightLayer

var light_start = Vector2i(0, 5)     # Starts at the left edge, middle row
var light_direction = Vector2i(1, 0) # Moving right (x: 1, y: 0)

var pump_pos = Vector2i(2, 0)

@onready var highlight_layer = $HighlightLayer

var active_pests = []
var active_crops = []


func _ready():
	print("Building the farm...") # <--- ADD THIS LINE
	_initialize_grid()
	calculate_water_flow()
	calculate_light_beam()
	calculate_pest_intents()
	update_trench_visuals()

#func _initialize_grid():
	## Create a 2D array filled with DIRT (0)
	#for x in range(GRID_WIDTH):
		#var column = []
		#for y in range(GRID_HEIGHT):
			#column.append(TileState.DIRT)
			## Optional: Fill the visual tilemap with dirt tiles immediately
			#tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0)) 
		#grid_data.append(column)
	#grid_data[pump_pos.x][pump_pos.y] = TileState.PUMP
	## Optional: Draw a temporary visual for the pump (assuming it's at atlas 2,0)
	#tilemap.set_cell(pump_pos, 0, Vector2i(2, 0))
	#
	#var crop_pos = Vector2i(6, 2)
	#grid_data[crop_pos.x][crop_pos.y] = TileState.CROP
	#tilemap.set_cell(crop_pos, 0, Vector2i(2, 0))
	#active_crops.append(crop_pos)
	#
	#var m1 = Vector2i(3, 5)
	#grid_data[m1.x][m1.y] = TileState.MIRROR_SLASH
	#tilemap.set_cell(m1, 0, Vector2i(2, 0)) # Drawing your blue square
#
	## Mirror 2 (Takes the UP beam and bounces it RIGHT)
	#var m2 = Vector2i(3, 2)
	#grid_data[m2.x][m2.y] = TileState.MIRROR_SLASH
	#tilemap.set_cell(m2, 0, Vector2i(2, 0))
#
	## Mirror 3 (Takes the RIGHT beam and bounces it DOWN)
	#var m3 = Vector2i(8, 2)
	#grid_data[m3.x][m3.y] = TileState.MIRROR_BACKSLASH
	#tilemap.set_cell(m3, 0, Vector2i(2, 0))
#
	## Mirror 4 (Takes the DOWN beam and bounces it LEFT, hitting the Crop!)
	#var m4 = Vector2i(8, 5)
	#grid_data[m4.x][m4.y] = TileState.MIRROR_SLASH
	#tilemap.set_cell(m4, 0, Vector2i(2, 0))
	#
	#var pest_pos = Vector2i(6, 8)
	#grid_data[pest_pos.x][pest_pos.y] = TileState.PEST
	#tilemap.set_cell(pest_pos, 0, Vector2i(0, 0))
	#active_pests.append({
		#"current_pos": pest_pos,
		#"next_pos": pest_pos, # Default to staying still
		#"alive": true
	#})
func _initialize_grid():
	# 1. Clear out any old data (great for when you add a "Restart Level" button later!)
	grid_data.clear()
	active_pests.clear()
	active_crops.clear()
	
	# 2. Sweep the entire board from top-left to bottom-right
	for x in range(GRID_WIDTH):
		var column = []
		for y in range(GRID_HEIGHT):
			var cell_pos = Vector2i(x, y)
			var source_id = tilemap.get_cell_source_id(cell_pos)
			
			# Default logical state is Dirt
			var state = TileState.DIRT
			
			# Check the Source ID to figure out what object this is
			if source_id == ID_CROP:
				state = TileState.CROP
				active_crops.append(cell_pos)
				
			elif source_id == ID_MIRROR_SLASH:
				state = TileState.MIRROR_SLASH
				
			elif source_id == ID_MIRROR_BACKSLASH:
				state = TileState.MIRROR_BACKSLASH
				
			elif source_id == ID_PEST:
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
		grid_data[x][y] = TileState.TRENCH
		
		print("Dug a trench at: ", x, ", ", y)
		
		calculate_water_flow()
		calculate_light_beam()
	
	
	elif grid_data[x][y] == TileState.MIRROR_SLASH:
		grid_data[x][y] = TileState.MIRROR_BACKSLASH
		print("Rotated mirror to \\")
		calculate_light_beam() # Recalculate the laser!
	elif grid_data[x][y] == TileState.MIRROR_BACKSLASH:
		grid_data[x][y] = TileState.MIRROR_SLASH
		print("Rotated mirror to /")
		calculate_light_beam()
	
	
func calculate_water_flow():
	# 1. THE RESET: Dry up all existing water first
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid_data[x][y] == TileState.WATERED_TRENCH:
				grid_data[x][y] = TileState.TRENCH
				

	# 2. THE SETUP: Create a queue for our BFS, starting at the pump
	var queue = []
	queue.append(pump_pos)
	
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
					grid_data[neighbor_x][neighbor_y] = TileState.WATERED_TRENCH
					
				
					
					# Add this newly wet trench to the queue so water can spread FROM it
					queue.append(Vector2i(neighbor_x, neighbor_y))
	update_crops()
	update_trench_visuals()

func fill_trench(x: int, y: int):
	# Make sure we are only filling in trenches, not the pump or existing dirt
	if grid_data[x][y] == TileState.TRENCH or grid_data[x][y] == TileState.WATERED_TRENCH:
		# 1. Update the logic array back to DIRT
		grid_data[x][y] = TileState.DIRT
		
		# 2. Update the visual back to the Red Square (Atlas 0,0). 
		# Note: Make sure the Source ID here (the middle number) matches the '1' you used to fix the invisible tiles!
		
		print("Filled trench at: ", x, ", ", y)
		
		# 3. Recalculate! This will instantly dry up any yellow trenches that are no longer connected to the pump.
		calculate_water_flow()
		calculate_light_beam()
		update_trench_visuals()

func update_crops():
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), 
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	# Sweep the entire board looking for crops
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid_data[x][y] == TileState.CROP:
				var is_watered = false
				
				# Check the 4 tiles immediately around the crop
				for dir in directions:
					var neighbor_x = x + dir.x
					var neighbor_y = y + dir.y
					
					# Make sure we don't check off the edge of the screen
					if _is_within_bounds(neighbor_x, neighbor_y):
						if grid_data[neighbor_x][neighbor_y] == TileState.WATERED_TRENCH:
							is_watered = true
							break # We found water! Stop checking the other sides.
				
				# Report the status to the Output window
				if is_watered:
					print("Crop at ", x, ",", y, " is WATERED ")
					# Later: tilemap.set_cell(..., Stage 4 Plant Sprite)
				else:
					print("Crop at ", x, ",", y, " is DRY ")
					# Later: tilemap.set_cell(..., Stage 1 Dirt Sprite)
func calculate_light_beam():
	# 1. THE RESET: Clear all old light from the glass layer
	light_layer.clear()
	
	# 2. THE SETUP: Start at the source
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
			print("Light is shining on the Crop!")
		
		elif cell_under_light == TileState.PEST:
			print("ZAPPED A PEST at: ", current_pos, "!")
			grid_data[current_pos.x][current_pos.y] = TileState.DIRT
			tilemap.set_cell(current_pos, 1, Vector2i(0, 0))
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
		for crop in active_crops:
			var d = abs(crop.x - current.x) + abs(crop.y - current.y)
			if d < min_crop_dist:
				min_crop_dist = d
				target_crop = crop
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

func execute_enemy_turn():
	print("--- ENEMY TURN EXECUTING ---")
	for pest in active_pests:
		if not pest["alive"]:
			continue
		var current = pest["current_pos"]
		var next = pest["next_pos"]
		if current != next:
			grid_data[current.x][current.y] = TileState.DIRT
			tilemap.set_cell(current, 1, Vector2i(0, 0))
			grid_data[next.x][next.y] = TileState.PEST
			tilemap.set_cell(next, 0, Vector2i(0, 0))
			pest["current_pos"] = next
	calculate_pest_intents()
	calculate_light_beam()

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
				var correct_png_id = trench_graphics_map[mask]
				
				# If it's a dry trench, draw the normal sprite (Alternative ID 0)
				if state == TileState.TRENCH:
					tilemap.set_cell(Vector2i(x, y), correct_png_id, Vector2i(0, 0), 0)
				# If it's watered, draw the Blue tinted sprite (Alternative ID 1)
				elif state == TileState.WATERED_TRENCH:
					tilemap.set_cell(Vector2i(x, y), correct_png_id, Vector2i(0, 0), 1)
