extends Node2D

@onready var anim: AnimationPlayer = $gerakan_ekor_animation

func _ready() -> void:
	# Timer untuk up_attack (12 detik)
	var up_timer = Timer.new()
	up_timer.wait_time = 12.0
	up_timer.one_shot = false
	up_timer.autostart = true
	add_child(up_timer)
	up_timer.timeout.connect(_on_up_attack_timeout)

	# Timer untuk down_attack (8 detik)
	var down_timer = Timer.new()
	down_timer.wait_time = 8.0
	down_timer.one_shot = false
	down_timer.autostart = true
	add_child(down_timer)
	down_timer.timeout.connect(_on_down_attack_timeout)


func _on_up_attack_timeout() -> void:
	anim.play("ekor_up_attack")

func _on_down_attack_timeout() -> void:
	anim.play("ekor_down_attack")
