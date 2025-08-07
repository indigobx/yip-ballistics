extends Node3D

var c: int = 0
var weapon: WeaponData
var ammo: AmmoData
var projectile: Dictionary = {}
var dt: float = (1.0/60.0)  # 60 PhyFPS
#var dt: float = (1.0/600.0)
var timeout: float = 0.1
#var dt: float = 0.1
var t: float = 0.0
var ax_scale = 0.5
var exec_time: float = 0.0
var sum_exec_time: float = 0.0
var metrics: Dictionary = {}
@onready var raycast: RayCast3D = $RayCast3D


func _ready() -> void:
  if GameState.projectiles.values():
    projectile = GameState.projectiles.values()[-1]
  else:
    $Firearm.shoot()
    projectile = GameState.projectiles.values()[-1]
  weapon = projectile["weapon"]
  ammo = projectile["ammo"]
  _output_metrics()
  _draw_axes()
  _rotate_bullet_3d()
  #$Firearm.shoot()
  


func _output_metrics() -> void:
  %Output.clear()
  %Output.append_text("%s %s\n" % [weapon.name, ammo.name])
  %Output.append_text("[b]%s[/b] frames  T [b]%.4f[/b] s  Δt [b]%.4f[/b] s\n" % [
    c, t, dt
  ])
  var dt_us := float(1.0/60.0) * 1_000_000.0  # перевести секунды в микросекунды
  var exec_ratio := float(exec_time) / dt_us
  %Output.append_text("Exec time [b]%.0f[/b] µs ([b]%.2f[/b]%% of frame)\n\n" % [
    exec_time, exec_ratio*100
  ])
  sum_exec_time += exec_time 
  metrics = {
    "timing": {
      "frame": c,
      "time": t,
      "delta": dt,
      "exec_time": exec_time,
      "avg_exec_time": sum_exec_time/c,
      "exec_ratio": exec_ratio
    },
    "naming": {
      "weapon_name": weapon.name,
      "ammo_name": ammo.name,
      "projectile_uid": projectile.uid
    },
    "projectile": projectile,
    "medium": Physics.get_medium_properties(GameState.env_conditions["medium"])
  }
  $UI/Dump.text = "Dump\n%.0f frames" % len(Metrics.metric_storage)
  %Output.add_text(JSON.stringify(metrics, "  "))

func get_type_schema(original: Dictionary) -> Dictionary:
    var result = {}
    for key in original:
        result[key] = _get_type_info(original[key])
    return result

func _get_type_info(value) -> Variant:
    if value == null:
        return "null"
    
    var type = typeof(value)
    
    if type == TYPE_DICTIONARY:
        # Рекурсия для словарей
        var dict_result = {}
        for k in value:
            dict_result[k] = _get_type_info(value[k])
        return dict_result
    
    if type == TYPE_ARRAY:
        # Рекурсия для массивов (берём тип первого элемента)
        if value.is_empty():
            return "Array[]"
        return "Array[%s]" % _get_type_info(value[0])
    
    if type == TYPE_OBJECT and value is Object:
        return value.get_class()  # Для любых объектов
    
    # Базовые типы
    return str(type)

func _rotate_bullet_3d() -> void:
  %Bullet3D.basis = projectile.rotation

func _draw_axes() -> void:
  var vel = projectile.velocity * -1
  var rot = projectile.rotation.get_euler()
  var angvel = projectile.angular_velocity * -1
  %VelZ.to.x = vel.z
  %VelZ.value = "%.1f m/s" % abs(vel.z)
  %VelZ.update()
  %VelY.to.y = vel.y
  %VelY.value = "%.1f m/s" % abs(vel.y)
  %VelY.update()
  %VelX.to.x = vel.x*500
  %VelX.value = "%.4f m/s" % abs(vel.x)
  %VelX.update()
  %AngZ.to.x = angvel.z * 0.005
  %AngZ.value = "%.1f rad/s" % abs(angvel.z)
  %AngZ.update()
  %AngX.to.y = angvel.x
  %AngX.value = "%.1f rad/s" % abs(angvel.x)
  %AngX.update()
  %BulletRear.rotation = rot.z
  %Bullet.rotation = -rot.x
  
  %GraphVelX.add_value(abs(vel.x))
  %GraphVelY.add_value(abs(vel.y))
  %GraphVelZ.add_value(abs(vel.z))
  %GraphRotX.add_value(rad_to_deg(rot.x))
  %GraphRotY.add_value(rad_to_deg(rot.y))
  %GraphRotZ.add_value(rad_to_deg(rot.z))
  var kinetic_energy = (projectile.mass * vel.length_squared())/2
  %GraphKE.add_value(kinetic_energy)
  var dist = projectile.position.length()
  %GraphDist.add_value(dist)
  var medium = GameState.env_conditions["medium"]
  var rho = Physics.get_medium_properties(medium)["base_density"]
  %GraphRho.add_value(rho)
  
  %BarZ.value = Globals.normalize(abs(projectile.position.z), 0.0, 2000.0)
  %BarY.value = Globals.normalize(projectile.position.y, 5.0, -45.0)
  %BarX.value = Globals.normalize(projectile.position.x, 5.0, -5.0)
  
  %MediumVis.medium = medium
  
  %Shockwave.offset = %Bullet.nose_point
  %Shockwave.mach = projectile.mach_number

func _update_medium() -> void:
  var current_medium = GameState.env_conditions["medium"]
  var new_medium = GameState.get_medium_at_distance(abs(projectile.position.z))
  if current_medium != new_medium:
    GameState.env_conditions["medium"] = new_medium
    Ballistics.on_impact_or_medium_change(
      projectile,
      -projectile.velocity.normalized()
        .rotated(Vector3.UP, deg_to_rad(randf_range(-45.0, 45.0)))
        .normalized(),
      new_medium,
      1.0
    )
    print(projectile.position)


func _do_ballistics() -> void:
  var d_from = Vector2(
    projectile["position"].z,
    projectile["position"].y
  )
  var d_to = Vector2(10, 10)
  #%Debug2D.set_vector("test", d_from, d_to, Color.RED)
  
  
  #_update_medium()
  var t0 = Time.get_ticks_usec()
  var medium = GameState.env_conditions["medium"]
  var new_proj = Ballistics.update_projectile(projectile, dt, medium)
  # handle collsion after getting next step of projectile
  var from = projectile["position"]
  var to = new_proj["position"]
  var space = get_world_3d().direct_space_state
  var params = PhysicsRayQueryParameters3D.new()
  params.from = from
  params.to = to
  var result = space.intersect_ray(params)
  if result:
    new_proj = Ballistics.impact_projectile_v2(new_proj, result, dt)
  projectile = new_proj
  exec_time = Time.get_ticks_usec() - t0
  c += 1
  t += dt
  Metrics.record_metrics(
    Globals.prettify_dict(metrics)
  )
  
  _output_metrics()
  _draw_axes()
  _rotate_bullet_3d()



func _on_step_button_up() -> void:
  _do_ballistics()

func _on_toggle_toggled(toggled_on: bool) -> void:
  if toggled_on and $Timer.is_stopped():
    $Timer.start(timeout)
  if not toggled_on and not $Timer.is_stopped():
    $Timer.stop()


func _on_timer_timeout() -> void:
  _do_ballistics()


func _on_copy_button_up() -> void:
  #var text = "%s" % %Output.get_parsed_text()
  #text = text.split("\n\n")[-1]  # copy metrics JSON only
  DisplayServer.clipboard_set(JSON.stringify(metrics, "  "))


func _on_dump_button_up() -> void:
  _output_metrics()
  _draw_axes()
  Metrics.dump_metrics_json()
