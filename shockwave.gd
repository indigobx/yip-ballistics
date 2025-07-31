extends Node2D

@export var mach: float = 0.0:
  get:
    return _mach
  set(value):
    _mach = value
    queue_redraw()
var _mach: float
@export var offset: Vector2 = Vector2.ZERO:
  get:
    return _offset
  set(value):
    _offset = value
    queue_redraw()
var _offset: Vector2
@export var base_direction := Vector2.RIGHT

var shockwave_half_profile: Array = []
var mach_angle: float
@export var length: float = 100.0


func _ready() -> void:
  _calc_shockwave()

func _draw() -> void:
  if mach >= 1.0:
    _calc_shockwave()
    _draw_shockwave()
  else:
    $Line2D.points = []

func _calc_shockwave() -> void:
  mach_angle = asin(1/mach)

func _draw_shockwave() -> void:
  var direction = base_direction.normalized().rotated(mach_angle - PI)

  var p0 = offset + direction*length
  var p1 = offset
  var p2 = Vector2(p0.x, -p0.y)
  var points = [p0, p1, p2]
  $Line2D.points = points
