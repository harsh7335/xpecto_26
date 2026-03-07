extends Node2D

const GRID_WIDTH = 12
const GRID_HEIGHT = 10

# Dictionary for readability
enum TileState {
	DIRT = 0,
	CROP = 1,
	MIRROR = 2,
	TRENCH = 3,
	OBSTACLE = 4,
	PUMP = 5,           # The water source
	WATERED_TRENCH = 6  # A trench currently filled with water
}

# Our 2D matrix
var grid_data = []

@onready var tilemap = $TileMapLayer
var pump_pos = Vector2i(2, 0)
func _ready():
	print("Building the farm...") # <--- ADD THIS LINE
	_initialize_grid()

func _initialize_grid():
	# Create a 2D array filled with DIRT (0)
	for x in range(GRID_WIDTH):
		var column = []
		for y in range(GRID_HEIGHT):
			column.append(TileState.DIRT)
			# Optional: Fill the visual tilemap with dirt tiles immediately
			tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0)) 
		grid_data.append(column)
	grid_data[pump_pos.x][pump_pos.y] = TileState.PUMP
	# Optional: Draw a temporary visual for the pump (assuming it's at atlas 2,0)
	tilemap.set_cell(pump_pos, 1, Vector2i(2, 0))

func _unhandled_input(event):
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
		
		# Update the visual TileMapLayer 
		# (Vector2i(x,y) is location, 0 is source_id, Vector2i(1,0) is the trench atlas coordinate)
		tilemap.set_cell(Vector2i(x, y), 1, Vector2i(1, 0))
		print("Dug a trench at: ", x, ", ", y)
		
		calculate_water_flow()
func calculate_water_flow():
	# 1. THE RESET: Dry up all existing water first
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid_data[x][y] == TileState.WATERED_TRENCH:
				grid_data[x][y] = TileState.TRENCH
				# Draw the dry trench texture (assuming atlas 1,0)
				tilemap.set_cell(Vector2i(x, y), 1, Vector2i(1, 0))

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
					
					# Update the visual (assuming wet trench is at atlas 3,0)
					tilemap.set_cell(Vector2i(neighbor_x, neighbor_y), 1, Vector2i(3, 0))
					
					# Add this newly wet trench to the queue so water can spread FROM it
					queue.append(Vector2i(neighbor_x, neighbor_y))

func fill_trench(x: int, y: int):
	# Make sure we are only filling in trenches, not the pump or existing dirt
	if grid_data[x][y] == TileState.TRENCH or grid_data[x][y] == TileState.WATERED_TRENCH:
		# 1. Update the logic array back to DIRT
		grid_data[x][y] = TileState.DIRT
		
		# 2. Update the visual back to the Red Square (Atlas 0,0). 
		# Note: Make sure the Source ID here (the middle number) matches the '1' you used to fix the invisible tiles!
		tilemap.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
		print("Filled trench at: ", x, ", ", y)
		
		# 3. Recalculate! This will instantly dry up any yellow trenches that are no longer connected to the pump.
		calculate_water_flow()
