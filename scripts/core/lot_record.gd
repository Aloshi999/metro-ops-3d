class_name LotRecord
extends RefCounted
## Deterministic renter card for one occupied residential lot. No 128×128 table.

const NAMES: PackedStringArray = [
	"Amina", "Rafi", "Soren", "Leila", "Kostya", "Noor", "Pavel", "Yara",
	"Jonas", "Mira", "Tariq", "Elena", "Oksana", "Samir", "Ingrid", "Hassan",
	"Nadja", "Viktor", "Hana", "Malik"
]
const JOB_CLASSES: PackedStringArray = ["labor", "merchant", "industrial", "civic"]
const FACTIONS: PackedStringArray = ["dockside", "uptown", "foundry", "civic"]
const TAG_POOL: PackedStringArray = ["jobs", "services", "quiet", "trade", "safety", "rent"]


var lot: Vector2i = Vector2i.ZERO
var name: String = ""
var job_class: String = "labor"
var faction: String = "civic"
var tags: PackedStringArray = PackedStringArray()


static func from_lot(x: int, y: int) -> LotRecord:
	var rec := LotRecord.new()
	rec.lot = Vector2i(x, y)
	var h: int = _hash(x, y)
	rec.name = NAMES[h % NAMES.size()]
	rec.job_class = JOB_CLASSES[(h >> 3) % JOB_CLASSES.size()]
	rec.faction = FACTIONS[(h >> 5) % FACTIONS.size()]
	var ntags: int = 2 + (h % 2)
	var start: int = (h >> 2) % TAG_POOL.size()
	rec.tags = PackedStringArray()
	for i in ntags:
		rec.tags.append(TAG_POOL[(start + i * 2) % TAG_POOL.size()])
	return rec


static func _hash(x: int, y: int) -> int:
	## Cheap deterministic mix; stays non-negative.
	var v: int = x * 73856093
	v = v ^ (y * 19349663)
	v = v ^ ((x + 13) * (y + 17))
	if v < 0:
		v = -v
	return v
