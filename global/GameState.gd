extends Node
signal stats_changed(stats: Dictionary)

var stats := {
	"max_health": 100,
	"current_health": 100,
	"dash_cooldown": 0.6,

	# NEW: damage terpisah
	"damage_melee": 10,
	"damage_projectile": 7,
	"damage_parry": 8,
}

func damage_for(kind: String) -> int:
	match kind:
		"melee": return int(stats.get("damage_melee", 10))
		"projectile": return int(stats.get("damage_projectile", stats.get("damage_melee", 10)))
		"parry": return int(stats.get("damage_parry", stats.get("damage_melee", 10)))
		_: return int(stats.get("damage_melee", 10))

func set_damage(kind: String, value: int) -> void:
	var key := "damage_%s" % kind
	stats[key] = max(0, int(value))
	stats_changed.emit(stats)
	
func _ready() -> void:
	load_from_disk()
	
func set_health(value: int) -> void:
	stats.health = clampi(value, 0, stats.max_health)
	stats_changed.emit(stats)

func add_health(delta: int) -> void:
	set_health(stats.health + delta)

func add_damage(delta: int) -> void:
	stats.damage += delta
	stats_changed.emit(stats)
	
func _apply_delta(stat: String, delta: int) -> void:
	if stat == "health":
		set_health(stats.health + delta)
	else:
		stats[stat] = stats.get(stat, 0) + delta

func reset_runtime() -> void:
	stats = {
		"max_health": 100,
		"health": 100,
		"damage": 10,
		"coins": 0,
	}
	stats_changed.emit(stats)

func save_to_disk(path := "user://save.json") -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		var data := {"stats": stats}
		f.store_string(JSON.stringify(data))
		f.close()

func load_from_disk(path := "user://save.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if parsed is Dictionary and parsed.has("stats"):
		var s: Dictionary = parsed["stats"]
		s["current_health"] = clampi(int(s.get("current_health", 0)), 0, int(s.get("max_health", 100)))
		stats = s
		stats_changed.emit(stats)
