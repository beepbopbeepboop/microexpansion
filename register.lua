-- register.lua

--[[ Machine Registration API ]]

local me = microexpansion
local power = me.power

if me.uinv_category_enabled and unified_inventory.registered_categories then
	if not unified_inventory.registered_categories["storage"] then
		unified_inventory.register_category("storage", {
			symbol = "default:chest",
			label = "Storage"
		})
	end
end

-- [function] Register machine
function me.register_machine(itemstring, def)
	-- Set after_place_node
	local def_afterplace = def.after_place_node
	def.after_place_node = function(pos, player)
		if def_afterplace then
			def_afterplace(pos, player)
		end

		local meta  = minetest.get_meta(pos)
		local nodes = me.network.adjacent_connected_nodes(pos)

		meta:set_string("infotext", def.description.."\nNo Network")

		for _, pos2 in pairs(nodes) do
			local id = minetest.get_meta(pos2):get_string("network_id")

			if id ~= "" then
				meta:set_string("infotext", def.description.."\nNetwork ID: "..id)
				meta:set_string("network_id", id)
			end
		end

		-- Trace Network
		--power.trace(pos)

		-- Set demand
		if def.demand then
			me.network_set_demand(pos, def.demand)
		end

		if type(def.machine) == "table" then
			if power then
				power.add_machine(pos, def.machine)
			end
		end
	end
	-- Set on_destruct
	local def_destruct = def.on_destruct
	def.on_destruct = function(pos, player)
		if def_destruct then
			def_destruct(pos, player)
		end

		local meta = minetest.get_meta(pos)

		if meta:get_string("network_id") ~= "" then
			-- Set demand
			me.network_set_demand(pos, 0)
			-- Remove item from network
			me.network_remove(pos)
			-- Retrace Network
			--power.trace(pos)
		end
	end
	-- Set connects_to
	def.connects_to = {"group:me_connect"}
	-- Set me_connect group
	def.groups = def.groups or {}
	def.groups.me_connect = 1

	me.register_node(itemstring, def)
end

-- [function] Get machine definition
function me.get_def(name, key)
	if type(name) == "table" then
		local node = me.get_node(name)
		if node then
			name = node.name
		end
	end

	local def = minetest.registered_nodes[name]
	-- Check name and if registered
	if not name or not def then
		return
	end

	if key then
		return def[key]
	else
		return def
	end
end

microexpansion.log("Machine Registration API loaded")
