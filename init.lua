-- microexpansion/init.lua
microexpansion           = {}
microexpansion.data      = {}
microexpansion.modpath   = minetest.get_modpath("microexpansion") -- Get modpath
microexpansion.worldpath = minetest.get_worldpath()               -- Get worldpath

local modpath   = microexpansion.modpath   -- Modpath pointer

-- Formspec GUI related stuff
microexpansion.gui_bg = "bgcolor[#080808BB;true]background[5,5;1,1;gui_formbg.png;true]"
microexpansion.gui_slots = "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"

microexpansion.settings = {
	huge_stacks = minetest.settings:get_bool("microexpansion_huge_stacks"),
	simple_craft = minetest.settings:get_bool("microexpansion_simple_craft")
}

microexpansion.uinv_category_enabled = minetest.global_exists("unified_inventory") and unified_inventory.add_category_item and true or false

-- logger
function microexpansion.log(content, log_type)
	assert(content, "microexpansion.log: missing content")
	if not content then return false end
	if log_type == nil then log_type = "action" end
	minetest.log(log_type, "[MicroExpansion] "..content)
end

-- Load API
dofile(modpath.."/api.lua")
-- Machine Registration
dofile(modpath.."/register.lua")

-------------------
----- MODULES -----
-------------------

local loaded_modules = {}

local settings = Settings(modpath.."/modules.conf"):to_table()

-- [function] Get module path
function microexpansion.get_module_path(name)
	local module_path = modpath.."/modules/"..name

  local handle = io.open(module_path.."/init.lua")
	if handle then
	  io.close(handle)
		return module_path
	end
end

-- [function] Load module (overrides modules.conf)
function microexpansion.load_module(name)
	if not loaded_modules[name] then
		local module_path = microexpansion.get_module_path(name)

		if module_path then
			dofile(module_path.."/init.lua")
			loaded_modules[name] = true
			return true
		else
			microexpansion.log("Invalid module \""..name.."\". The module either does not exist "..
				"or is missing an init.lua file.", "error")
		end
	else
		return true
	end
end

-- [function] Require module (does not override modules.conf)
function microexpansion.require_module(name)
	if settings[name] then
		microexpansion.log("loading module " .. name)
		return microexpansion.load_module(name)
	else
		microexpansion.log("not loading module " .. name)
	end
end

for name,enabled in pairs(settings) do
	if enabled ~= false then
		microexpansion.load_module(name)
	end
end
