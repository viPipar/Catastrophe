extends Node
signal stats_changed(stats: Dictionary)

const SAVE_PATH := "user://save.json"

const DEFAULT_STATS := {
	"max_health": 100,
	"current_health": 100,
	"dash_cooldown": 1.5,
	"blackjack_played": 0,

	# damage terpisah
	"damage_melee": 10,
	"damage_projectile": 7,
	"damage_parry": 8,
}

var stats: Dictionary = DEFAULT_STATS.duplicate(true)

const BJ_SCENES: Array[String] = [
	"res://Shared/main/scene/Castle.tscn",   # index 0
	"res://Shared/main/scene/CaveOne.tscn",  # index 1
	"res://boss_jatuh/scene/boss_play.tscn", # index 2
]

func _ready() -> void:
	load_from_disk()

# ===== Blackjack counter & scene routing =====
func get_blackjack_played() -> int:
	return int(stats.get("blackjack_played", 0))

func inc_blackjack_played(n: int = 1) -> void:
	stats["blackjack_played"] = get_blackjack_played() + n
	stats_changed.emit(stats)

func reset_blackjack_played() -> void:
	stats["blackjack_played"] = 0
	stats_changed.emit(stats)

func scene_after_blackjack() -> String:
	var played: int = get_blackjack_played()
	var idx: int = clampi(played, 0, BJ_SCENES.size() - 1)
	return BJ_SCENES[idx]

# ===== Health helpers (pakai current_health & max_health) =====
func set_current_health(value: int) -> void:
	var maxh: int = int(stats.get("max_health", DEFAULT_STATS["max_health"]))
	stats["current_health"] = clampi(value, 0, maxh)
	stats_changed.emit(stats)

func add_current_health(delta: int) -> void:
	set_current_health(int(stats.get("current_health", DEFAULT_STATS["current_health"])) + delta)

func set_max_health(value: int) -> void:
	value = max(1, value)
	stats["max_health"] = value
	# pastikan current tidak melebihi max baru
	stats["current_health"] = clampi(int(stats.get("current_health", value)), 0, value)
	stats_changed.emit(stats)

func add_max_health(delta: int) -> void:
	set_max_health(int(stats.get("max_health", DEFAULT_STATS["max_health"])) + delta)

# ===== Damage helpers (by kind) =====
func damage_for(kind: String) -> int:
	match kind:
		"melee": return int(stats.get("damage_melee", DEFAULT_STATS["damage_melee"]))
		"projectile": return int(stats.get("damage_projectile", DEFAULT_STATS["damage_projectile"]))
		"parry": return int(stats.get("damage_parry", DEFAULT_STATS["damage_parry"]))
		_: return int(stats.get("damage_melee", DEFAULT_STATS["damage_melee"]))

func set_damage(kind: String, value: int) -> void:
	var key := "damage_%s" % kind
	stats[key] = max(0, int(value))
	stats_changed.emit(stats)

func add_damage_kind(kind: String, delta: int) -> void:
	set_damage(kind, damage_for(kind) + delta)

# (kompatibilitas lama: kalau ada yang masih manggil add_damage(delta), anggap ke melee)
func add_damage(delta: int) -> void:
	add_damage_kind("melee", delta)

# ===== Dash cooldown =====
func set_dash_cooldown(v: float) -> void:
	stats["dash_cooldown"] = max(0.0, v)
	stats_changed.emit(stats)

func get_dash_cooldown() -> float:
	return float(stats.get("dash_cooldown", DEFAULT_STATS["dash_cooldown"]))

# ===== Generic delta (rapihin versi lama kamu) =====
func _apply_delta(stat: String, delta: int) -> void:
	match stat:
		"current_health": add_current_health(delta)
		"max_health": add_max_health(delta)
		"damage_melee": add_damage_kind("melee", delta)
		"damage_projectile": add_damage_kind("projectile", delta)
		"damage_parry": add_damage_kind("parry", delta)
		"blackjack_played":
			stats["blackjack_played"] = get_blackjack_played() + delta
			stats_changed.emit(stats)
		_:
			# fallback integer delta untuk key lain
			stats[stat] = int(stats.get(stat, 0)) + delta
			stats_changed.emit(stats)

# ===== Reset untuk “To Main Menu” =====
func reset_all() -> void:
	stats = DEFAULT_STATS.duplicate(true)
	stats_changed.emit(stats)
	save_to_disk()  # overwrite supaya sesi berikutnya juga bersih

# ===== Save / Load =====
func save_to_disk(path: String = SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"stats": stats}))
		f.close()

func load_from_disk(path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if parsed is Dictionary and parsed.has("stats"):
		var s: Dictionary = parsed["stats"]

		# migrasi kompatibilitas lama (kalau masih ada "health")
		if s.has("health") and not s.has("current_health"):
			s["current_health"] = int(s["health"])
			s.erase("health")

		# isi default & clamp yang wajib
		s["max_health"] = int(s.get("max_health", DEFAULT_STATS["max_health"]))
		s["current_health"] = clampi(int(s.get("current_health", s["max_health"])), 0, s["max_health"])
		s["dash_cooldown"] = float(s.get("dash_cooldown", DEFAULT_STATS["dash_cooldown"]))
		s["blackjack_played"] = int(s.get("blackjack_played", DEFAULT_STATS["blackjack_played"]))
		s["damage_melee"] = int(s.get("damage_melee", DEFAULT_STATS["damage_melee"]))
		s["damage_projectile"] = int(s.get("damage_projectile", DEFAULT_STATS["damage_projectile"]))
		s["damage_parry"] = int(s.get("damage_parry", DEFAULT_STATS["damage_parry"]))

		stats = s
		stats_changed.emit(stats)
