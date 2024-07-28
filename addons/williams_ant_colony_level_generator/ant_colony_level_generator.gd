class_name AntColonyLevelGenerator extends TileMap


@export_category("Spawning")
## Amount of ants to start each level generation with.
@export_range(0, 255, 1, "suffix:ant(s)") var count: int = 8;
## How far spread out the ants' randomized starting positions are. Larger values increase the risk of disconnected islands.
@export var spawn_spread: Vector2i = Vector2i(1, 1);
## Controls by how many increments to snap the direction the ants will march (360°/x). 0 disables snapping.
@export_category("Branching")
@export_range(0, 255) var direction_snap_divisor: int = 4;
## Chance for ants to change their direction.
@export_range(0, 100, 1, "suffix:%") var branching_chance: int = 85;
@export_category("Marching")
## Minimum amount of tiles an ant will march.
@export_range(0, 255, 1, "suffix:tile(s)") var min_marching_distance: int = 3;
## Maximum amount of tiles an ant will march.
@export_range(0, 255, 1, "suffix:tile(s)") var max_marching_distance: int = 5;
## Chance for an ant to survive after a cycle.
@export_range(0, 100, 1, "suffix:%") var survival_chance: int = 90;
## Minimum amount of cycles ants won't die.
@export_range(0, 32766, 1) var min_cycles_lifetime: int = 2;
@export_category("Limit/Failsafe")
## Maximum amount of cycles permitted before generation is paused automatically.
@export_range(1, 32767, 1) var completed_cycles_limit: int = 64;

var ants: Array[Vector2i];
var completed_cycles: int = 0;
var direction: Vector2 = Vector2.ZERO;
var tiles_to_set: Array[Vector2i];


func branch() -> void:
	var angle: float = randf_range(-PI, PI);
	if direction_snap_divisor != 0:
		angle = snappedf(angle, TAU/direction_snap_divisor);
	direction = Vector2.from_angle(angle).normalized();

func generate() -> void:
	print("Starting generation...");
	var start_time: float = Time.get_unix_time_from_system();
	reset();
	while generation_step() and (completed_cycles < completed_cycles_limit):
		completed_cycles += 1;
	if !(completed_cycles < completed_cycles_limit):
		print("Cycle limit reached");
	var end_time: float = Time.get_unix_time_from_system();
	print("Finished %s cycles in %s ms\n" % [completed_cycles, roundi((end_time-start_time)*1000.0)]);
	update_tiles();

func update_tiles(clear_cells: bool = false, clear_tile_array: bool = false) -> void:
	if clear_cells: clear();
	set_cells_terrain_connect(0, tiles_to_set, 0, 0);
	if clear_tile_array: tiles_to_set.clear();

func reset() -> void:
	randomize();
	completed_cycles = 0;
	tiles_to_set.clear();
	if direction == Vector2.ZERO: branch();
	clear();
	ants.resize(count);
	ants.fill(Vector2i.ZERO);
	if spawn_spread != Vector2i.ZERO:
		ants = Array(ants.map(func(a:Vector2i): return Vector2i(
				randi_range(-spawn_spread.x, spawn_spread.x),
				randi_range(-spawn_spread.y, spawn_spread.y))),
		TYPE_VECTOR2I, &"", null);

func generation_step(set_cells: bool = true, clear_tile_array: bool = true, clear_cells: bool = false) -> bool:
	ants = Array(
		ants.map(move_ant).filter(func(ant): return ant != -Vector2i.ONE),
		TYPE_VECTOR2I, &"", null);
	if set_cells: update_tiles(clear_cells, clear_tile_array);
	return !ants.is_empty();

func move_ant(ant: Vector2i) -> Vector2i:
	if randf() > (survival_chance/100.0) && (completed_cycles >= min_cycles_lifetime): return -Vector2i.ONE;
	if randf() < (branching_chance/100.0): branch();

	var distance: Vector2i = direction * randi_range(min_marching_distance, max_marching_distance);
	# Advance ant's position tile by tile
	for i in absi(distance.x):
		if distance.x > 0: ant.x += 1;
		else: ant.x -= 1;
		tiles_to_set.append_array(expand_tiles(ant));
	for i in absi(distance.y):
		if distance.y > 0: ant.y += 1;
		else: ant.y -= 1;
		tiles_to_set.append_array(expand_tiles(ant));

	return ant;

## Adds extra layer of cells around the ants' path for thicker paths.
func expand_tiles(ant: Vector2i) -> Array[Vector2i]:
	return [ant, ant+Vector2i(0,1), ant+Vector2i(1,0), ant+Vector2i(1,1)];


func rapid_step() -> void:
	reset();
	while generation_step() and (completed_cycles < completed_cycles_limit):
		completed_cycles += 1;
		update_tiles();
		await get_tree().process_frame;
		await get_tree().create_timer(0.08).timeout;
