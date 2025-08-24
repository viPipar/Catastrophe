extends Button

@onready var anim: AnimationPlayer = $"../../AnimationPlayer"
@export var slide_duration := 0.35
@export var delete_on_finish := false

var _sliding := false


func _on_pressed():
	if _sliding: return
	_sliding = true
	disabled = true

	# target = di bawah layar + tinggi tombol (biar benar-benar keluar)
	var vp_h: float = float(get_viewport_rect().size.y)
	var target_y: float = vp_h + size.y
	var next_scene := String(GameState.scene_after_blackjack())
	GameState.inc_blackjack_played()

	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", target_y, slide_duration)
	tw.parallel().tween_property(self, "modulate:a", 0.0, slide_duration)
	
	GameState.inc_blackjack_played()
	await tw.finished
	if delete_on_finish:
		queue_free()
	else:
		visible = false
	await get_tree().create_timer(0.5).timeout
	anim.play("fade_in")
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file(next_scene)
