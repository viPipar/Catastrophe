extends TextureProgressBar

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		$".".visible = !$".".visible

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		push_error("GameState tidak ditemukan di /root/GameState")
		return

	var cb := Callable(self, "_on_stats_changed")
	if not gs.is_connected("stats_changed", cb):
		gs.connect("stats_changed", cb)

	# inisialisasi awal
	_on_stats_changed(gs.stats)

func _on_stats_changed(new_stats: Dictionary) -> void:
	print("[HPBar] _on_stats_changed:", new_stats)  # <<-- debug line
	if new_stats.has("max_health"):
		max_value = float(new_stats["max_health"])
	if new_stats.has("current_health"):
		value = float(new_stats["current_health"])
