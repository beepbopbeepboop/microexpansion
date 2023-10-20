-- storage/init.lua

local module_path = microexpansion.get_module_path("item_transfer")

microexpansion.require_module("network")

-- Load API
dofile(module_path.."/api.lua")

-- Load upgrade cards
dofile(module_path.."/upgrades.lua")

-- Load ports
dofile(module_path.."/importer.lua")
dofile(module_path.."/exporter.lua")
--dofile(module_path.."/interface.lua")
