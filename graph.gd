extends Control

@export var graph_width: int = 100
@export var color: Color = Color.CYAN
@export var thickness: float = 2.0
@export var min: float = 0.0
@export var max: float = 100.0
@export var hard_limits: bool = false
@export var thresholds: Array[float] = []
@export var label: String = "LBL"

var values: Array[float] = []

func _ready() -> void:
  $Label.modulate = color
  $Label.text = label
  $Value.modulate = color

func add_value(val: float) -> void:
  values.append(val)
  if values.size() > graph_width:
    values.pop_front()
  $Value.text = "%.1f" % val
  queue_redraw()  # вместо update() в Godot 4

func _draw() -> void:
  if values.size() < 2:
    return

  var w = size.x
  var h = size.y
  var step_x = w / max(1.0, float(graph_width - 1))

  var data_min = min if hard_limits else values.min()
  var data_max = max if hard_limits else values.max()
  
  if data_max == data_min:
    data_max += 1.0  # предотвращение деления на 0

  var points: PackedVector2Array = []

  for i in values.size():
    var x = i * step_x
    var value = clamp(values[i], data_min, data_max)
    var y = h - ((value - data_min) / (data_max - data_min)) * h
    points.append(Vector2(x, y))

  draw_polyline(points, color, thickness)

  # Рисуем пороги (thresholds)
  for t in thresholds:
    var y = h - ((t - data_min) / (data_max - data_min)) * h
    draw_line(Vector2(0, y), Vector2(w, y), Color.YELLOW, 0.5, true)
  
