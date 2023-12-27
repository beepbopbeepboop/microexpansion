-- crafting/shared.lua

local me = microexpansion

-- custom items that are used by multiple devices

local steel_infused_obsidian_ingot_recipe = nil
local machine_casing_recipe = nil

if minetest.get_modpath("mcl_core") then
  steel_infused_obsidian_ingot_recipe = {
    { 2, {
        { "mcl_core:iron_ingot", "mcl_core:obsidian", "mcl_core:iron_ingot" },
      },
    },
  }
  
  machine_casing_recipe = {
    { 1, {
        {"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"},
        {"mcl_core:iron_ingot", "mcl_copper:copper_ingot", "mcl_core:iron_ingot"},
        {"mcl_core:iron_ingot", "mcl_core:iron_ingot", "mcl_core:iron_ingot"},
      },
    },
  }
  
else
  steel_infused_obsidian_ingot_recipe = {
    { 2, {
        { "default:steel_ingot", "default:obsidian_shard", "default:steel_ingot" },
      },
    },
  }

  machine_casing_recipe = {
    { 1, {
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:copper_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
      },
    },
  }
  
end
-- [register item] Steel Infused Obsidian Ingot
me.register_item("steel_infused_obsidian_ingot", {
  description = "Steel Infused Obsidian Ingot",
  recipe = steel_infused_obsidian_ingot_recipe,
})

-- [register item] Machine Casing
me.register_item("machine_casing", {
  description = "Machine Casing",
  recipe = machine_casing_recipe,
})
