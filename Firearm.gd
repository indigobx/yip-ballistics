extends Node3D

var weapon: WeaponData
var ammo: AmmoData


func _ready() -> void:
  #weapon = WeaponRegistry.get_weapon_by_name("Glock17_HST")
  #ammo = AmmoRegistry.get_ammo_by_name("9x19_HST_PlusP")
  #weapon = WeaponRegistry.get_weapon_by_name("FN_EVOLYS")
  #ammo = AmmoRegistry.get_ammo_by_name("7.62x51_SLAP_T")
  weapon = WeaponRegistry.get_weapon_by_name("SCAR_L_CQC")
  ammo = AmmoRegistry.get_ammo_by_name("5.56x45_M855")
  #weapon = WeaponRegistry.get_weapon_by_name("XPR_Railgun_MK1")
  #ammo = AmmoRegistry.get_ammo_by_name("5mm_Rail_Slug")
  #weapon = WeaponRegistry.get_weapon_by_name("KwK_40_L48")
  #ammo = AmmoRegistry.get_ammo_by_name("75mm_PzGr39_APCBC")

func shoot() -> void:
  var proj = Ballistics.create_projectile(
    weapon,
    ammo,
    GameState.muzzle_pos,
    GameState.muzzle_rot,
    GameState.env_conditions["medium"]
  )
  GameState.projectiles["test_proj_01"] = proj
