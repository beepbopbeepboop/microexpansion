-- microexpansion/network/security.lua

local me = microexpansion
local access_level = me.constants.security.access_levels
local access_desc = me.constants.security.access_level_descriptions

-- [me security] Get formspec
local function security_formspec(pos, player, rule, q)
	local list
	local buttons
	local logout = true
	local query = q or ""
	local net,cp = me.get_connected_network(pos)
	if player and cp then
		local access = net:get_access_level(player)
		if access < access_level.manage then -- Blocked dialog
			logout = false
			list = "label[2.5,3;"..minetest.colorize("red", "Access Denied").."]"
			buttons = "button[3.5,6;2,1;logout;back]"
		elseif (not rule) or rule == "" then -- Main Screen
			--TODO: show button or entry for default access level
			list = "tablecolumns[color,span=1;text;color,span=1;text]"
			    .. "table[0.5,2;6,7;access_table;"
			local first = true
			--TODO: filter
			local name_list = {}
			for p,l in pairs(net:list_access()) do
				if first then
					first = false
				else
					list = list .. ","
				end
				table.insert(name_list, p)
				local desc = access_desc[l] or {name = "Unknown", color = "red"}
				list = list .. "cyan," .. p .. "," .. desc.color .. "," .. desc.name
			end
			list = list .. ";]"
			minetest.get_meta(pos):set_string("table_index", minetest.serialize(name_list))

			list = list .. [[
				field[0.5,1;2,0.5;filter;;]]..query..[[]
				button[3,1;0.8,0.5;search;?]
				button[4,1;0.8,0.5;clear;X]
				tooltip[search;Search]
				tooltip[clear;Reset]
				field_close_on_enter[filter;false]
			]]
			buttons = [[
				button[7,7;1.5,0.8;new;new rule]
				button[7,8;1.5,0.8;edit_sel;edit rule]
			]]
			--button[7,6;1.5,0.8;del_sel;delete rule]
		elseif rule == "<new>" then -- Creation screen
			logout = false
			local players = ""
			for _,p in pairs(minetest.get_connected_players()) do
				if players ~= "" then
					players = players .. ","
				end
				players = players .. p:get_player_name()
			end
			--TODO: add a text field (maybe toggelable)
			list = [[
				dropdown[3,2.75;5,0.5;new_player;]]..players..[[;]
				label[1.5,3;rule for:]
			]]
			buttons = [[
				button[2,6;2,0.8;edit;add/edit]
				button[5,6;2,0.8;back;cancel]
			]]
		elseif (access < access_level.full and net:get_access_level(rule) >= access_level.manage) or (player ~= rule and access >= access_level.full and net:get_access_level(rule) >= access_level.full) then
			-- low access dialog
			list = "label[1,3;"..minetest.colorize("red", "You can only modify rules with lower access than yourself.").."]"
			buttons = "button[3.5,6;2,1;back;back]"
		else
			local rule_level = net:get_access_level(rule)
			local current = rule_level == access_level.blocked and  "1" or 
			                rule_level == access_level.view and     "2" or
			                rule_level == access_level.interact and "3" or
			                rule_level == access_level.modify and   "4" or
			                rule_level == access_level.manage and   "5" or
			                rule_level == access_level.full and     "6" or ""
			list = [[
				label[1,3;rule for:]].."\t"..minetest.colorize("cyan", rule)..[[]
				label[1,4;access level:]
				dropdown[3,3.75;2,0.5;access;Blocked,View,Interact,Modify,Manage,Full;]]..current..[[]
			]]
			buttons = [[
				button[1,6;1,0.8;save;save]
				button[3,6;2,0.8;reset;reset to default]
				button[6,6;1,0.8;back;cancel]
			]]
		end
	elseif cp then
		logout = false
		list = "label[2.5,3;Welcome to the security Terminal!]"
		buttons = [[
			button[3.5,6;2,1;login;login]
			button_exit[8,0.5;0.5,0.5;close;x]
		]]
	else
		logout = false
		list = "label[2.5,3;" .. minetest.colorize("red", "No connected network!") .. "]"
		buttons = "button_exit[3,6;2,1;close;close]"
	end

	return [[
		formspec_version[2]
		size[9,9.5]
	]]..
		microexpansion.gui_bg ..
		list ..
		(logout and "button[7.5,0.5;1,0.5;logout;logout]" or "") ..
		"label[0.5,0.5;ME Security Terminal]" ..
		buttons
end

local function update_security(pos,_,ev)
  --for now all events matter
  
	local network = me.get_connected_network(pos)
	local meta = minetest.get_meta(pos)
	if network == nil then
		meta:set_string("editing_rule", "")
		meta:set_string("formspec", security_formspec(pos))
	end
	meta:set_string("formspec", security_formspec(pos))
end

-- [me chest] Register node
microexpansion.register_node("security", {
	description = "ME Security Terminal",
	usedfor = "Allows controlling access to ME networks",
	tiles = {
		"security_bottom",
		"security_bottom",
		"chest_side",
		"chest_side",
		"chest_side",
		"security_front",
	},
	recipe = {
    { 1, {
        {"default:steel_ingot",   "default:copper_ingot",               "default:steel_ingot"},
        {"default:steel_ingot", "microexpansion:machine_casing", "default:steel_ingot"},
        {"default:steel_ingot", "microexpansion:cable",          "default:steel_ingot"},
      },
    }
  },
	is_ground_content = false,
	groups = { cracky = 1, me_connect = 1 },
	paramtype = "light",
	paramtype2 = "facedir",
	me_update = update_security,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local net = me.get_connected_network(pos)
		me.send_event(pos,"connect",{net=net})
		update_security(pos)
	end,
	after_destruct = function(pos)
   me.send_event(pos,"disconnect")
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
		local net,cp = me.get_connected_network(pos)
		if not net then
			return true
		end
		return net:get_access_level(name) >= access_level.manage
	end,
  on_receive_fields = function(pos, _, fields, sender)
		if fields.close then
			return
		end
	  local net,cp = me.get_connected_network(pos)
    if net then
      if cp then
        microexpansion.log("network and ctrl_pos","info")
      else
		   microexpansion.log("network but no ctrl_pos","warning")
			end
		else
			if cp then
			  microexpansion.log("no network but ctrl_pos","warning")
			else
			  microexpansion.log("no network and no ctrl_pos","info")
			end
		end
		local meta = minetest.get_meta(pos)
		local name = sender:get_player_name()
		if not net then
			microexpansion.log("no network connected to security terminal","warning")
			return
		end
		if fields.logout then
			meta:set_string("formspec", security_formspec(pos))
		elseif fields.login or fields.back then
			meta:set_string("formspec", security_formspec(pos, name))
		elseif fields.search or fields.key_enter_field == "filter" then
			meta:set_string("formspec", security_formspec(pos, name), false, fields.filter)
		elseif fields.clear then
			meta:set_string("formspec", security_formspec(pos, name))
		elseif fields.new then
			meta:set_string("formspec", security_formspec(pos, name, "<new>"))
		elseif fields.edit then
			local access = net:get_access_level(name)
			if not fields.new_player then
				me.log("edit button without new player field","warning")
				meta:set_string("formspec", security_formspec(pos, name))
				return
			end
			if net:get_access_level(fields.new_player) == nil then
				if access >= access_level.manage then
					net:set_access_level(fields.new_player, net:get_access_level())
				end
			end
			meta:set_string("editing_rule", fields.new_player)
			meta:set_string("formspec", security_formspec(pos, name, fields.new_player))
		elseif fields.edit_sel then
			meta:set_string("formspec", security_formspec(pos, name, meta:get_string("editing_rule")))
		elseif fields.access_table then
			local ev = minetest.explode_table_event(fields.access_table)
			local table_index = minetest.deserialize(meta:get_string("table_index"))
			local edit_player = table_index[ev.row]
			if net:get_access_level(edit_player) == nil then
				me.log("playerlist changed before editing","warning")
				meta:set_string("formspec", security_formspec(pos, name))
				return
			else
				meta:set_string("editing_rule", edit_player)
				if ev.type == "DCL" then
					meta:set_string("formspec", security_formspec(pos, name, edit_player))
				end
			end
		elseif fields.reset then
			local rule = meta:get_string("editing_rule")
			local access = net:get_access_level(name)
			local old_level = net:get_access_level(rule)
			local new_level = net.default_access_level
			if (access > old_level or name == rule) and (access > new_level or access >= access_level.full) then
				net:set_access_level(rule, nil)
				--TODO: show fail dialog if access violation
			end
			meta:set_string("formspec", security_formspec(pos, name))
		elseif fields.save then
			local rule = meta:get_string("editing_rule")
			local access = net:get_access_level(name)
			local old_level = net:get_access_level(rule)
			local new_level = fields.access == "Blocked" and access_level.blocked or
			                  fields.access == "View" and access_level.view or
			                  fields.access == "Interact" and access_level.interact or
			                  fields.access == "Modify" and access_level.modify or
			                  fields.access == "Manage" and access_level.manage or
			                  fields.access == "Full" and access_level.full
			if not new_level then
				me.log("unknown access level selection " .. fields.access, "error")
				--TODO: show fail dialog
				return
			end
			if (access > old_level or name == rule) and access > new_level then
				net:set_access_level(rule, new_level)
				--TODO: show fail dialog if access violation
			end
			meta:set_string("formspec", security_formspec(pos, name))
		end
	end,
})
