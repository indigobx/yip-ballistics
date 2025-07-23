extends Node3D

func create_projectile(weapon: WeaponData, ammo: AmmoData, muzzle_pos: Vector3, muzzle_rot: Basis) -> Dictionary:
  var direction = -muzzle_rot.z.normalized()
  
  var length_diameter_ratio = 3.0
  if ammo.get("length") != null and ammo.caliber > 0:
    length_diameter_ratio = ammo.length / ammo.caliber
  elif ammo.get("length_diameter_ratio") != null:
    length_diameter_ratio = ammo.length_diameter_ratio
  
  var angular_velocity = Vector3.ZERO
  #if ammo.stab_type == 1:
    #var twist_rate_m = weapon.twist_rate * 0.001
    #var spin_magnitude = (2.0 * PI * ammo.speed) / twist_rate_m
    #angular_velocity = Vector3(0, 0, spin_magnitude) * (-1.0 if weapon.rifling_clockwise else 1.0)
  if ammo.stab_type == 1:
    var twist_rate_m = weapon.twist_rate * 0.001
    var spin_magnitude = (2.0 * PI * ammo.speed) / twist_rate_m

    var spin_axis_local = Vector3(0, 0, 1)  # Вращение вдоль оси пули (Z локальная)
    var spin_axis_world = (muzzle_rot * Vector3(0, 0, 1)).normalized()

    angular_velocity = spin_axis_world * spin_magnitude * (-1.0 if weapon.rifling_clockwise else 1.0)

  return {
    "weapon": weapon,
    "ammo": ammo,
    "weapon.name": weapon.name,
    "ammo.name": ammo.name,
    "uid": Globals.gen_uid(8, "proj_"),
    "position": muzzle_pos,
    "velocity": direction * ammo.speed,
    "rotation": muzzle_rot,
    "flight_time": 0.0,
    "mass": ammo.mass,
    "caliber": ammo.caliber,
    "drag_coef": ammo.drag_coef,
    "cross_section": PI * pow(ammo.caliber * 0.0005, 2),
    "length": ammo.length,
    "length_diameter_ratio": length_diameter_ratio,
    "core_mass": ammo.core_mass,
    "core_hardness": ammo.core_hardness,
    "core_caliber": ammo.core_caliber,
    "kind": "normal",
    "state": "normal",
    "ricochet_min_angle": ammo.ricochet_min_angle,
    "ricochet_max_angle": ammo.ricochet_max_angle,
    "fragmentation_chance": ammo.get_property("fragmentation_chance", 0.0),
    "fragments_min": ammo.get_property("fragments_min", 0),
    "fragments_max": ammo.get_property("fragments_max", 0),
    "impact_count": 0,
    "ricochet_count": 0,
    "penetration_count": 0,
    "fragmentation_count": 0,
    "ttl": Time.get_ticks_msec() / 1000.0 + Config.projectile_ttl,
    "spin_decay_rate": 0.998,
    "angular_velocity": angular_velocity,
    "magnus_effect_factor": 0.00025 * weapon.rifling_depth_mm * length_diameter_ratio
  }

func update_projectile(proj: Dictionary, delta: float) -> Dictionary:
  var new_proj = proj.duplicate(true)
  var medium = GameState.env_conditions["medium"]
  
  match medium:
    Physics.Medium.WATER_FRESH:
      _apply_underwater_physics(new_proj, delta)
    Physics.Medium.VACUUM:
      _apply_vacuum_physics(new_proj, delta)
    _:
      _apply_air_physics(new_proj, delta)
  
  if not new_proj["velocity"].is_finite():
    new_proj["velocity"] = Vector3.ZERO
  if not new_proj["position"].is_finite():
    new_proj["position"] = Vector3.ZERO
  new_proj["position"] += new_proj["velocity"] * delta
  return new_proj

func _apply_air_physics(proj: Dictionary, delta: float) -> void:
  _apply_gravity(proj, delta)
  _apply_drag_linear(proj, delta)
  _apply_drag_angular(proj, delta)
  _apply_wind(proj, delta)
  _apply_spin(proj, delta)

func _apply_underwater_physics(proj: Dictionary, delta: float) -> void:
  # Получаем параметры воды из Globals
  var medium_profile = Physics.get_medium_properties(Physics.Medium.WATER_FRESH)
  var density = Physics.get_density(Physics.Medium.WATER_FRESH)
  var viscosity = Physics.get_viscosity(Physics.Medium.WATER_FRESH)
  
  # 1. Гидродинамическое сопротивление (комбинация квадратичного и вязкого)
  var speed = proj["velocity"].length()
  var radius = proj["caliber"] * 0.0005
  
  # Квадратичное сопротивление (доминирует на высоких скоростях)
  var quadratic_drag = 0.5 * density * speed * speed * proj["drag_coef"] * proj["cross_section"]
  
  # Вязкое сопротивление (по Стоксу, доминирует на низких скоростях)
  var stokes_drag = 6 * PI * viscosity * radius * speed
  
  # Комбинированная модель (переход между режимами)
  var total_drag = quadratic_drag + stokes_drag
  proj["velocity"] -= total_drag * delta / (proj["mass"] * 0.001) * proj["velocity"].normalized()
  
  # 2. Динамическая плавучесть (зависит от глубины)
  var depth_factor = clamp(abs(proj["position"].y) / 10.0, 0.0, 1.0)
  var buoyancy = (0.5 + 0.3 * depth_factor) * GameState.env_conditions["gravity"] * delta
  proj["velocity"].y += buoyancy
  
  # 3. Быстрая потеря вращения (в 5 раз быстрее чем в воздухе)
  proj["angular_velocity"] *= pow(0.8, delta) 
  
  # 4. Дополнительные эффекты для пуль в воде
  if proj["flight_time"] < 0.1:  # Первые 100мс - кавитация
    proj["velocity"] *= 0.95  # Дополнительные потери энергии

func _apply_vacuum_physics(proj: Dictionary, delta: float) -> void:
  proj["velocity"].y -= GameState.env_conditions["gravity"] * delta
  proj["angular_velocity"] *= 0.999 ** delta

func _apply_gravity(proj: Dictionary, delta: float) -> void:
  proj["velocity"].y -= GameState.env_conditions["gravity"] * delta

func _apply_drag_linear(proj: Dictionary, delta: float) -> void:
  var env = GameState.env_conditions
  var density = Physics.get_density(env["medium"], env["temperature"], env.get("pressure", -1.0))
  
  var mass_kg = proj["mass"] * 0.001
  var speed = proj["velocity"].length()
  var drag_force = 0.5 * density * speed * speed * proj["drag_coef"] * proj["cross_section"]
  proj["velocity"] -= drag_force * delta / mass_kg * proj["velocity"].normalized()

func _apply_viscous_drag(proj: Dictionary, density: float, viscosity: float, delta: float) -> void:
  var radius = proj["caliber"] * 0.0005
  var drag_force = 6 * PI * viscosity * radius * proj["velocity"]
  proj["velocity"] -= drag_force * delta / (proj["mass"] * 0.001)

func _apply_drag_angular(proj: Dictionary, delta: float) -> void:
  if proj["angular_velocity"].length_squared() > 0:
    var angular_drag = 0.1 * proj["drag_coef"] * delta
    proj["angular_velocity"] *= 1.0 - angular_drag

func _apply_wind(proj: Dictionary, delta: float) -> void:
  var wind = GameState.env_conditions["wind_direction"].normalized() * GameState.env_conditions["wind_strength"]
  proj["velocity"] += (wind - proj["velocity"]) * 0.05 * delta

func _apply_spin(proj: Dictionary, delta: float) -> void:
  if proj["ammo"].stab_type != 1:
    return

  # 1. Получаем текущее вращение
  var rot = Basis(proj["rotation"])
  if not _is_basis_valid(rot):
    rot = Basis.IDENTITY

  # 2. Применяем потери вращения
  var spin_decay = 0.998  # Воздух
  if GameState.env_conditions["medium"] == Physics.Medium.WATER_FRESH:
    spin_decay = 0.8  # Вода
  
  proj["angular_velocity"] *= pow(spin_decay, delta)

  # 3. Вращаем снаряд
  if proj["angular_velocity"].length_squared() > 0.01:
    var axis = proj["angular_velocity"].normalized()
    var angle = proj["angular_velocity"].length() * delta
    rot = rot.rotated(axis, angle)
    proj["rotation"] = rot

  # 4. Эффект Магнуса (только для нормальных снарядов)
  if proj["state"] == "normal" and proj["angular_velocity"].length() > 10.0:
    var vel_dir = proj["velocity"].normalized()
    if _is_vector_valid(vel_dir):
      var magnus_dir = proj["angular_velocity"].cross(vel_dir)
      if magnus_dir.length_squared() > 0:
        var magnus_force = magnus_dir * proj["magnus_effect_factor"]
        proj["velocity"] += magnus_force * delta
        #print("magnus_force:", magnus_force)
        #print("angular_velocity:", proj["angular_velocity"])
        #print("velocity:", proj["velocity"])
        #print("cross:", proj["angular_velocity"].cross(proj["velocity"]))



func _is_vector_valid(v: Vector3) -> bool:
  return v.x != NAN and v.y != NAN and v.z != NAN and v.is_finite()

func _is_basis_valid(b: Basis) -> bool:
  return _is_vector_valid(b.x) and _is_vector_valid(b.y) and _is_vector_valid(b.z)

func get_medium_density(medium: Physics.Medium, temp: float, pressure: float = -1.0) -> float:
  return Physics.get_medium_density(medium, temp, pressure)

func get_aim_direction(from: Vector3, to: Vector3, ammo: AmmoData) -> Vector3:
  var g: float = GameState.env_conditions.get("gravity", 9.81)
  var v0: float = ammo.speed
  if v0 <= 0.0:
    push_warning("Ammo speed is zero or negative.")
    return (to - from).normalized()

  var flat_distance: float = (to - from).length()
  var flight_time: float = flat_distance / v0
  var drop: float = 0.5 * g * flight_time * flight_time

  var corrected_to: Vector3 = to + Vector3.UP * drop
  return (corrected_to - from).normalized()

func get_targets_in_radius(position: Vector3, radius: float) -> Array:
  var space_state = get_world_3d().direct_space_state
  var query = PhysicsShapeQueryParameters3D.new()
  query.shape = SphereShape3D.new()
  query.shape.radius = radius
  query.transform = Transform3D.IDENTITY.translated(position)
  return space_state.intersect_shape(query)
