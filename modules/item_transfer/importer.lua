-- microexpansion/machines.lua

local me = microexpansion
local item_transfer = me.item_transfer
local access_level = microexpansion.constants.security.access_levels

function importer_timer(pos, elapsed)
	local net, cp = me.get_connected_network(pos)
	if not net then
		return false
	end
	local node = minetest.get_node(pos)
	local target = vector.add(pos, microexpansion.facedir_to_right_dir(node.param2))
	--TODO: allow setting list with upgrade
	local list, inv = item_transfer.get_output_inventory(target)
	if list then
		local own_inv = minetest.get_meta(pos):get_inventory()
		local upgrades = me.count_upgrades(own_inv)
		local count = math.min(net:get_inventory_space(),math.pow(2, upgrades.bulk or 0))
		if count <= 0 then
			return true
		end
		local import_filter = function(stack)
			local stack_name = stack:get_name()
		  if minetest.get_item_group(stack_name, "microexpansion_cell") > 0 then
  		  return true
  		end
			if upgrades.filter then
				return not own_inv:contains_item("filter",stack:peek_item())
			end
			return false
		end
		microexpansion.move_inv({inv=inv,name=list}, {inv=net:get_inventory(),name="main",huge=true}, count, import_filter)
		net:set_storage_space(true)
	end
	return true
end

-- [MicroExpansion Importer] Register node
item_transfer.register_io_device("importer", {
	description = "ME Importer",
	usedfor = "Imports items from machines into ME Networks",
	tiles = {
		"importer",
		"importer",
		"interface",
		"cable",
		"microexpansion_importer.png^[transform4",
		"importer",
	},
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.25, -0.25, 0.25,  0.25, 0.25},
			{0.25, -0.375, -0.375, 0.5,  0.375, 0.375},
		},
	},
	connect_sides = { "left" },
	recipe = {
		{ 1, {
        {"", "basic_materials:ic", microexpansion.iron_ingot_ingredient },
        {"", "microexpansion:cable", "group:hoe" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    },
    { 1, {
        {"", "microexpansion:logic_chip", microexpansion.iron_ingot_ingredient },
        {"", "microexpansion:cable", "group:hoe" },
        {"", "", microexpansion.iron_ingot_ingredient },
      },
    }
  },
	is_ground_content = false,
	groups = { crumbly = 1 },
	on_timer = importer_timer,
	on_construct = function(pos)
		item_transfer.setup_io_device("ME Importer",pos)
		me.send_event(pos,"connect")
		item_transfer.update_timer_based(pos)
	end,
	after_destruct = function(pos)
		minetest.get_node_timer(pos):stop()
		me.send_event(pos,"disconnect")
  end,
	on_metadata_inventory_put = function(pos, listname, _, stack, player)
		if listname == "upgrades" then
			item_transfer.setup_io_device("ME Importer",pos)
		end
	end,
	on_metadata_inventory_take = function(pos, listname, _, stack, player)
		if listname == "upgrades" then
			item_transfer.setup_io_device("ME Importer",pos)
		end
	end
})

if me.uinv_category_enabled then
	unified_inventory.add_category_item("storage", "microexpansion:importer")
end
