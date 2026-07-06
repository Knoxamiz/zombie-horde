class_name MapBlueprint
extends Resource

const STATUS_LAB_ONLY := "lab_only"
const STATUS_PROTOTYPE := "prototype"
const STATUS_VALIDATED := "validated"
const STATUS_PLAYABLE := "playable"
const STATUS_DISABLED := "disabled"

const CELL_VOID := "VOID"
const CELL_SAFE_ROAD := "SAFE_ROAD"
const CELL_ROAD := "ROAD"
const CELL_CRACK_ROAD := "CRACK_ROAD"
const CELL_BROKEN_EDGE := "BROKEN_EDGE"
const CELL_GAP_VISUAL := "GAP_VISUAL"
const CELL_LEFT_RAIL := "LEFT_RAIL"
const CELL_RIGHT_RAIL := "RIGHT_RAIL"
const CELL_CONE := "CONE"
const CELL_BARRIER := "BARRIER"
const CELL_DEBRIS := "DEBRIS"
const CELL_LIGHT := "LIGHT"
const CELL_CONTAINER := "CONTAINER"
const CELL_HAZARD := "HAZARD"
const CELL_SPAWN := "SPAWN"
const CELL_GOAL := "GOAL"

@export var id: String = ""
@export var display_name: String = ""
@export var authoring_status: String = STATUS_LAB_ONLY
@export var enabled_for_selection: bool = false
@export var tile_size: float = 8.0
@export var visual_width_tiles: int = 3
@export var visual_length_tiles: int = 8
@export var safe_path_width_meters: float = 10.0
@export var gameplay_lane_half_width: float = 6.1
@export var spawn_z: float = -28.0
@export var goal_z: float = 28.0
@export var theme: String = "bridge"
@export var seed: int = 1
@export var rows: Array[Dictionary] = []
@export var gameplay_plates: Array[Dictionary] = []
@export var hazard_zones: Array[Dictionary] = []
@export var dressing_rules: Dictionary = {}
@export var validation_requirements: Dictionary = {}


func get_row_count() -> int:
	return rows.size()


func get_row(index: int) -> Dictionary:
	if index < 0 or index >= rows.size():
		return {}
	return rows[index]


func get_cells_for_row(row_index: int) -> Array:
	var row: Dictionary = get_row(row_index)
	return row.get("cells", [])


func get_cell(row_index: int, column_index: int) -> Dictionary:
	var cells: Array = get_cells_for_row(row_index)
	if column_index < 0 or column_index >= cells.size():
		return {}
	var cell = cells[column_index]
	if cell is Dictionary:
		return cell
	return {"type": str(cell)}


func get_cell_type(row_index: int, column_index: int) -> String:
	return str(get_cell(row_index, column_index).get("type", CELL_VOID))


func is_safe_path_cell(row_index: int, column_index: int) -> bool:
	var cell: Dictionary = get_cell(row_index, column_index)
	if bool(cell.get("safe_path", false)):
		return true
	var cell_type: String = str(cell.get("type", CELL_VOID))
	return cell_type == CELL_SAFE_ROAD or cell_type == CELL_SPAWN or cell_type == CELL_GOAL


func get_center_column_index() -> int:
	return int(floor(float(visual_width_tiles - 1) * 0.5))


func column_to_x(column_index: int) -> float:
	var center_col: float = float(get_center_column_index())
	return (float(column_index) - center_col) * tile_size


func row_to_z(row_index: int) -> float:
	var first_row_z: float = spawn_z + tile_size * 0.5
	return first_row_z + float(row_index) * tile_size
