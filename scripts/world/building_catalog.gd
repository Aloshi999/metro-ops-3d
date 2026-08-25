class_name BuildingCatalog
extends RefCounted
## Loads Kenney City Kit GLBs (real meshes) and returns scaled instances.
## Occupancy tiers swap house → midrise → skyscraper / factory.

const GameConstants = preload("res://scripts/core/game_constants.gd")
const TileTypes = preload("res://scripts/core/tile_types.gd")

const SUB := "res://assets/city/kenney_suburban/"
const COM := "res://assets/city/kenney_commercial/"
const IND := "res://assets/city/kenney_industrial/"
const ROAD := "res://assets/city/kenney_roads/"

var _scenes: Dictionary = {}  # path -> PackedScene
var loaded_count: int = 0
var failed: PackedStringArray = []

const RES_LOW: Array[String] = [
	SUB + "building-type-a.glb",
	SUB + "building-type-c.glb",
	SUB + "building-type-g.glb",
	SUB + "building-type-h.glb",
	SUB + "building-type-j.glb",
]
const RES_MID: Array[String] = [
	SUB + "building-type-b.glb",
	SUB + "building-type-d.glb",
	SUB + "building-type-e.glb",
	SUB + "building-type-f.glb",
	SUB + "building-type-i.glb",
	SUB + "building-type-k.glb",
	SUB + "building-type-l.glb",
]
const RES_HIGH: Array[String] = [
	SUB + "building-type-m.glb",
	SUB + "building-type-n.glb",
	SUB + "building-type-o.glb",
	SUB + "building-type-p.glb",
	SUB + "building-type-q.glb",
	SUB + "building-type-r.glb",
	SUB + "building-type-s.glb",
	SUB + "building-type-t.glb",
	SUB + "building-type-u.glb",
	COM + "low-detail-building-a.glb",
	COM + "low-detail-building-wide-a.glb",
]

const COM_LOW: Array[String] = [
	COM + "building-a.glb",
	COM + "building-b.glb",
	COM + "low-detail-building-c.glb",
	COM + "low-detail-building-d.glb",
]
const COM_MID: Array[String] = [
	COM + "building-c.glb",
	COM + "building-d.glb",
	COM + "building-e.glb",
	COM + "building-f.glb",
	COM + "building-g.glb",
	COM + "building-h.glb",
	COM + "building-i.glb",
	COM + "building-j.glb",
]
const COM_HIGH: Array[String] = [
	COM + "building-k.glb",
	COM + "building-l.glb",
	COM + "building-m.glb",
	COM + "building-n.glb",
	COM + "building-skyscraper-a.glb",
	COM + "building-skyscraper-b.glb",
	COM + "building-skyscraper-c.glb",
	COM + "building-skyscraper-d.glb",
	COM + "building-skyscraper-e.glb",
]

const IND_LOW: Array[String] = [
	IND + "building-a.glb",
	IND + "building-b.glb",
	IND + "building-c.glb",
	IND + "detail-tank.glb",
]
const IND_MID: Array[String] = [
	IND + "building-d.glb",
	IND + "building-e.glb",
	IND + "building-f.glb",
	IND + "building-g.glb",
	IND + "building-h.glb",
	IND + "building-i.glb",
]
const IND_HIGH: Array[String] = [
	IND + "building-j.glb",
	IND + "building-k.glb",
	IND + "building-l.glb",
	IND + "building-m.glb",
	IND + "building-n.glb",
	IND + "building-o.glb",
	IND + "building-p.glb",
	IND + "building-q.glb",
	IND + "building-r.glb",
	IND + "building-s.glb",
	IND + "building-t.glb",
]

const HQ_PATH: String = COM + "building-skyscraper-d.glb"
const POWER_PATH: String = IND + "building-s.glb"
const POWER_CHIMNEY: String = IND + "chimney-large.glb"
const WATER_PATH: String = IND + "detail-tank.glb"
const TREE_LARGE: String = SUB + "tree-large.glb"
const TREE_SMALL: String = SUB + "tree-small.glb"

const ROAD_STRAIGHT: String = ROAD + "road-straight.glb"
const ROAD_CROSS: String = ROAD + "road-crossroad.glb"
const ROAD_T: String = ROAD + "road-intersection.glb"
const ROAD_BEND: String = ROAD + "road-bend.glb"
const ROAD_END: String = ROAD + "road-end.glb"
const ROAD_SQUARE: String = ROAD + "road-square.glb"
const LAMP: String = ROAD + "light-curved.glb"


func load_all() -> void:
	var paths: Array[String] = []
	for arr in [RES_LOW, RES_MID, RES_HIGH, COM_LOW, COM_MID, COM_HIGH, IND_LOW, IND_MID, IND_HIGH]:
		for p in arr:
			if p not in paths:
				paths.append(p)
	for p in [HQ_PATH, POWER_PATH, POWER_CHIMNEY, WATER_PATH, TREE_LARGE, TREE_SMALL,
			ROAD_STRAIGHT, ROAD_CROSS, ROAD_T, ROAD_BEND, ROAD_END, ROAD_SQUARE, LAMP]:
		if p not in paths:
			paths.append(p)
	for p in paths:
		_load(p)


func _load(path: String) -> void:
	if _scenes.has(path):
		return
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		failed.append(path)
		return
	var res = ResourceLoader.load(path)
	if res is PackedScene:
		_scenes[path] = res
		loaded_count += 1
	else:
		failed.append(path)


func has_meshes() -> bool:
	return loaded_count >= 8


func instantiate_path(path: String, scale: float = GameConstants.BUILDING_SCALE) -> Node3D:
	var packed: PackedScene = _scenes.get(path, null)
	if packed == null:
		_load(path)
		packed = _scenes.get(path, null)
	if packed == null:
		return null
	var n: Node = packed.instantiate()
	var wrap := Node3D.new()
	wrap.name = path.get_file().get_basename()
	if n is Node3D:
		(n as Node3D).scale = Vector3.ONE
		wrap.add_child(n)
	else:
		wrap.add_child(n)
	wrap.scale = Vector3(scale, scale, scale)
	return wrap


func pick_zone_building(z: int, occupancy: float, lot_index: int) -> Node3D:
	var tier: Array[String]
	if occupancy < 0.18:
		return null
	elif occupancy < 0.45:
		tier = _low(z)
	elif occupancy < 0.75:
		tier = _mid(z)
	else:
		tier = _high(z)
	if tier.is_empty():
		return null
	var path: String = tier[lot_index % tier.size()]
	var n := instantiate_path(path, GameConstants.BUILDING_SCALE)
	if n:
		n.rotate_y(float((lot_index * 17) % 4) * PI * 0.5)
	return n


func instantiate_hq() -> Node3D:
	return instantiate_path(HQ_PATH, GameConstants.BUILDING_SCALE * 1.15)


func instantiate_power() -> Node3D:
	var root := instantiate_path(POWER_PATH, GameConstants.BUILDING_SCALE)
	if root == null:
		return null
	var chim := instantiate_path(POWER_CHIMNEY, GameConstants.BUILDING_SCALE * 0.55)
	if chim:
		chim.position = Vector3(3.5, 0.0, 3.5)
		root.add_child(chim)
	return root


func instantiate_water() -> Node3D:
	var n := instantiate_path(WATER_PATH, GameConstants.BUILDING_SCALE * 1.35)
	if n:
		n.scale.y *= 1.6
	return n


func instantiate_road(mask: int) -> Node3D:
	## mask: bit0 N, bit1 E, bit2 S, bit3 W. Returns yaw in radians via meta.
	var bits := 0
	if mask & 1:
		bits += 1
	if mask & 2:
		bits += 1
	if mask & 4:
		bits += 1
	if mask & 8:
		bits += 1
	var path := ROAD_SQUARE
	var yaw := 0.0
	match bits:
		0:
			path = ROAD_SQUARE
		1:
			path = ROAD_END
			if mask & 1:
				yaw = 0.0
			elif mask & 2:
				yaw = -PI * 0.5
			elif mask & 4:
				yaw = PI
			else:
				yaw = PI * 0.5
		2:
			if (mask & 5) == 5:
				path = ROAD_STRAIGHT
				yaw = 0.0
			elif (mask & 10) == 10:
				path = ROAD_STRAIGHT
				yaw = PI * 0.5
			else:
				path = ROAD_BEND
				if mask == (1 | 2):
					yaw = 0.0
				elif mask == (2 | 4):
					yaw = -PI * 0.5
				elif mask == (4 | 8):
					yaw = PI
				else:
					yaw = PI * 0.5
		3:
			path = ROAD_T
			if (mask & 1) == 0:
				yaw = PI
			elif (mask & 2) == 0:
				yaw = PI * 0.5
			elif (mask & 4) == 0:
				yaw = 0.0
			else:
				yaw = -PI * 0.5
		_:
			path = ROAD_CROSS
	var n := instantiate_path(path, GameConstants.ROAD_SCALE)
	if n:
		n.rotate_y(yaw)
	return n


func instantiate_tree(large: bool) -> Node3D:
	return instantiate_path(TREE_LARGE if large else TREE_SMALL, GameConstants.PROP_SCALE)


func instantiate_lamp() -> Node3D:
	return instantiate_path(LAMP, GameConstants.PROP_SCALE)


func _low(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_LOW
		TileTypes.Zone.COMMERCIAL:
			return COM_LOW
		_:
			return IND_LOW


func _mid(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_MID
		TileTypes.Zone.COMMERCIAL:
			return COM_MID
		_:
			return IND_MID


func _high(z: int) -> Array[String]:
	match z:
		TileTypes.Zone.RESIDENTIAL:
			return RES_HIGH
		TileTypes.Zone.COMMERCIAL:
			return COM_HIGH
		_:
			return IND_HIGH
