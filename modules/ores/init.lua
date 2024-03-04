-- ores/init.lua

local me = microexpansion
local mcl_core_modpath = minetest.get_modpath("mcl_core")
stone_ingrediant = mcl_core_modpath and "mcl_core:stone" or "default:stone"


local incranium_y_min = -300
local incranium_y_max = -90

local quartz_y_min = -31000
local quartz_y_max = -5

local incranium_cracky = 3
local quartz_cracky = 3

if mcl_core_modpath then
  incranium_y_min = -55
  incranium_y_max = -20
  quartz_y_min = -50
  quartz_y_max = 0
  incranium_cracky = 3
  quartz_cracky = 3
end

local quartz_nodedef = {
  description = "Quartz Ore",
  tiles = { "default_stone.png^microexpansion_ore_quartz.png" },
  is_ground_content = true,
  type = "ore",
  groups = {cracky=quartz_cracky,material_stone=1, stone=1, pickaxey=3},
  drop = "microexpansion:quartz_crystal",
  oredef = {{
    ore_type = "scatter",
    wherein = stone_ingrediant,
    clust_scarcity = 10*10*10,
    clust_num_ores = 6,
    clust_size = 5,
    y_min = quartz_y_min,
    y_max = quartz_y_max,
  }},
}

incranium_nodedef = {
  description = "Incranium Ore",
  tiles = { "incranium" },
  is_ground_content = true,
  groups = {cracky=incranium_cracky, material_stone=1, stone=1,pickaxey=3 },
  type = "ore",
  oredef = {
    {
      ore_type = "blob",
      wherein = stone_ingrediant,
      clust_scarcity = 4*4*4,
      clust_num_ores = 4,
      clust_size = 3,
      y_min = incranium_y_min,
      y_max = incranium_y_max,
    },
  },
  disabled = true,
}

if mcl_core_modpath then
  quartz_nodedef._mcl_hardness = 3
  quartz_nodedef._mcl_blast_resistance = 3
  quartz_nodedef._mcl_hardness = 3
  quartz_nodedef._mcl_silk_touch_drop = true
  quartz_nodedef._mcl_fortune_drop = mcl_core.fortune_drop_ore

  incranium_nodedef._mcl_hardness = 3
  incranium_nodedef._mcl_blast_resistance = 3
  incranium_nodedef._mcl_hardness = 3
  incranium_nodedef._mcl_silk_touch_drop = true
  incranium_nodedef._mcl_fortune_drop = mcl_core.fortune_drop_ore
end

-- [register] Incranium Ore
me.register_node("incranium", incranium_nodedef)

me.register_item("quartz_crystal", {
  description = "Quartz Crystal",
})


me.register_node("quartz", quartz_nodedef)

local glcraft_modpath = minetest.get_modpath("glcraft")
if glcraft_modpath then
  local glass_ingredient = "default:glass"
  if mcl_core_modpath then glass_ingredient = "mcl_core:glass" end
  -- glcraft is part of the nonsensical_skyblock game. It doesn't have a world,
  -- so we need to add a crafting recipe for the ores.
  minetest.register_craft({
    output = "microexpansion:quartz",
    recipe = {
      {"bonemeal:fertiliser", glass_ingredient, "bonemeal:fertiliser"},
      {"bonemeal:fertiliser", stone_ingrediant, "bonemeal:fertiliser"},
      {"bonemeal:fertiliser", glass_ingredient, "bonemeal:fertiliser"},
    }
  })
end
