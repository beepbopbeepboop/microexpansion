-- ores/init.lua

local me = microexpansion

-- [register] Incranium Ore
me.register_node("incranium", {
	description = "Incranium Ore",
	tiles = { "incranium" },
	is_ground_content = true,
	groups = { cracky=3, stone=1 },
	type = "ore",
	oredef = {
		{
			ore_type = "blob",
			wherein = "default:stone",
			clust_scarcity = 4*4*4,
			clust_num_ores = 4,
			clust_size = 3,
			y_min = -300,
			y_max = -90,
		},
	},
	disabled = true,
})

me.register_item("quartz_crystal", {
	description = "Quartz Crystal",
})


me.register_node("quartz", {
	description = "Quartz Ore",
	tiles = { "default_stone.png^microexpansion_ore_quartz.png" },
	is_ground_content = true,
	type = "ore",
	groups = { cracky=3, stone=1 },
	drop = "microexpansion:quartz_crystal",
	oredef = {{
		ore_type = "scatter",
		wherein = "default:stone",
		clust_scarcity = 10*10*10,
		clust_num_ores = 6,
		clust_size = 5,
		y_min = -31000,
		y_max = -5,
	}}
})
