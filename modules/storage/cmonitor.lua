-- crafting monitor
-- microexpansion/cmonitor.lua

local me = microexpansion

-- [me chest] Get formspec
local function chest_formspec(pos, start_id, listname, page_max, q)
  local list
  local page_number = ""
  local buttons = ""
  local query = q or ""
  local net,cpos = me.get_connected_network(pos)

  if cpos then
    local inv = net:get_inventory()
    if listname and (inv:get_size(listname) > 0 or net:get_item_capacity() > 0) then
      local ctrlinvname = net:get_inventory_name()
      list = "list[detached:"..ctrlinvname..";"
	.. listname .. ";0,0.3;4,4;" .. (start_id - 1) .. "]"
      if minetest.get_modpath("i3") then
	list = list .. [[
	  list[current_player;main;0,8.5;9,4;]
	]]
      else
	list = list .. [[
	  list[current_player;main;0,8.5;8,1;]
	  list[current_player;main;0,9.73;8,3;8]
	]]
      end
      list = list .. [[
	listring[current_player;main]
	listring[detached:]]..ctrlinvname..[[;ac]
	listring[current_player;main]
      ]]
      local status = "The status of the crafter is: " ..
        ((net.pending and "running " .. #net.pending .. " steps\n") or "idle\n")
      status = status .. (me.ac_status or "")
      buttons = [[
	button[0.8,5.1;0.8,0.9;prev;<]
	button[2.65,5.1;0.8,0.9;next;>]
	tooltip[prev;Previous]
	tooltip[next;Next]
	field[0.29,4.6;2.2,1;filter;;]]..query..[[]
	button[2.1,4.5;0.8,0.5;search;?]
	button[2.75,4.5;1.6,0.5;refresh;Refresh]
	button[0,5.28;0.8,0.5;clear;X]
	tooltip[search;Search]
	tooltip[refresh;Refresh]
	tooltip[clear;Reset]
	textarea[4.75,0;4.65,12.5;;]] .. status .. ";]"
    else
      list = "label[3,2;" .. minetest.colorize("blue", "Crafter is idle") .. "]"
    end
  else
    list = "label[3,2;" .. minetest.colorize("red", "No connected network!") .. "]"
  end
  if page_max then
    page_number = "label[1.55,5.25;" .. math.floor((start_id / 16)) + 1 ..
      "/" .. page_max .."]"
  end

  return [[
    size[9,12.5]
  ]]..
    microexpansion.gui_bg ..
    microexpansion.gui_slots ..
    list ..
  [[
    label[0,-0.23;ME Crafting Monitor]
    field_close_on_enter[filter;false]
  ]]..
    page_number ..
    buttons
end

local function update_chest(pos,_,ev)
  --for now all events matter

  local net = me.get_connected_network(pos)
  local meta = minetest.get_meta(pos)
  if net == nil then
    meta:set_int("page", 1)
    meta:set_string("formspec", chest_formspec(pos, 1))
    return
  end
  local inv = net:get_inventory()
  local page_max = math.floor(inv:get_size("ac") / 16) + 1

  meta:set_string("inv_name", "ac")
  meta:set_string("formspec", chest_formspec(pos, 1, "ac", page_max))
end

-- [me cmonitor] Register node
me.register_node("cmonitor", {
  description = "ME Crafting Monitor",
  usedfor = "Monitors crafting in ME networks",
  tiles = {
    "chest_top",
    "chest_top",
    "chest_side",
    "chest_side",
    "chest_side",
    "chest_front",
  },
  recipe = {
    { 1, {
	{"microexpansion:cterminal",   "default:chest"},
      },
    }
  },
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update_chest,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("formspec", chest_formspec(pos, 1))
    meta:set_string("inv_name", "none")
    meta:set_int("page", 1)

    local own_inv = meta:get_inventory()

    local net = me.get_connected_network(pos)
    me.send_event(pos,"connect",{net=net})
    if net then
      update_chest(pos)
    end
  end,
  after_destruct = function(pos)
    me.send_event(pos,"disconnect")
  end,
  can_dig = function(pos, player)
    return true
  end,
  allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    me.log("Allow a move from "..from_list.." to "..to_list, "error")
    local meta = minetest.get_meta(pos)
    if to_list == "search" then
      local net = me.get_connected_network(pos)
      local linv = minetest.get_meta(pos):get_inventory()
      local inv = net:get_inventory()
      local stack = linv:get_stack(from_list, from_index)
      stack:set_count(count)
      me.insert_item(stack, net, inv, "ac")
      return count
    end
    return count
  end,
  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    -- This is used for removing items from "search".
    --me.log("Allow a take from "..listname, "error")
    local count = stack:get_count()
    return count
  end,
  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    return stack:get_count()
  end,
  on_metadata_inventory_put = function(pos, listname, _, stack)
    if listname == "search" or listname == "ac" then
      -- done above in allow, nothing left to do here
    end
  end,
  on_metadata_inventory_take = function(pos, listname, index, stack)
    me.log("A taking of "..stack:get_name().." from "..listname, "error")
    if listname ~= "ac" then
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()
      me.remove_item(net, inv, "ac", stack)
    end
  end,
  on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
  end,
  on_receive_fields = function(pos, _, fields, sender)
    local net,cpos = me.get_connected_network(pos)
    if net then
      if cpos then
	me.log("network and ctrl_pos","info")
      else
	me.log("network but no ctrl_pos","warning")
      end
    else
      if cpos then
	me.log("no network but ctrl_pos","warning")
      else
	me.log("no network and no ctrl_pos","info")
      end
    end
    local meta = minetest.get_meta(pos)
    local page = meta:get_int("page")
    local inv_name = meta:get_string("inv_name")
    local own_inv = meta:get_inventory()
    local ctrl_inv
    if cpos then
      ctrl_inv = net:get_inventory()
    else
      me.log("no network connected","warning")
      return
    end
    local inv
    if inv_name == "ac" then
      inv = ctrl_inv
      assert(inv,"no control inv")
    else
      inv = own_inv
      assert(inv,"no own inv")
    end
    local page_max = math.floor(inv:get_size(inv_name) / 16) + 1
    if inv_name == "none" then
      return
    end
    if fields.next then
      if page + 16 > inv:get_size(inv_name) then
	return
      end
      meta:set_int("page", page + 16)
      meta:set_string("formspec", chest_formspec(pos, page + 16, inv_name, page_max))
    elseif fields.prev then
      if page - 16 < 1 then
	return
      end
      meta:set_int("page", page - 16)
      meta:set_string("formspec", chest_formspec(pos, page - 16, inv_name, page_max))
    elseif fields.search or fields.key_enter_field == "filter" then
      own_inv:set_size("search", 0)
      if fields.filter == "" then
	meta:set_int("page", 1)
	meta:set_string("inv_name", "ac")
	meta:set_string("formspec", chest_formspec(pos, 1, "ac", page_max))
      else
	local tab = {}
	for i = 1, ctrl_inv:get_size("ac") do
	  local match = ctrl_inv:get_stack("ac", i):get_name():find(fields.filter)
	  if match then
	    tab[#tab + 1] = ctrl_inv:get_stack("ac", i)
	  end
	end
	own_inv:set_list("search", tab)
	meta:set_int("page", 1)
	meta:set_string("inv_name", "search")
	meta:set_string("formspec", chest_formspec(pos, 1, "search", page_max, fields.filter))
      end
    elseif fields.refresh then
      meta:set_string("formspec", chest_formspec(pos, 1, inv_name, page_max))
    elseif fields.clear then
      own_inv:set_size("ac", 0)
      meta:set_int("page", 1)
      meta:set_string("inv_name", "ac")
      net.pending = nil
      meta:set_string("formspec", chest_formspec(pos, 1, "ac", page_max))
    end
  end,
})
