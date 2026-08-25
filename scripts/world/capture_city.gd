extends SceneTree
## Capture world.tscn → /workspace/city_looks_3d.png
## Run: godot --path /workspace/metro-ops-3d --script res://scripts/world/capture_city.gd

func _initialize() -> void:
	print("[capture_city] initialize")
	OS.set_environment("CITY_MESH_CAPTURE", "1")
	var packed: PackedScene = load("res://scenes/world.tscn")
	if packed == null:
		push_error("[capture_city] failed to load res://scenes/world.tscn")
		quit(1)
		return
	var world: Node = packed.instantiate()
	root.add_child(world)
	print("[capture_city] world instanced")


func _process(_dt: float) -> bool:
	# WorldRoot quits after capture when CITY_MESH_CAPTURE=1.
	return false
