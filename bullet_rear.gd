extends Control

@export var radius: float = 10.0
@export var num: int = 16
var points = []

func _ready() -> void:
  _fill_points()
  _draw_circle()
  #_draw_label()

#func _draw_label() -> void:
  #$Label.text = "%.1d°" % rotation_degrees
  #$Label.position = Vector2(radius, radius*0.5)

func _draw_circle() -> void:
  $Circle.clear_points()
  $Circle2.clear_points()
  $LineUp.clear_points()
  for p in points:
    $Circle.add_point(p)
    $Circle2.add_point(p*0.5)
  $LineUp.add_point(Vector2(0.0, -radius*0.5))
  $LineUp.add_point(Vector2(0.0, -radius*1.5))

func _fill_points() -> void:
  for i in range(num):
    var angle = TAU * i / num  # TAU = 2π, полный круг
    var x = radius * cos(angle)
    var y = radius * sin(angle)
    points.append(Vector2(x, y))
