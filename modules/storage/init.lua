-- storage/init.lua

local module_path = microexpansion.get_module_path("storage")

microexpansion.require_module("network")

-- Load API
dofile(module_path.."/api.lua")

-- Load storage devices
dofile(module_path.."/storage.lua")

-- Load machines
dofile(module_path.."/drive.lua")
dofile(module_path.."/terminal.lua")
dofile(module_path.."/cterminal.lua")
dofile(module_path.."/cmonitor.lua")
dofile(module_path.."/interface.lua")
dofile(module_path.."/remote.lua")

local drawers_enabled = minetest.get_modpath("drawers") and true or false
if drawers_enabled then
  dofile(module_path.."/drawer-api.lua") -- Extra Drawer api
  dofile(module_path.."/drawer-interop.lua")
end
local technic_enabled = minetest.get_modpath("technic") and true or false
if technic_enabled then
  dofile(module_path.."/technic-interop.lua")
end
local pipeworks_enabled = minetest.get_modpath("pipeworks") and true or false
if pipeworks_enabled then
  dofile(module_path.."/pipeworks-interop.lua")
end
