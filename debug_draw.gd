extends Node3D
class_name DebugDraw3D

var lines := []
var points := []
var line_mesh := ImmediateMesh.new()
var point_mesh := ImmediateMesh.new()
var line_mat := StandardMaterial3D.new()
var point_mat := StandardMaterial3D.new()

func _ready():
  var mesh_instance := MeshInstance3D.new()
  mesh_instance.mesh = line_mesh
  add_child(mesh_instance)
  
  var point_instance := MeshInstance3D.new()
  point_instance.mesh = point_mesh
  add_child(point_instance)
  
  line_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
  line_mat.albedo_color = Color(1, 0, 0, 1)
  point_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
  point_mat.albedo_color = Color(0, 1, 0, 1)
  
  mesh_instance.material_override = line_mat
  point_instance.material_override = point_mat

func _process(_delta):
  line_mesh.clear_surfaces()
  point_mesh.clear_surfaces()
  
  # Рисуем линии
  if lines:
    line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    for line in lines:
      line_mesh.surface_add_vertex(line.from)
      line_mesh.surface_add_vertex(line.to)
    line_mesh.surface_end()
  
  # Рисуем точки
  if points:
    point_mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
    for point in points:
      point_mesh.surface_add_vertex(point.position)
    point_mesh.surface_end()
  
  lines.clear()
  points.clear()

func draw_line(from: Vector3, to: Vector3, color: Color = Color.RED):
  lines.append({from = from, to = to, color = color})

func draw_point(position: Vector3, color: Color = Color.GREEN):
  points.append({position = position, color = color})
