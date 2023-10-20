-- shared/init.lua

local me = microexpansion

-- This mostly contains items that are used by multiple modules and
-- don't really fit with anything else.

-- [register item] Steel Infused Obsidian Ingot
me.register_item("steel_infused_obsidian_ingot", {
	description = "Steel Infused Obsidian Ingot",
	recipe = {
		{ 2, {
				{ "default:steel_ingot", "default:obsidian_shard", "default:steel_ingot" },
			},
		},
	},
})

-- [register item] Machine Casing
me.register_item("machine_casing", {
	description = "Machine Casing",
	recipe = {
		{ 1, {
				{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
				{"default:steel_ingot", "default:copper_ingot", "default:steel_ingot"},
				{"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
			},
		},
	},
})

-- [register item] Gold Wire
me.register_item("gold_wire", {
	description = "Gold Wire",
	recipe = {
		{ 2, {
				{"default:gold_ingot", "default:stick"},
				{"default:stick", ""}
			},
		},
	},
})

-- [register item] Control Unit
me.register_item("logic_chip", {
	description = "Control Unit",
	recipe = {
		{ 2, {
				{"microexpansion:gold_wire"},
				{"microexpansion:quartz_crystal"},
				{"group:wood"}
			},
		},
	},
})
