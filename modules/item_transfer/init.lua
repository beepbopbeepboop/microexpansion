-- storage/init.lua

local module_path = microexpansion.get_module_path("item_transfer")

microexpansion.require_module("network")


-- Iron Ingot Ingredient for MineClone2
microexpansion.iron_ingot_ingredient = nil
if minetest.get_modpath("mcl_core") then
	microexpansion.iron_ingot_ingredient = "mcl_core:iron_ingot"
else
	microexpansion.iron_ingot_ingredient = "default:steel_ingot"
end

-- Load API
dofile(module_path.."/api.lua")

-- Load upgrade cards
dofile(module_path.."/upgrades.lua")

-- Load ports
dofile(module_path.."/importer.lua")
dofile(module_path.."/exporter.lua")
--dofile(module_path.."/interface.lua")
