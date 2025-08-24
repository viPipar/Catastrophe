extends Button

@onready var anim: AnimationPlayer = $"../../AnimationPlayer"
@export var slide_duration: float = 0.35
@export var delete_on_finish: bool = false
@export var heal_to_full: bool = true

var _sliding: bool = false

func _on_pressed() -> void:
	if _sliding: return
	_sliding = true
	disabled = true

	# ===== BUFF: +50% max_health =====
	var old_max: int = int(GameState.stats.get("max_health", 100))
	var old_cur: int = int(GameState.stats.get("current_health", old_max))
	var delta: int   = int(round(old_max * -0.5))
	var new_max: int = old_max + delta
	var new_cur: int
	if heal_to_full:
		new_cur = old_cur + delta
	else:
		var ratio: float = (float(old_cur) / float(old_max)) if old_max > 0 else 1.0
		new_cur = clampi(int(round(ratio * new_max)), 0, new_max)

	GameState.stats["max_health"] = new_max
	GameState.stats["current_health"] = new_cur
	GameState.stats_changed.emit(GameState.stats)

	# ===== Scene berikut berdasarkan counter blackjack =====
	var next_scene: String = GameState.scene_after_blackjack()
	GameState.inc_blackjack_played()

	# ===== Anim geser & fade tombol =====
	var vp_h: float = float(get_viewport_rect().size.y)
	var target_y: float = vp_h + size.y

	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", target_y, slide_duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, slide_duration)

	await tw.finished
	if delete_on_finish:
		queue_free()
	else:
		visible = false

	await get_tree().create_timer(0.5).timeout
	anim.play("fade_in")
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file(next_scene)
