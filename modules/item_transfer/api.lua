-- item_transfer/api.lua
local me = microexpansion
local item_transfer = {}
me.item_transfer = item_transfer

function item_transfer.get_output_inventory(pos,metadata,inventory)
  local meta = metadata or minetest.get_meta(pos)
  local inv = inventory or meta:get_inventory()
  local lists = inv:get_lists()
	if not lists then
		return
	elseif lists["dst"] then
		return "dst", inv
	elseif lists["main"] then
		return "main", inv
	end
end

function item_transfer.get_input_inventory(pos,metadata,inventory)
  local meta = metadata or minetest.get_meta(pos)
  local inv = inventory or meta:get_inventory()
  local lists = inv:get_lists()
  if not lists then
		return
	elseif lists["src"] then
		return "src", inv
	elseif lists["main"] then
		return "main", inv
	end
end

function microexpansion.vector_cross(a, b)
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x
	}
end

function microexpansion.facedir_to_top_dir(facedir)
	return 	({[0] = {x =  0, y =  1, z =  0},
	                {x =  0, y =  0, z =  1},
	                {x =  0, y =  0, z = -1},
	                {x =  1, y =  0, z =  0},
	                {x = -1, y =  0, z =  0},
	                {x =  0, y = -1, z =  0}})
		[math.floor(facedir / 4)]
end

function microexpansion.facedir_to_right_dir(facedir)
	return microexpansion.vector_cross(
		microexpansion.facedir_to_top_dir(facedir),
		minetest.facedir_to_dir(facedir)
	)
end

function microexpansion.count_upgrades(inv)
	local upgrades = {}
	for i = 0, inv:get_size("upgrades") do
		local stack = inv:get_stack("upgrades", i)
		local item = stack:get_name()
		if item == "microexpansion:upgrade_filter" then
			upgrades.filter = (upgrades.filter or 0) + stack:get_count()
		elseif item == "microexpansion:upgrade_bulk" then
			upgrades.bulk = (upgrades.bulk or 0) + stack:get_count()
		end
	end
	return upgrades
end

function item_transfer.update_timer_based(pos,_,ev)
	if ev then
		if ev.type ~= "disconnect"
				and ev.type ~= "connect"
				and ev.type ~= "construct" then
			return
		end
	end
	local meta = minetest.get_meta(pos)
	if me.get_connected_network(pos) then
		meta:set_string("infotext", "Network connected")
		if not minetest.get_node_timer(pos):is_started() then
			minetest.get_node_timer(pos):start(2)
		end
	else
		meta:set_string("infotext", "No Network")
		minetest.get_node_timer(pos):stop()
	end
end

function item_transfer.setup_io_device(title, pos, metadata, inventory)
	local meta = metadata or minetest.get_meta(pos)
	local inv = inventory or meta:get_inventory()
	local formspec = [[
			formspec_version[2]
			size[11,11]
		]] ..
		microexpansion.gui_bg ..
		microexpansion.gui_slots
	if title then
		formspec = formspec .. "label[9,0.5;"..title.."]"
	end
	local upgrades = me.count_upgrades(inv)
	if upgrades.filter then
		inv:set_size("filter", math.pow(2, upgrades.filter - 1))
		formspec = formspec .. [[
			label[0.5,0.75;filter]
			list[context;filter;0.5,1;5,3]
		]]
	else
		inv:set_size("filter",0)
	end
	--TODO: target inventory dropdown
	inv:set_size("upgrades", 4)
	meta:set_string("formspec",
		formspec ..
		[[
			label[8.5,2.5;upgrades]
			list[context;upgrades;8,2.75;2,2]
			list[current_player;main;0.5,5.5;8,1;]
			list[current_player;main;0.5,7;8,3;8]
			listring[current_name;upgrades]
			listring[current_player;main]
		]])
end

local access_level = microexpansion.constants.security.access_levels
local io_device_base = {
	is_ground_content = false,
	groups = { crumbly = 1, me_connect = 1  },
	paramtype = "light",
	paramtype2 = "facedir",
	me_update = item_transfer.update_timer_based,
	after_place_node = function(pos, placer)
		if not placer then
			return false
		end
		local name = placer:get_player_name()
		local net,cp = me.get_connected_network(pos)
		if net then
			if net:get_access_level(name) < access_level.modify then
				-- prevent placing exporters on a network that a player doesn't have access to
				--Do we need to send a disconnect or stop any node timers?
				minetest.remove_node(pos)
				return true
			else
				return false
			end
		elseif minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			--protection probably handles this itself
			--minetest.remove_node(pos)
			return true
		end
	end,
	can_dig = function(pos, player)
		if not player then
			return false
		end
		local name = player:get_player_name()
		local net,cp = me.get_connected_network(pos)
		if net then
			if net:get_access_level(name) < access_level.modify then
				return false
			end
		elseif minetest.is_protected(pos, name) then
				minetest.record_protection_violation(pos, name)
				return false
		end
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:is_empty("upgrades")
	end,
	allow_metadata_inventory_put = function(pos, listname, _, stack, player)
		local max_allowed = stack:get_count()
		if listname == "upgrades" then
			local item = stack:get_name()
			if item == "microexpansion:upgrade_filter" then
				local filter_upgrades = me.count_upgrades(minetest.get_meta(pos):get_inventory()).filter
				if filter_upgrades then
					max_allowed = math.max(0, math.min(stack:get_count(), 5 - filter_upgrades))
				else
					max_allowed = math.min(stack:get_count(), 5)
				end
			elseif item == "microexpansion:upgrade_bulk" then
				local bulk_upgrades = me.count_upgrades(minetest.get_meta(pos):get_inventory()).bulk
				if bulk_upgrades then
					max_allowed = math.max(0, math.min(stack:get_count(), 10 - bulk_upgrades))
				else
					max_allowed = math.min(stack:get_count(), 10)
				end
			else
				return 0
			end
		end
		if not player then
			return max_allowed
		end
		local name = player:get_player_name()
		local net,cp = me.get_connected_network(pos)
		if net then
			if net:get_access_level(name) < access_level.modify then
				return 0
			end
		elseif minetest.is_protected(pos, name) then
			--minetest.record_protection_violation(pos, name)
			return 0
		end
		if listname == "filter" then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local filter = stack:peek_item()
			if inv:room_for_item(listname,filter) and not inv:contains_item(listname, filter) then
				inv:add_item(listname, filter)
			end
			return 0
		else
			return max_allowed
		end
	end,
	allow_metadata_inventory_take = function(pos, listname, _, stack, player)
		if not player then
			return 0
		end
		local name = player:get_player_name()
		local net,cp = me.get_connected_network(pos)
		if net then
			if net:get_access_level(name) < access_level.modify then
				return 0
			end
		elseif minetest.is_protected(pos, name) then
			--minetest.record_protection_violation(pos, name)
			return 0
		end
		if listname == "filter" then
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:remove_item(listname, stack)
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_move = function(pos, from_list, _, to_list, _, count, player)
		--perhaps allow filtering for upgrades and removing filters in this way
		if from_list ~= to_list then
			return 0
		end
		return count
	end,
}

function item_transfer.register_io_device(itemstring, def)
	for k,v in pairs(io_device_base) do
		if def[k] == nil then
			def[k] = v
		end
	end
	if not def.groups.me_connect then
		def.groups.me_connect = 1 
	end
	microexpansion.register_node(itemstring, def)
end
