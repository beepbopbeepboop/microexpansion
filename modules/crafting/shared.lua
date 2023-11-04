-- crafting/shared.lua

local me = microexpansion

-- custom items that are used by multiple devices

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
