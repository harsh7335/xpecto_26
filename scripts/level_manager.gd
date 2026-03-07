extends Node2D

const GRID_WIDTH = 12
const GRID_HEIGHT = 10

# Dictionary for readability
enum TileState {
	DIRT = 0,
	CROP = 1,
	MIRROR = 2,
	TRENCH = 3,
	OBSTACLE = 4
}

# Our 2D matrix
var grid_data = []

@onready var tilemap = $TileMapLayer

func _ready():
	_initialize_grid()

func _initialize_grid():
	# Create a 2D array filled with DIRT (0)
	for x in range(GRID_WIDTH):
		var column = []
		for y in range(GRID_HEIGHT):
			column.append(TileState.DIRT)
			# Optional: Fill the visual tilemap with dirt tiles immediately
			tilemap.set_cell(Vector2i(x, y), 0, Vector2i(0, 0)) 
		grid_data.append(column)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = tilemap.local_to_map(mouse_pos)
		if _is_within_bounds(grid_pos.x, grid_pos.y):
			interact_with_cell(grid_pos.x, grid_pos.y)

func _is_within_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

func interact_with_cell(x: int, y: int):
	# If the cell is dirt, dig a trench!
	if grid_data[x][y] == TileState.DIRT:
		grid_data[x][y] = TileState.TRENCH
		
		# Update the visual TileMapLayer 
		# (Vector2i(x,y) is location, 0 is source_id, Vector2i(1,0) is the trench atlas coordinate)
		tilemap.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
		print("Dug a trench at: ", x, ", ", y)
		
		# Later, we will call our water BFS function right here!
