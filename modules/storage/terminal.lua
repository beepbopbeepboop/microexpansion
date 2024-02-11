-- terminal
-- microexpansion/modules/storage/terminal.lua

local me = microexpansion
local pipeworks_enabled = minetest.get_modpath("pipeworks") and true or false
local access_level = microexpansion.constants.security.access_levels

-- [me chest] Get formspec
local function chest_formspec(pos, start_id, listname, page_max, q)
  local list
  local page_number = ""
  local buttons = ""
  local query = q or ""
  local net,cpos = me.get_connected_network(pos)

  if cpos then
    if listname and net:get_item_capacity() > 0 then
      local ctrlinvname = net:get_inventory_name()
      if listname == "main" then
	list = "list[detached:"..ctrlinvname..";"
	  .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      else
	list = "list[context;" .. listname .. ";0,0.3;8,4;" .. (start_id - 1) .. "]"
      end
      if minetest.get_modpath("i3") then
	list = list .. [[
	  list[current_player;main;0,5.5;9,4;]
	]]
      else
	list = list .. [[
	  list[current_player;main;0,5.5;8,1;]
	  list[current_player;main;0,6.73;8,3;8]
	]]
      end
      list = list .. [[
	listring[detached:]]..ctrlinvname..[[;main]
	listring[current_player;main]
      ]]
      buttons = [[
	button[3.56,4.35;1.8,0.9;tochest;To Drive]
	tooltip[tochest;Move everything from your inventory to the ME network.]
	button[5.4,4.35;0.8,0.9;prev;<]
	button[7.25,4.35;0.8,0.9;next;>]
	tooltip[prev;Previous]
	tooltip[next;Next]
	field[0.29,4.6;2.2,1;filter;;]]..query..[[]
	button[2.1,4.5;0.8,0.5;search;?]
	button[2.75,4.5;0.8,0.5;clear;X]
	tooltip[search;Search]
	tooltip[clear;Reset]
      ]]
    else
      list = "label[3,2;" .. minetest.colorize("red", "No connected drives!") .. "]"
    end
  else
    list = "label[3,2;" .. minetest.colorize("red", "No connected network!") .. "]"
  end
  if page_max then
    page_number = "label[6.15,4.5;" .. math.floor((start_id / 32)) + 1 ..
      "/" .. page_max .."]"
  end

  if net and not net:powered() then
    list = "label[3,2;" .. minetest.colorize("red", "No power!") .. "]"
    buttons = ""
    page_number = ""
  end

  return [[
    size[9,9.5]
  ]]..
    microexpansion.gui_bg ..
    microexpansion.gui_slots ..
    list ..
  [[
    label[0,-0.23;ME Terminal]
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
  local size = net:get_item_capacity()
  local page_max = me.int_to_pagenum(size) + 1

  meta:set_string("inv_name", "main")
  meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
end

local term_recipe = nil
if minetest.get_modpath("mcl_core") then
term_recipe = {
    { 1, {
	{"mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot"},
	{"mcl_core:iron_ingot", "microexpansion:machine_casing", "mcl_core:iron_ingot"},
	{"mcl_core:iron_ingot", "microexpansion:cable", "mcl_core:iron_ingot"},
      },
    }
}

else

term_recipe = {
    { 1, {
	{"default:steel_ingot",   "default:chest",               "default:steel_ingot"},
	{"default:steel_ingot", "microexpansion:machine_casing", "default:steel_ingot"},
	{"default:steel_ingot", "microexpansion:cable",          "default:steel_ingot"},
      },
    }
  }
end

-- [me terminal] Register node
me.register_node("term", {
  description = "ME Terminal",
  usedfor = "Can interact with storage cells in ME networks",
  tiles = {
    "chest_top",
    "chest_top",
    "chest_side",
    "chest_side",
    "chest_side",
    "chest_front",
  },
  recipe = term_recipe,
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1, tubedevice = 1, tubedevice_receiver = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update_chest,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("formspec", chest_formspec(pos, 1))
    meta:set_string("inv_name", "none")
    meta:set_int("page", 1)

    local own_inv = meta:get_inventory()
    own_inv:set_size("src", 1)

    local net = me.get_connected_network(pos)
    me.send_event(pos, "connect", {net=net})
    if net then
      update_chest(pos)
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
    local net,cpos = me.get_connected_network(pos)
    if not net then
      return true
    end
    return net:get_access_level(name) >= access_level.modify
  end,
  after_destruct = function(pos)
    me.send_event(pos, "disconnect")
  end,
  allow_metadata_inventory_put = function(pos, _, _, stack, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    return stack:get_count()
  end,
  on_metadata_inventory_put = function(pos, listname, _, stack)
    local net = me.get_connected_network(pos)
    local inv = net:get_inventory()
    local leftovers = me.insert_item(stack, net, inv, "main")
    if not leftovers:is_empty() then
      me.leftovers(leftovers)
    end
    net:set_storage_space(true)
  end,
  allow_metadata_inventory_take = function(pos,_,_,stack, player)
    local net = me.get_connected_network(pos)
    if net then
      if net:get_access_level(player) < access_level.interact then
	return 0
      end
    elseif minetest.is_protected(pos, player) then
      minetest.record_protection_violation(pos, player)
      return 0
    end
    return math.min(stack:get_count(),stack:get_stack_max())
  end,
  on_metadata_inventory_take = function(pos, listname, _, stack)
    local net = me.get_connected_network(pos)
    local inv = net:get_inventory()
    me.remove_item(net, inv, "main", stack)
  end,
  tube = {
    can_insert = function(pos, _, stack) --pos, node, stack, direction
      local net = me.get_connected_network(pos)
      if not net then
	return false
      end
      local inv = net:get_inventory()
      local max_slots = inv:get_size("main")
      local max_items = net.capacity_cache

      local slots, items = 0, 0
      -- Get amount of items in drive
      for i = 1, max_slots do
	local dstack = inv:get_stack("main", i)
	if dstack:get_name() ~= "" then
	  slots = slots + 1
	  local num = dstack:get_count()
	  if num == 0 then num = 1 end
	  items = items + num
	end
      end
      items = items + stack:get_count()
      return max_items > items
    end,
    insert_object = function(pos, _, stack)
      local net = me.get_connected_network(pos)
      if not net then
	return stack
      end
      local inv = net:get_inventory()
      local leftovers = me.insert_item(stack, net, inv, "main")
      net:set_storage_space(true)
      return leftovers
    end,
    connect_sides = {left=1, right=1, front=1, back=1, top=1, bottom=1},
  },
  after_place_node = pipeworks_enabled and pipeworks.after_place,
  after_dig_node = pipeworks_enabled and pipeworks.after_dig,
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
    if inv_name == "main" then
      inv = ctrl_inv
      assert(inv,"no control inv")
    else
      inv = own_inv
      assert(inv,"no own inv")
    end
    local page_max = math.floor(inv:get_size(inv_name) / 32) + 1
    if inv_name == "none" then
      return
    end
    if fields.next then
      if page + 32 > inv:get_size(inv_name) then
	return
      end
      meta:set_int("page", page + 32)
      meta:set_string("formspec", chest_formspec(pos, page + 32, inv_name, page_max))
    elseif fields.prev then
      if page - 32 < 1 then
	return
      end
      meta:set_int("page", page - 32)
      meta:set_string("formspec", chest_formspec(pos, page - 32, inv_name, page_max))
    elseif fields.search or fields.key_enter_field == "filter" then
      own_inv:set_size("search", 0)
      if fields.filter == "" then
	meta:set_int("page", 1)
	meta:set_string("inv_name", "main")
	meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
      else
	local tab = {}
	for i = 1, ctrl_inv:get_size("main") do
	  local match = ctrl_inv:get_stack("main", i):get_name():find(fields.filter)
	  if match then
	    tab[#tab + 1] = ctrl_inv:get_stack("main", i)
	  end
	end
	own_inv:set_list("search", tab)
	meta:set_int("page", 1)
	meta:set_string("inv_name", "search")
	meta:set_string("formspec", chest_formspec(pos, 1, "search", page_max, fields.filter))
      end
    elseif fields.clear then
      own_inv:set_size("search", 0)
      meta:set_int("page", 1)
      meta:set_string("inv_name", "main")
      meta:set_string("formspec", chest_formspec(pos, 1, "main", page_max))
    elseif fields.tochest then
      if net:get_access_level(sender) < access_level.interact then
	return
      end
      local pinv = minetest.get_inventory({type="player", name=sender:get_player_name()})
      net:set_storage_space(pinv:get_size("main"))
      local space = net:get_item_capacity()
      local contents = ctrl_inv:get_list("main") or {}
      for _,s in pairs(contents) do
	if not s:is_empty() then
	  space = space - s:get_count()
	end
      end
      me.move_inv(net, { inv=pinv, name="main" }, { inv=ctrl_inv, name="main", huge=true }, space)
      net:set_storage_space(true)
    end
  end,
})

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:term")
end
