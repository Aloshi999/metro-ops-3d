class_name TileTypes
extends Object
## Zone / terrain enums + readable lot colors for 800p FSR2.

enum Terrain { DIRT = 0, GRASS = 1, WATER = 2 }
enum Zone { NONE = 0, RESIDENTIAL = 1, COMMERCIAL = 2, INDUSTRIAL = 3 }
enum Service { NONE = 0, POWER_PLANT = 1, WATER_TOWER = 2, HQ = 3 }

static func terrain_color(t: int, revealed: bool = true) -> Color:
	var c: Color
	match t:
		Terrain.DIRT:
			c = Color(0.45, 0.34, 0.20)
		Terrain.GRASS:
			c = Color(0.28, 0.52, 0.22)
		Terrain.WATER:
			c = Color(0.12, 0.38, 0.68)
		_:
			c = Color(0.18, 0.18, 0.16)
	if not revealed:
		c = c.darkened(0.55)
	return c


static func zone_color(z: int, occupancy: float = 0.0, damaged: bool = false) -> Color:
	var base: Color
	match z:
		Zone.RESIDENTIAL:
			base = Color(0.18, 0.78, 0.32, 0.55)
		Zone.COMMERCIAL:
			base = Color(0.18, 0.48, 0.95, 0.55)
		Zone.INDUSTRIAL:
			base = Color(0.92, 0.72, 0.12, 0.55)
		_:
			return Color(0, 0, 0, 0)
	if damaged:
		return Color(base.r * 0.35, base.g * 0.28, base.b * 0.28, 0.7)
	var mass := clampf(occupancy, 0.0, 1.0)
	base = base.lightened(mass * 0.12)
	base.a = 0.38 + mass * 0.28
	return base


static func zone_name(z: int) -> String:
	match z:
		Zone.RESIDENTIAL:
			return "Residential"
		Zone.COMMERCIAL:
			return "Commercial"
		Zone.INDUSTRIAL:
			return "Industrial"
		_:
			return "None"
