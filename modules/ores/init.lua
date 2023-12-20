-- ores/init.lua

local me = microexpansion
local mcl_core_modpath = minetest.get_modpath("mcl_core")
stone_ingrediant = mcl_core_modpath and "mcl_core:stone" or "default:stone"


local incranium_y_min = -300
local incranium_y_max = -90

local quartz_y_min = -31000
local quartz_y_max = -5

if mcl_core_modpath then
	incranium_y_min = -55
	incranium_y_max = -20
	quartz_y_min = -50
	quartz_y_max = 0
end

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
			wherein = stone_ingrediant,
			clust_scarcity = 4*4*4,
			clust_num_ores = 4,
			clust_size = 3,
			y_min = incranium_y_min,
			y_max = incranium_y_max,
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
		wherein = stone_ingrediant,
		clust_scarcity = 10*10*10,
		clust_num_ores = 6,
		clust_size = 5,
		y_min = quartz_y_min,
		y_max = quartz_y_max,
	}}
})
