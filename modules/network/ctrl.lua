-- power/ctrl.lua

local me = microexpansion
local network = me.network
local access_level = microexpansion.constants.security.access_levels

-- [register node] Controller
me.register_node("ctrl", {
	description = "ME Controller",
	tiles = {
		"ctrl_sides",
		"ctrl_bottom",
		"ctrl_sides",
		"ctrl_sides",
		"ctrl_sides",
		"ctrl_sides"
	},
	recipe = {
    { 1, {
        {"default:steel_ingot", "microexpansion:steel_infused_obsidian_ingot", "default:steel_ingot"},
        {"default:steel_ingot",       "microexpansion:machine_casing",         "default:steel_ingot"},
        {"default:steel_ingot",             "microexpansion:cable",            "default:steel_ingot"},
      },
    }
  },
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-0.375, -0.375, -0.375, 0.375, 0.375, 0.375}, -- Core
			{0.1875, -0.5, -0.5, 0.5, 0.5, -0.1875}, -- Corner1
			{-0.5, -0.5, -0.5, -0.1875, 0.5, -0.1875}, -- Corner2
			{-0.5, -0.5, 0.1875, -0.1875, 0.5, 0.5}, -- Corner3
			{0.1875, -0.5, 0.1875, 0.5, 0.5, 0.5}, -- Corner4
			{-0.5, -0.4375, -0.5, 0.5, -0.1875, 0.5}, -- Bottom
			{-0.5, 0.1875, -0.5, 0.5, 0.5, -0.1875}, -- Top1
			{0.1875, 0.1875, -0.5, 0.5, 0.5, 0.5}, -- Top2
			{-0.5, 0.1875, -0.5, -0.1875, 0.5, 0.5}, -- Top3
			{-0.5, 0.1875, 0.1875, 0.5, 0.5, 0.5}, -- Top4
			{-0.1875, -0.5, -0.1875, 0.1875, -0.25, 0.1875}, -- Bottom2
		},
	},
	groups = { cracky = 1, me_connect = 1, },
	connect_sides = "nobottom",
	me_update = function(pos,_,ev)
		local meta = minetest.get_meta(pos)
		if meta:get_string("source") ~= "" then
			return
		end
    local cnet = me.get_network(pos)
    if cnet == nil then
      microexpansion.log("no network for ctrl at pos "..minetest.pos_to_string(pos),"error")
      return
    end
    cnet:update()
  end,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
		local net,cp = me.get_connected_network(pos)
		if net then
			meta:set_string("source", vector.to_string(cp))
		else
  	  net = network.new({controller_pos = pos})
  	  table.insert(me.networks,net)
		end
	  me.send_event(pos,"connect",{net=net})
    meta:set_string("infotext", "Network Controller")
  end,
	after_place_node = function(pos, player)
		local name = player:get_player_name()
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Network Controller")
		meta:set_string("owner", name)
		local net,idx = me.get_network(pos)
		if net then
      net:set_access_level(name, me.constants.security.access_levels.full)
		elseif meta:get_string("source") == "" then
			me.log("no network after placing controller", "warning")
    end
	end,
	can_dig = function(pos, player)
		if not player then
			return false
		end
		local name = player:get_player_name()
		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			return false
		end
		local meta = minetest.get_meta(pos)
		local net
		if meta:get_string("source") == "" then
			net = me.get_network(pos)
		else
			net = me.get_connected_network(pos)
		end
		if not net then
			me.log("ME Network Controller without Network","error")
			return true
		end
		return net:get_access_level(name) >= access_level.full
	end,
	on_destruct = function(pos)
    local net,idx = me.get_network(pos)
    --disconnect all those who need the network
    me.send_event(pos,"disconnect",{net=net})
    if net then
			if me.promote_controller(pos,net) then
				--reconnect with new controller
				me.send_event(pos,"reconnect",{net=net})
			else
	      net:destruct()
		    if idx then
		      table.remove(me.networks,idx)
  			end
		    --disconnect all those that haven't realized the network is gone
		    me.send_event(pos,"disconnect")
			end
		else
			-- disconnect just in case
			me.send_event(pos,"disconnect")
    end
	end,
	after_destruct = function(pos)
    --disconnect all those that haven't realized the controller was disconnected
    me.send_event(pos,"disconnect")
	end,
	machine = {
		type = "controller",
	},
})

minetest.register_lbm({
	name = "microexpansion:update_network",
	label = "integrate new ME Network data",
	nodenames = {"microexpansion:ctrl"},
	run_at_every_load = true,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		local net,idx = me.get_network(pos)
		if not meta then
			me.log("activated controller before metadata was available", "warning")
			return
		end
		local source = meta:get_string("source")
		if not net then
			if source == "" then
				me.log("activated controller without network", "warning")
				return
			else
				net = me.get_network(vector.from_string(source))
				if not net then
					me.log("activated controller that is linked to an unloaded controller", "info")
					return
				end
  	  end
		end
		if not net.access then
			me.log("added access table to old network", "action")
			net.access = {}
		end
		net:fallback_access()
	end
})

-- [register node] Cable
me.register_machine("cable", {
	description = "ME Cable",
	tiles = {
		"cable",
	},
	recipe = {
    { 12, "shapeless", {
        "microexpansion:steel_infused_obsidian_ingot", "microexpansion:machine_casing"
      },
    }
  },
	drawtype = "nodebox",
	node_box = {
		type = "connected",
		fixed          = {-0.25, -0.25, -0.25, 0.25,  0.25, 0.25},
		connect_top    = {-0.25, -0.25, -0.25, 0.25,  0.5,  0.25}, -- y+
		connect_bottom = {-0.25, -0.5,  -0.25, 0.25,  0.25, 0.25}, -- y-
		connect_front  = {-0.25, -0.25, -0.5,  0.25,  0.25, 0.25}, -- z-
		connect_back   = {-0.25, -0.25,  0.25, 0.25,  0.25, 0.5 }, -- z+
		connect_left   = {-0.5,  -0.25, -0.25, 0.25,  0.25, 0.25}, -- x-
		connect_right  = {-0.25, -0.25, -0.25, 0.5,   0.25, 0.25}, -- x+
	},
	paramtype = "light",
	groups = { crumbly = 1, },
	--TODO: move these functions into the registration
	can_dig = function(pos, player)
		if not player then
			return false
		end
		local name = player:get_player_name()
		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			return false
		end
		local net,cp = me.get_connected_network(pos)
		if not net then
			return true
		end
		return net:get_access_level(name) >= access_level.modify
	end,
	on_construct = function(pos)
		--perhaps this needs to be done after the check if it can be placed
	 me.send_event(pos,"connect")
	end,
	after_place_node = function(pos, placer)
		if not placer then
			return false
		end
		local name = placer:get_player_name()
		if minetest.is_protected(pos, name) then
			minetest.record_protection_violation(pos, name)
			--protection probably handles this itself
			--minetest.remove_node(pos)
			return true
		end
		--TODO: prevent connecting multiple networks
		local net,cp = me.get_connected_network(pos)
		if not net then
			return false
		end
		if net:get_access_level(name) < access_level.modify then
			-- prevent placing cables on a network that a player doesn't have access to
			minetest.remove_node(pos)
			return true
		end
	end,
	after_destruct = function(pos)
		--FIXME: write drives before disconnecting
		me.send_event(pos,"disconnect")
	end,
	me_update = function(pos,_,ev)
	 if ev then
	   if ev.type ~= "disconnect" then return end
	 end
	 --maybe this shouldn't be called on every update
	 local meta = minetest.get_meta(pos)
	 if me.get_connected_network(pos) then
    meta:set_string("infotext", "Network connected")
   else
    meta:set_string("infotext", "No Network")
	 end
	end,
	machine = {
		type = "conductor",
	},
})
