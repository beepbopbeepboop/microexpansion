local me = microexpansion

--technic = rawget(_G, "technic") or {}

--local S = technic.getter

local S = function(t)
  return t
end

local function get_metadata(toolstack)
  local m = minetest.deserialize(toolstack:get_metadata())
  if not m then m = {} end
  if not m.charge then m.charge = 100 end
  if not m.page then m.page = 1 end
  if not m.query then m.query = "" end
  if not m.crafts then m.crafts = "false" end
  if not m.inv_name then m.inv_name = "main" end
  if not m.query then m.query = "" end
  return m
end

local function chest_formspec(s, pos, start_id, listname)
  local list
  local page_number = ""
  local buttons = ""
  local net,cpos = me.get_connected_network(pos)

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
      ]]
      buttons = [[
	button[3.56,4.35;1.8,0.9;tochest;To Drive]
	tooltip[tochest;Move everything from your inventory to the ME network.]
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
  on_refill = technic.refill_RE_charge,
  on_use = function(toolstack, user, pointed_thing)
    if not user or not user:is_player() or user.is_fake_player then return end
    local toolmeta = get_metadata(toolstack)
    if pointed_thing.type == "node" then
      local pos = pointed_thing.under
      pos.z = pos.z - 1
      local net,cpos = me.get_connected_network(pos)
      if net then
	minetest.chat_send_player(user:get_player_name(), "Connected to ME network, use left-click to use.")
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
    local net = me.get_connected_network(pos)
    -- if not net then return end

    local charge_to_take = 100

    if toolmeta.charge < charge_to_take then
      minetest.chat_send_player(user:get_player_name(), "No power left, recharge in technic battery.")
      return
    end

    if technic and not technic.creative_mode then
      toolmeta.charge = toolmeta.charge - charge_to_take
      toolstack:set_metadata(minetest.serialize(toolmeta))
      technic.set_RE_wear(toolstack, toolmeta.charge, technic.power_tools[toolstack:get_name()])
    end

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
      toolmeta.page_max = math.floor(inv:get_size(inv_name) / 32) + 1
      toolstack:set_metadata(minetest.serialize(toolmeta))
    end

    minetest.show_formspec(user:get_player_name(), "microexpansion:remote_control",
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
  for field, value in pairs(fields) do
    me.log("REMOTE: form "..field.." value "..value, "error")
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
      own_inv:set_size("me_search", 0)
      own_inv:set_size("me_crafts", 0)
      page = 1
      toolmeta.page = page
      toolmeta.inv_name = "main"
      toolmeta.query = ""
      toolmeta.crafts = "false"
      toolmeta.page_max = math.floor(inv:get_size(inv_name) / 32) + 1
      update_search = true
    elseif field == "tochest" then
    elseif field == "autocraft" then
      if tonumber(value) ~= nil then
        toolmeta.autocraft = value
      end
    elseif field == "key_enter_field" and value == "autocraft" then
      local count = tonumber(toolmeta.autocraft)
      if not own_inv:get_stack("output", 1):is_empty() and count < math.pow(2,16) then
        me.autocraft(me.autocrafterCache, pos, net, own_inv, ctrl_inv, count)
      end
    end
  end

  if update_search then
    inv_name = "main"
    if toolmeta.crafts == "true" then
      inv_name = "me_crafts"
      local tab = {}
      if net then
	if not net.process then
	  net:reload_network()
	end
	for name,pos in pairs(net.autocrafters) do
	  tab[#tab + 1] = ItemStack(name)
	end
	tab[#tab + 1] = ItemStack("")
	for name,pos in pairs(net.process) do
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

if technic then
  technic.register_power_tool("microexpansion:remote", 450000)
end
