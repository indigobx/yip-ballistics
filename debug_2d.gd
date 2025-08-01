extends Control

var lines: Dictionary = {}
var points: Dictionary = {}

func set_vector(id, from, to, color) -> void:
  var line: Line2D
  from = Vector2(from.z, from.y)
  to = Vector2(to.z, to.y)
  if id in lines:
    line = lines[id]
    line.clear_points()
  else:
    line = Line2D.new()
    add_child(line)
  line.add_point(from)
  line.add_point(to)
  line.width = 1.0
  line.default_color = color
  lines[id] = line

func set_point(id, pos, color) -> void:
  var point: Polygon2D
  if id in points:
    point = points[id]
  else:
    point = Polygon2D.new()
    var pts = []
    for i in range(12):
      var angle = TAU * i / 12
      var p = Vector2(cos(angle), sin(angle)) * 5
      pts.append(p)
    point.polygon = PackedVector2Array(pts)
    add_child(point)
  point.offset = Vector2(pos.z, pos.y)
  point.color = color
  points[id] = point
