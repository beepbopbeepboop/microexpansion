-- shared/init.lua

local me = microexpansion

-- TODO: regulation upgrade (1: disable in formspec, mesecon control; 2: requests from the me network and perhaps digiline)

-- [register item] Upgrade Base
me.register_item("upgrade_base", {
	description = "Upgrade Base",
	usedfor = "the base for crafting upgrades",
	recipe = {
		{ 1, {
				{ "microexpansion:quartz_crystal" },
				{ iron_ingot_ingredient },
			},
		},
	},
})

-- [register item] Bulk Upgrade
me.register_item("upgrade_bulk", {
	description = "Bulk Upgrade",
	usedfor = "upgrades components to process more at the same time",
	recipe = {
		{ 1, {
				{"basic_materials:gold_wire"},
				{"microexpansion:upgrade_base"}
			},
		},
		{ 1, {
				{"microexpansion:gold_wire"},
				{"microexpansion:upgrade_base"}
			},
		},
	},
})

-- [register item] Filter Upgrade
me.register_item("upgrade_filter", {
	description = "Filter Upgrade",
	usedfor = "allows setting up filters for components",
	recipe = {
		{ 1, {
				{"microexpansion:quartz_crystal"},
				{"microexpansion:upgrade_base"}
			},
		},
	},
})

-- [register item] Control Upgrade
me.register_item("upgrade_control", {
	description = "Control Upgrade",
	usedfor = "allows more fine tuned control over components",
	recipe = {
		{ 1, {
				{"basic_materials:ic"},
				{"microexpansion:upgrade_base"}
			},
		},
		{ 1, {
				{"microexpansion:logic_chip"},
				{"microexpansion:upgrade_base"}
			},
		},
	},
})
