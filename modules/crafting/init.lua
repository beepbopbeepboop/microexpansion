local module_path = microexpansion.get_module_path("crafting")

-- basic_materials replacements
dofile(module_path.."/materials.lua")
-- shared items used for various machine recipes
dofile(module_path.."/shared.lua")
-- items that allow for alternative recipes
dofile(module_path.."/alternatives.lua")
