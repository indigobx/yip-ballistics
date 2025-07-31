extends Node

var cursor_screen_pos := Vector2.ZERO
var cursor_world_pos := Vector3.ZERO
var gun_muzzle_pos := Vector3(1, 0, 0)
var vision_point := Vector3.ZERO
var focus_point := Vector3.ZERO
@onready var game = get_tree().root.get_node_or_null("Main/Game")

var muzzle_pos = Vector3(0, 0, 0)
var yaw = deg_to_rad(0.0)
var pitch = -deg_to_rad(45.0)  # (0.1° up really) is good
var muzzle_rot

var debug_text := ""

var env_conditions: Dictionary = {
  "gravity": 9.78863,  # Miami
  "temperature": 22.0,  # Celsius
  "medium": Physics.Medium.AIR_CLEAN,  # to be set in layered medium
  "wind_strength": 0.0,  # m/s
  "wind_direction": Vector3(1.0, 0.0, 0.0)
}

var layered_medium = {
  0.0: Physics.Medium.AIR_CLEAN,
  30.0: Physics.Medium.FLESH_MUSCLE,
  30.4: Physics.Medium.AIR_CLEAN,
  #2.5: Physics.Medium.FLESH_SKIN,
  #3.0: Physics.Medium.AIR_CLEAN,
}

var projectiles = {}

func _ready() -> void:
  env_conditions["medium"] = get_medium_at_distance(0.0)
  muzzle_rot = Basis(Vector3.UP, yaw) * Basis(Vector3.LEFT, pitch)

func get_medium_at_distance(dist: float) -> Physics.Medium:
  var keys = layered_medium.keys()
  keys.sort()  # Обязательно, если словарь не отсортирован

  var result = layered_medium[keys[0]]  # По умолчанию — первая среда

  for key in keys:
    if dist < key:
      break
    result = layered_medium[key]

  return result
