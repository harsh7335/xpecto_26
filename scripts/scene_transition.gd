extends CanvasLayer

@onready var animation_player = $AnimationPlayer

func _ready():
	# Make sure it's transparent when the game first boots up
	$ColorRect.modulate.a = 0

func change_scene(target_path: String) -> void:
	# 1. Play the fade to black
	animation_player.play("dissolve")
	
	# 2. Wait for the animation to finish
	await animation_player.animation_finished
	
	# 3. Change the actual scene while the screen is black
	get_tree().change_scene_to_file(target_path)
	
	# 4. Play the animation backwards to fade back into the new level!
	animation_player.play_backwards("dissolve")
