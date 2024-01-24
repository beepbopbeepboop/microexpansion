---
-- Craft materials, that are normally registered by basic_materials

local me = microexpansion
local substitute_basic_materials = microexpansion.settings.simple_craft == true or not minetest.get_modpath("basic_materials")
local gold_wire_recipe

if minetest.get_modpath("mcl_core") then
  gold_wire_recipe = {
    { 2, {
        {"mcl_core:gold_ingot", "mcl_core:stick"},
        {"mcl_core:stick", ""}
      },
    },
  }
else
  gold_wire_recipe = {
    { 2, {
        {"default:gold_ingot", "default:stick"},
        {"default:stick", ""}
      },
    },
  }

end

-- [register item] Gold Wire
me.register_item("gold_wire", {
  description = "Gold Wire",
  groups = { wire = 1 },
  recipe = substitute_basic_materials and gold_wire_recipe or nil,
})
