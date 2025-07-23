extends Node

const JSON_PATH := "res://ammo_data.json"
var ammo_dict: Dictionary = {}
var ammo_list: Array[AmmoData] = []

func _ready():
  load_ammo_from_json()
  
func load_ammo_from_json():
  var file = FileAccess.open(JSON_PATH, FileAccess.READ)
  if file == null:
    push_error("Failed to open ammo JSON file: %s" % FileAccess.get_open_error())
    return
  
  var json = JSON.new()
  var parse_result = json.parse(file.get_as_text())
  if parse_result != OK:
    push_error("JSON parse error: %s" % json.get_error_message())
    return
  
  var data = json.get_data()
  var entries: Array = data.get("ammo", [])
  
  ammo_dict.clear()
  ammo_list.clear()
  
  for entry in entries:
    var ammo = parse_ammo_dict(entry)
    if ammo != null:
      ammo_dict[ammo.name] = ammo
      ammo_list.append(ammo)
  
  var out = "Loaded %s ammo data:" % len(ammo_list)
  for a in ammo_list:
    out += " %s," % a.name
  print(out.substr(0, len(out)-1) + ".")

  

func parse_ammo_dict(dict: Dictionary) -> AmmoData:
  var ammo = AmmoData.new()

  # Явно задаём значения — только известные поля
  ammo.name = dict.get("name", "")
  ammo.speed = dict.get("speed", 0.0)
  ammo.mass = dict.get("mass", 0.0)
  ammo.caliber = dict.get("caliber", 0.0)
  ammo.length = dict.get("length", 0.0)
  ammo.spread_moa = dict.get("spread_moa", 4.0)
  ammo.drag_coef = dict.get("drag_coef", 0.0)
  ammo.stab_type = dict.get("stab_type", 0)
  ammo.has_thruster = dict.get("has_thruster", false)
  ammo.thrust_force = dict.get("thrust_force", 0.0)
  ammo.fuel_mass = dict.get("fuel_mass", 0.0)
  ammo.burn_time = dict.get("burn_time", 0.0)
  ammo.core_mass = dict.get("core_mass", 0.0)
  ammo.core_hardness = dict.get("core_hardness", 1.0)
  ammo.core_caliber = dict.get("core_caliber", 0.0)
  ammo.can_ricochet = dict.get("can_ricochet", true)
  ammo.ricochet_min_angle = dict.get("ricochet_min_angle", 20.0)
  ammo.ricochet_max_angle = dict.get("ricochet_max_angle", 75.0)
  ammo.ricochet_chance = dict.get("ricochet_chance", 0.5)
  ammo.explosive = dict.get("explosive", false)
  ammo.explosive_mass = dict.get("explosive_mass", 0.0)
  ammo.explosive_coef = dict.get("explosive_coef", 1.0)
  ammo.fuse_delay_msec = dict.get("fuse_delay_msec", 0.0)
  ammo.fuse_delay_distance = dict.get("fuse_delay_distance", 0.0)
  ammo.fuse_arm_distance = dict.get("fuse_arm_distance", 0.0)
  ammo.fuse_init_rule = dict.get("fuse_init_rule", 0)
  ammo.fuse_init_angle = dict.get("fuse_init_angle", 45.0)
  ammo.fuse_init_speed = dict.get("fuse_init_speed", 100.0)
  ammo.fragments_min = dict.get("fragments_min", 0)
  ammo.fragments_max = dict.get("fragments_max", 0)
  ammo.fragmentation_chance = dict.get("fragmentation_chance", 0.5)

  return ammo

func get_ammo_by_name(aname: String) -> AmmoData:
  return ammo_dict.get(aname, null)
