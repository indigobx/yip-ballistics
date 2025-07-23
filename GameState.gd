extends Node

var cursor_screen_pos := Vector2.ZERO
var cursor_world_pos := Vector3.ZERO
var gun_muzzle_pos := Vector3(1, 0, 0)
var vision_point := Vector3.ZERO
var focus_point := Vector3.ZERO
@onready var game = get_tree().root.get_node_or_null("Main/Game")

var debug_text := ""

var env_conditions: Dictionary = {
  "gravity": 9.78863,  # Miami
  "temperature": 22.0,  # Celsius
  "medium": Physics.Medium.AIR_CLEAN,
  "wind_strength": 0.0,  # m/s
  "wind_direction": Vector3(1.0, 0.0, 0.0)
}

var projectiles = {}
