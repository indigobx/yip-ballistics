extends Control

var half_profile = [
  Vector2(0.0, 0.0),  # tip
  Vector2(-0.6, 0.18),          # ogive approx 1/3
  Vector2(-1.3, 0.36),          # ogive approx 2/3
  Vector2(-2.180, 0.5),  # ogive end
  Vector2(-3.630, 0.5),  # cylinder end
  Vector2(-4.230, 0.421),  # boattail end
  Vector2(-4.230, 0.0)  # tip end
]
var cog = 0.6  # center of gravity from the tip [0, 1]
var offset = Vector2.ZERO
var full_profile = []
@onready var bullet = $BulletShape
@export var caliber: float = 12.7

func _ready() -> void:
  offset.x = 4.230 * cog
  for point in half_profile:
    full_profile.append(point)
  for i in range(half_profile.size() - 1, 0, -1):
    var p = half_profile[i]
    full_profile.append(Vector2(p.x, -p.y))

  _draw_bullet()

func _draw_bullet() -> void:
  bullet.clear_points()
  for p in full_profile:
    bullet.add_point((p + offset) * caliber)
