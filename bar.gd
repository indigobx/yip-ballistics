extends Control

@export var main_thickness = 1.0
@export var tick_thickness = 0.5
@export var marker_thickness = 0.5
var color = Color.WHITE
var margin = 6
@onready var w = size.x
@onready var h = size.y
@export var value = 0.0
@export var central_tick = true
@export var ticks = 16
@export var antialias = false


func _ready() -> void:
  pass

func _process(delta: float) -> void:
  queue_redraw()

func _draw() -> void:
  draw_line(Vector2(margin, h/4), Vector2(w-margin, h/4), color, main_thickness, antialias)  # draw main bar
  draw_line(Vector2(margin, 0), Vector2(margin, h/2), color, main_thickness, antialias)
  draw_line(Vector2(w-margin, 0), Vector2(w-margin, h/2), color, main_thickness, antialias)  # draw edge bars
  
  var pos = lerpf(margin, w-margin, value)
  var triangle = [
    Vector2(pos, h/2),
    Vector2(pos+margin, h),
    Vector2(pos-margin, h),
    Vector2(pos, h/2)
  ]
  draw_polyline(
    triangle, color, main_thickness, antialias
  )
  if central_tick:
    var center_x = lerpf(margin, w - margin, 0.5)
    draw_line(Vector2(center_x, 0), Vector2(center_x, h / 4), color, tick_thickness, antialias)
  for i in range(ticks + 1):
    var t = float(i) / float(ticks)
    var x = lerpf(margin, w - margin, t)
    draw_line(Vector2(x, h / 2), Vector2(x, h / 4), color, tick_thickness, antialias)
