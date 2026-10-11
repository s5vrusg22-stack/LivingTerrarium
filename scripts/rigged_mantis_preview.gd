extends Node3D
## Attach to a scene that contains an imported rigged GLB under Mantis.
## Play clips from the imported AnimationPlayer if available.
@export_enum("IDLE", "WALK", "ALERT", "GROOM", "HUNT", "STRIKE", "SCAN", "FEED", "CLIMB", "DEFEND") var selected_clip := "IDLE"
var player: AnimationPlayer

func _ready() -> void:
    player = find_child("AnimationPlayer", true, false) as AnimationPlayer
    if player != null:
        play_clip(selected_clip)

func play_clip(clip: String) -> void:
    if player == null:
        return
    for name in player.get_animation_list():
        if name == clip or name.ends_with("/" + clip):
            player.play(name)
            return
