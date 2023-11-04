---
-- Craft materials, that are normally registered by basic_materials

local me = microexpansion
local substitute_basic_materials = microexpansion.settings.simple_craft == true or not minetest.get_modpath("basic_materials")


-- [register item] Gold Wire
me.register_item("gold_wire", {
	description = "Gold Wire",
	groups = { wire = 1 },
	recipe = substitute_basic_materials and {
		{ 2, {
				{"default:gold_ingot", "default:stick"},
				{"default:stick", ""}
			},
		},
	} or nil,
})
