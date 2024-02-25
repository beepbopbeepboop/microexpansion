local me = microexpansion
local access_level = microexpansion.constants.security.access_levels

--technic = rawget(_G, "technic") or {}

--local S = technic.getter

local S = function(t)
  return t
end

local function get_metadata(toolstack)
  local m = minetest.deserialize(toolstack:get_metadata())
  if not m then m = {} end
  -- They can use it for just a little bit, then, they will have to charge it.
  if not m.charge then m.charge = 3000 end
  if not m.page then m.page = 1 end
  if not m.query then m.query = "" end
  if not m.crafts then m.crafts = "false" end
  if not m.desc then m.desc = "false" end
  if not m.inv_name then m.inv_name = "main" end
  return m
end

local function chest_formspec(s, pos, start_id, listname)
  local list
  local page_number = ""
  local buttons = ""
  local net,cpos = me.get_connected_network(pos)

  -- luajit seems to need this to ensure "clear" works, weird, why?
  local dummy = s.query
  if net then
    local inv = net:get_inventory()
    if listname and (inv:get_size(listname) > 0 or net:get_item_capacity() > 0) then
      local ctrlinvname = net:get_inventory_name()
      if listname == "main" then
	list = "list[detached:"..ctrlinvname..";"
	  .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      else
	list = "list[current_player;" .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      end
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
	list[current_player;recipe;0.22,5.22;3,3;]
	list[current_player;output;4,6.22;1,1;]
      ]]
      list = list .. [[
	listring[current_player;main]
	listring[detached:]]..ctrlinvname..[[;main]
	listring[current_player;main]
	listring[current_player;recipe]
	listring[current_player;main]
	listring[current_player;output]
	listring[current_player;main]
	listring[current_player;me_search]
      ]]
      buttons = [[
	button[3.56,4.35;0.9,0.9;tochest;To Drive]
	tooltip[tochest;Move everything from your inventory to the ME network.]
	checkbox[4.46,4.35;desc;desc;]]..s.desc..[[]
	tooltip[desc;Search the descriptions]
	button[5.4,4.35;0.8,0.9;prev;<]
	button[7.25,4.35;0.8,0.9;next;>]
	tooltip[prev;Previous]
	tooltip[next;Next]
	field[0.29,4.6;2.2,1;filter;;]]..s.query..[[]
	button[2.1,4.5;0.8,0.5;search;?]
	button[2.75,4.5;0.8,0.5;clear;X]
	tooltip[search;Search]
	tooltip[clear;Reset]
	field[6,5.42;2,1;autocraft;;1]
	tooltip[autocraft;Number of items to Craft]
	checkbox[6,6.45;crafts;crafts;]]..s.crafts..[[]
	tooltip[crafts;Show only craftable items]
      ]]
    else
      list = "label[3,2;" .. minetest.colorize("red", "No connected storage!") .. "]"
    end
  else
    list = "label[3,2;" .. minetest.colorize("red", "No connected network!") .. "]"
  end
  if s.page_max then
    page_number = "label[6.15,4.5;" .. math.floor((start_id / 32)) + 1 ..
      "/" .. s.page_max .."]"
  end

  return [[
    size[9,12.5]
  ]]..
    microexpansion.gui_bg ..
    microexpansion.gui_slots ..
    list ..
  [[
    label[0,-0.23;ME Remote Crafting Terminal]
    label[5,-0.23;Charge level: ]]..s.charge..[[]
    field_close_on_enter[filter;false]
    field_close_on_enter[autocraft;false]
  ]]..
    page_number ..
    buttons
end

minetest.register_tool("microexpansion:remote", {
  description = S("Microexpansion Remote"),
  inventory_image = "technic_prospector.png",
  wear_represents = "technic_RE_charge",
  on_refill = technic and technic.refill_RE_charge,
  on_use = function(toolstack, user, pointed_thing)
    if not user or not user:is_player() or user.is_fake_player then return end
    local toolmeta = get_metadata(toolstack)
    if pointed_thing.type == "node" then
      local pos = pointed_thing.under
      pos.z = pos.z - 1
      local net,cpos = me.get_connected_network(pos)
      if net then
	if net:get_access_level(user) < access_level.interact then
	  return 0
	end
      elseif minetest.is_protected(pos, user) then
	minetest.record_protection_violation(pos, user)
	return 0
      end
      if net then
        if not net:powered(user:get_player_name()) then return end
	minetest.chat_send_player(user:get_player_name(), "Connected to ME network, right-click to use.")
	toolmeta.terminal = pos
	local pinv = user:get_inventory()
	pinv:set_size("recipe", 3*3)
	pinv:set_size("output", 1)
	toolstack:set_metadata(minetest.serialize(toolmeta))
	user:set_wielded_item(toolstack)
      else
	minetest.chat_send_player(user:get_player_name(), "Left-click on ME block to connect to ME network.")
	return
      end
    end
  end,
  on_secondary_use = function(toolstack, user, pointed_thing)
    if not user or not user:is_player() or user.is_fake_player then return end
    local toolmeta = get_metadata(toolstack)
    local pos = toolmeta.terminal
    local playername = user:get_player_name()
    if not pos then
      minetest.chat_send_player(playername, "Left-click on ME block to connect to ME network.")
      return
    end
    local net,cpos = me.get_connected_network(pos)

    local charge_to_take = 100
    if net then
      -- 150 to 1187 eu per operation, rich people pay for distance.
      local distance = vector.distance(net.controller_pos, user:get_pos())
      charge_to_take = math.pow(math.log(distance),2) * 10 + 125
    end

    if toolmeta.charge < charge_to_take then
      minetest.chat_send_player(playername, "No power left, recharge in technic battery.")
      return
    end

    if technic and not technic.creative_mode then
      toolmeta.charge = toolmeta.charge - charge_to_take
      toolstack:set_metadata(minetest.serialize(toolmeta))
      technic.set_RE_wear(toolstack, toolmeta.charge, technic.power_tools[toolstack:get_name()])
    end

    if net and not net:powered(playername) then return end

    local page = toolmeta.page
    local inv_name = toolmeta.inv_name
    local query = toolmeta.query
    local crafts = toolmeta.crafts

    local inv
    local own_inv = user:get_inventory()
    local ctrl_inv
    if net then
      ctrl_inv = net:get_inventory()
    end
    if inv_name == "main" then
      inv = ctrl_inv
    else
      inv = own_inv
    end
    if net then
      user:get_meta():set_string("controller_pos", minetest.pos_to_string(net.controller_pos))
      toolmeta.page_max = math.floor(inv:get_size(inv_name) / 32) + 1
      toolstack:set_metadata(minetest.serialize(toolmeta))
    end

    minetest.show_formspec(playername, "microexpansion:remote_control",
      chest_formspec(toolmeta, pos, page, inv_name))

    return toolstack
  end,
})

minetest.register_on_player_receive_fields(function(user, formname, fields)
  if formname ~= "microexpansion:remote_control" then return false end
  if not user or not user:is_player() or user.is_fake_player then return end
  local toolstack = user:get_wielded_item()
  if toolstack:get_name() ~= "microexpansion:remote" then return true end

  local toolmeta = get_metadata(toolstack)

  local pos = toolmeta.terminal
  local net
  if pos then
    net = me.get_connected_network(pos)
  end

  local page_max
  local inv
  local own_inv = user:get_inventory()
  local ctrl_inv
  if net then
    ctrl_inv = net:get_inventory()
  end
  local inv_name = toolmeta.inv_name
  if inv_name == "main" then
    inv = ctrl_inv
  else
    inv = own_inv
  end

  local page = toolmeta.page
  local did_update = false
  local update_search = false
  local to_clear = false
  local do_autocraft = false
  for field, value in pairs(fields) do
    --me.log("REMOTE: form "..field.." value "..value, "error")
    if field == "next" then
      if page + 32 <= inv:get_size(inv_name) then
        page = page + 32
        toolmeta.page = page
	did_update = true
      end
    elseif field == "prev" then
      if page - 32 >= 1 then
        page = page - 32
        toolmeta.page = page
	did_update = true
      end
    elseif field == "crafts" then
      toolmeta.crafts = value
      page = 1
      toolmeta.page = page
      update_search = true
    elseif (field == "key_enter_field" and value == "filter")
           or field == "filter" or field == "search" then
      if field == "filter" then
        toolmeta.query = value
      end
      if (field == "key_enter_field" and value == "filter") or field == "search" then
        page = 1
        toolmeta.page = page
        update_search = true
      end
    elseif field == "clear" then
      to_clear = true
    elseif field == "tochest" then
    elseif field == "desc" then
      toolmeta.desc = value
      page = 1
      toolmeta.page = page
      update_search = true
    elseif field == "autocraft" then
      if tonumber(value) ~= nil then
        toolmeta.autocraft = value
      end
    elseif field == "key_enter_field" and value == "autocraft" then
      local count = tonumber(toolmeta.autocraft)
      if not own_inv:get_stack("output", 1):is_empty() and count < math.pow(2,16) then
        do_autocraft = true
      end
    end
  end

  if to_clear then
    own_inv:set_size("me_search", 0)
    own_inv:set_size("me_crafts", 0)
    page = 1
    toolmeta.page = page
    toolmeta.inv_name = "main"
    toolmeta.query = ""
    toolstack:get_meta():set_string("query", "")
    toolmeta.crafts = "false"
    toolmeta.page_max = math.floor(ctrl_inv:get_size(inv_name) / 32) + 1
    update_search = true
    did_update = true
  end

  if do_autocraft then
    local count = tonumber(toolmeta.autocraft)
    me.autocraft(me.autocrafterCache, pos, net, own_inv, ctrl_inv, count)
  end

  if update_search then
    if toolmeta.crafts == "true" then
      inv_name = "me_crafts"
      local tab = {}
      if net then
	if not net.process then
	  net:reload_network()
	end
	for name,hash in pairs(net.autocrafters) do
	  tab[#tab + 1] = ItemStack(name)
	end
	tab[#tab + 1] = ItemStack("")
	for name,hash in pairs(net.process) do
	  tab[#tab + 1] = ItemStack(name)
	end
      end
      own_inv:set_size(inv_name, #tab)
      own_inv:set_list(inv_name, tab)
      toolmeta.inv_name = inv_name
      page_max = math.floor(own_inv:get_size(inv_name) / 32) + 1
      toolmeta.page_max = page_max
      did_update = true
    else
      inv_name = "main"
      if toolmeta.query == "" then
	own_inv:set_size("me_crafts", 0)
	toolmeta.inv_name = inv_name
	page_max = math.floor(ctrl_inv:get_size(inv_name) / 32) + 1
	toolmeta.page_max = page_max
	did_update = true
      end
    end
    if toolmeta.query ~= "" then
      inv = own_inv
      if inv_name == "main" then
	inv = ctrl_inv
      end
      local tab = {}
      for i = 1, inv:get_size(inv_name) do
	local match = inv:get_stack(inv_name, i):get_name():find(toolmeta.query)
	if toolmeta.desc == "true" then
	  match = match or inv:get_stack(inv_name, i):get_description():find(toolmeta.query)
	  match = match or inv:get_stack(inv_name, i):get_short_description():find(toolmeta.query)
	end
	if match then
	  tab[#tab + 1] = inv:get_stack(inv_name, i)
	end
      end
      inv_name = "me_search"
      own_inv:set_size(inv_name, #tab)
      own_inv:set_list(inv_name, tab)
      toolmeta.inv_name = inv_name
      page_max = math.floor(own_inv:get_size(inv_name) / 32) + 1
      toolmeta.page_max = page_max
      did_update = true
    end
  end

  if did_update then
    minetest.show_formspec(user:get_player_name(), "microexpansion:remote_control",
      chest_formspec(toolmeta, pos, page, inv_name))
  end
  toolstack:set_metadata(minetest.serialize(toolmeta))
  user:set_wielded_item(toolstack)
  return true
end)

minetest.register_craft({
  output = "microexpansion:remote",
  recipe = {
    {"basic_materials:brass_ingot", "", "pipeworks:teleport_tube_1"},
    {"", (technic and "technic:control_logic_unit") or "", "basic_materials:brass_ingot"},
    {"", "", ""},
  }
})

minetest.register_allow_player_inventory_action(
  function(player, action, linv, info)
    -- linv:get_list(info.from_list)[info.from_index]
    local from_list = info.from_list
    local to_list = info.to_list
    if action == "move" then
      if (to_list == "recipe" or to_list == "main") and from_list == "me_search" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local net = me.get_network(cpos)
	local inv = net:get_inventory()
	local stack = linv:get_stack(from_list, info.from_index)
	local count = math.min(info.count, stack:get_stack_max())
	stack:set_count(count)
	return me.remove_item(net, inv, "main", stack):get_count()
      end
      if to_list == "output" then
	--local stack = linv:get_list(info.from_list)[info.from_index]
	local stack = linv:get_stack(from_list, info.from_index)
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local net = me.get_network(cpos)
	return net:on_output_change(cpos, linv, stack)
      end
      if from_list == "me_crafts" or from_list == "me_search" then
	return 0
      end
      if from_list == "output" then
	-- an output with no recipe is a virtual item and can't be taken,
	-- but if there is a recipe, then it can be taken.
	local was_empty = true
	for i = 1, 9 do
	  was_empty = was_empty and linv:get_stack("recipe", i):is_empty()
	end
        if was_empty then return 0 end
      end
      if to_list == "me_search" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local net = me.get_network(cpos)
	local inv = net:get_inventory()
	--local stack = linv:get_stack(from_list, info.from_index)
	local stack = linv:get_list(info.from_list)[info.from_index]
	stack:set_count(info.count)
	-- meta:set_string("infotext", "allow moving: "..stack:get_name())
	-- TODO: Check capacity? Test.
	local leftovers = me.insert_item(stack, net, inv, "main")
	return info.count - leftovers:get_count()
      end
    elseif action == "take" then
      local stack = info.stack
      local count = stack:get_count()
      local listname = info.listname
      if listname == "me_search" or listname == "recipe" then
        count = math.min(count, stack:get_stack_max())
      elseif listname == "output" then
	-- an output with no recipe is a virtual item and can't be taken,
	-- but if there is a recipe, then it can be taken.
	local was_empty = true
	for i = 1, 9 do
	  was_empty = was_empty and linv:get_stack("recipe", i):is_empty()
	end
        if was_empty then return 0 end
      end
      if listname == "me_crafts" then
        return 0
      end
      return count
    elseif action == "put" then
      local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
      local listname = info.listname
      if listname == "output" then
        local net = me.get_network(cpos)
	net:on_output_change(cpos, linv, info.stack)
      elseif listname == "me_search" or listname == "me_crafts" then
        local net = me.get_network(cpos)
        local inv = net:get_inventory()
        -- TODO: Check full inv, should be fixed now, confirm.
        local leftovers = me.insert_item(stack, net, inv, "main")
        return stack:get_count() - leftovers:get_count()
      end
    end
    if info.stack then
      return info.stack:get_count()
    end
    return info.count
  end)

minetest.register_on_player_inventory_action(
  function(player, action, linv, info)
    -- linv:get_list(info.from_list)[info.from_index]
    local from_list = info.from_list
    local to_list = info.to_list
    if action == "move" then
      if from_list == "output" then
	local num_left = linv:get_stack("output", 1):get_count()
	-- We only need to consume the recipe if there are no more items
	if num_left > 0 then return end
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local net = me.get_network(cpos)
	local inv = net:get_inventory()
	net:take_output(cpos, linv, inv)
      end
      if to_list == "recipe" or from_list == "recipe" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local net = me.get_network(cpos)
	me.after_recipe_change(cpos, linv)
      end
    elseif action == "take" then
      local stack = info.stack
      local count = stack:get_count()
      local listname = info.listname
      if listname == "output" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	local num_left = linv:get_stack("output", 1):get_count()
	-- We only need to consume the recipe if there are no more items
	if num_left > 0 then return end
	local net = me.get_network(cpos)
	local inv = net:get_inventory()
	net:take_output(cpos, linv, inv)
      elseif listname == "recipe" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	me.after_recipe_change(cpos, linv)
      elseif listname == "me_crafts" or listname == "me_search" then
      end
    elseif action == "put" then
      local listname = info.listname
      if listname == "recipe" then
        local cpos = minetest.string_to_pos(player:get_meta():get_string("controller_pos"))
	me.after_recipe_change(cpos, linv)
      end
    end
  end)

if technic then
  technic.register_power_tool("microexpansion:remote", 450000)
end
