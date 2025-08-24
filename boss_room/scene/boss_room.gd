extends ParallaxBackground

@onready var hurt_sfx: AudioStreamPlayer = $HurtSFX
@onready var hurtbox1: Area2D = $Hurtbox
@onready var hurtbox2: Area2D = $Hurtbox2

var health: int = 500

func _ready() -> void:
	# connect sinyal dari kedua hurtbox
	hurtbox1.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox2.area_entered.connect(_on_hurtbox_area_entered)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	# cek apakah nama area yang masuk adalah "AttackArea" atau "Projectile"
	if area.name == "AttackArea" or area.name == "Projectile":
		_take_damage(20) # contoh damage default 100, bisa diganti sesuai kebutuhan
		if not hurt_sfx.playing:
			hurt_sfx.play()

func _take_damage(amount: int) -> void:
	health -= amount
	print("Health:", health)

	if health <= 0:
		_game_over()

func _game_over() -> void:
	get_tree().change_scene_to_file("res://boss_kalah.tscn")
