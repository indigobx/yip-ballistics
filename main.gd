extends Node

var c: int = 0
var weapon: WeaponData
var ammo: AmmoData
var muzzle_pos := Vector3.ZERO
var muzzle_rot := Basis.IDENTITY
var projectile: Dictionary = {}
var dt: float = (1.0/60.0)
#var dt: float = 0.1
var t: float = 0.0
var ax_scale = 0.5
var exec_time: float = 0.0
var metrics: Dictionary = {}


func _ready() -> void:
  muzzle_pos = Vector3(0, 0, 0)
  var yaw = deg_to_rad(0.0)
  var pitch = deg_to_rad(0.0)
  muzzle_rot = Basis(Vector3.UP, yaw) * Basis(Vector3.LEFT, pitch)
  #weapon = WeaponRegistry.get_weapon_by_name("Glock17_HST")
  #ammo = AmmoRegistry.get_ammo_by_name("9x19_HST_PlusP")
  weapon = WeaponRegistry.get_weapon_by_name("SCAR_L_CQC")
  ammo = AmmoRegistry.get_ammo_by_name("5.56x45_M855")
  projectile = Ballistics.create_projectile(
    weapon, ammo, muzzle_pos, muzzle_rot
  )
  _print_text()
  _draw_axes()


func _print_text() -> void:
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
  metrics = {
    "timing": {
      "frame": c,
      "time": t,
      "delta": dt,
      "exec_time": exec_time,
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
  %Output.add_text(JSON.stringify(metrics, "  "))

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
  %Bullet.rotation = rot.x
  
  %GraphVelX.add_value(abs(vel.x))
  %GraphVelY.add_value(abs(vel.y))
  %GraphVelZ.add_value(abs(vel.z))
  %GraphRotX.add_value(rot.x)
  %GraphRotY.add_value(rot.y)
  %GraphRotZ.add_value(rot.z)
  var kinetic_energy = (projectile.mass * vel.length_squared())/2
  %GraphKE.add_value(kinetic_energy)
  var dist = projectile.position.length()
  %GraphDist.add_value(dist)

func _do_ballistics() -> void:
  var t0 = Time.get_ticks_usec()
  var new_proj = Ballistics.update_projectile(projectile, dt)
  exec_time = Time.get_ticks_usec() - t0
  projectile = new_proj
  c += 1
  t += dt
  _print_text()
  _draw_axes()
  Metrics.send_metrics(metrics)

func _on_step_button_up() -> void:
  _do_ballistics()

func _on_toggle_toggled(toggled_on: bool) -> void:
  if toggled_on and $Timer.is_stopped():
    $Timer.start()
  if not toggled_on and not $Timer.is_stopped():
    $Timer.stop()


func _on_timer_timeout() -> void:
  _do_ballistics()


func _on_copy_button_up() -> void:
  #var text = "%s" % %Output.get_parsed_text()
  #text = text.split("\n\n")[-1]  # copy metrics JSON only
  DisplayServer.clipboard_set(JSON.stringify(metrics, "  "))
