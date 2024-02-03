-- quantum/init.lua

local module_path = microexpansion.get_module_path("quantum")

microexpansion.require_module("network")


-- Iron Ingot Ingredient for MineClone2
microexpansion.iron_ingot_ingredient = nil
if minetest.get_modpath("mcl_core") then
  microexpansion.iron_ingot_ingredient = "mcl_core:iron_ingot"
else
  microexpansion.iron_ingot_ingredient = "default:steel_ingot"
end

-- Load Quantum bits
dofile(module_path.."/matter_condenser.lua")
dofile(module_path.."/quantum_link.lua")
dofile(module_path.."/quantum_ring.lua")
