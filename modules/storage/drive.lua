-- microexpansion/machines.lua

local me = microexpansion
local access_level = microexpansion.constants.security.access_levels

local netdrives

-- load drives
local function load_drives()
  local f = io.open(me.worldpath.."/microexpansion_drives", "r")
  if f then
    netdrives = minetest.deserialize(f:read("*all")) or {}
    f:close()
    --[[
    if type(res) == "table" then
      for _,d in pairs(res) do
       table.insert(netdrives,d)
      end
    end
    ]]
  else
    netdrives = {}
  end
end

-- load now
load_drives()

-- save drives
local function save_drives()
  local f = io.open(me.worldpath.."/microexpansion_drives", "w")
  f:write(minetest.serialize(netdrives))
  f:close()
end

-- save on server shutdown
minetest.register_on_shutdown(save_drives)

local function get_drive_controller(pos)
  for i,d in pairs(netdrives) do
    if d.dpos then
      if vector.equals(pos, d.dpos) then
	return d,i
      end
    end
  end
  return --false,#netdrives+1
end

local function set_drive_controller(dpos,setd,cpos,i)
  if i then
    local dt = netdrives[i]
    if dt then
      if setd then
	dt.dpos = dpos
      end
      if cpos ~= nil then
	dt.cpos = cpos
      end
    else
      netdrives[i] = {dpos = dpos, cpos = cpos}
    end
  else
    local dt = get_drive_controller(dpos)
    if dt then
      if setd then
	dt.dpos = dpos
      end
      if cpos ~= nil then
	dt.cpos = cpos
      end
    else
      table.insert(netdrives,{dpos = dpos, cpos = cpos})
    end
  end
end

local function write_to_cell(cell, items, item_count)
  local size = microexpansion.get_cell_size(cell:get_name())
  local item_meta = cell:get_meta()
  --print(dump2(items,"cell_items"))
  item_meta:set_string("items", minetest.serialize(items))
  local base_desc = minetest.registered_craftitems[cell:get_name()].microexpansion.base_desc
  -- Calculate Percentage
  local percent = math.floor(item_count / size * 100)
  -- Update description
  item_meta:set_string("description", base_desc.."\n"..
  minetest.colorize("grey", tostring(item_count).."/"..tostring(size).." Items ("..tostring(percent).."%)"))
  return cell
end

local function write_drive_cells(pos, net)
  local meta = minetest.get_meta(pos)
  local own_inv = meta:get_inventory()
  if net == nil then
    return false
  end
  local ctrl_inv = net:get_inventory()
  local cells = {}
  for i = 1, own_inv:get_size("main") do
    local cell = own_inv:get_stack("main", i)
    local name = cell:get_name()
    if name ~= "" then
      cells[i] = cell
    end
  end
  local cell_idx = next(cells)
  if cell_idx == nil then
    return
  end
  local size = microexpansion.get_cell_size(cells[cell_idx]:get_name())
  local items_in_cell_count = 0
  local cell_items = {}

  net:update_counts()
  if not net.counts then
    net.counts = {}
  end
  for i = 1, ctrl_inv:get_size("main") do
    local stack = ctrl_inv:get_stack("main", i)
    local item_string = stack:to_string()
    if item_string ~= "" then
      item_string = item_string:split(" ")
      lbias = (net.counts and net.counts[stack:get_name()]) or 0
      local mbias = (net.bias and net.bias["main"] and net.bias["main"][stack:get_name()]) or 0
      if mbias > lbias and lbias > 0 then
        mbias = mbias - lbias
	lbias = 0
	net.bias["main"][stack:get_name()] = mbias
	net.counts[stack:get_name()] = nil
      elseif lbias > mbias and mbias > 0 then
        lbias = lbias - mbias
	mbias = 0
	net.counts[stack:get_name()] = lbias
	net.bias["main"][stack:get_name()] = nil
      elseif mbias == lbias and mbias > 0 then
	net.bias["main"][stack:get_name()] = nil
	net.counts[stack:get_name()] = nil
      end
      local item_count = stack:get_count() + mbias
      -- TODO: on_loan includes the >32k bias in it, so, therefore the
      -- stack:get_count() + mbias should have it in it.
      local on_loan = net.counts[stack:get_name()] or 0
      item_count = item_count - on_loan
      if item_count < 0 then
        me.log("LOAN: drive "..item_count.." "..stack:get_name().." "..on_loan.." on loan", "error")
	-- TODO: we need to update the count faster and we need to update counts from actual inventories
        -- and not allow taking unless there is an actual item there, mostly done now
	-- TODO: In theory this should be impossible now, but we have
        -- bugs with cell removal and insert, see wow
        me.log("wow, free items "..stack:get_name().." during drive write, "..tostring(-item_count).." extra, with a loan of "..on_loan, "error")
	item_count = 0
	if mbias > 0 then
	  net.bias["main"][stack:get_name()] = nil
	end
      end
      if item_count > 1 and item_string[2] ~= tostring(item_count) then
	me.log("stack count differs from second field of the item string","warning")
      end
      while item_count ~= 0 and cell_idx ~= nil do
	--print(("stack to store: %q"):format(table.concat(item_string," ")))

	-- TODO: This should fail if we write 64k items onto a 64k
        -- drive (or larger). Fix by writting the number first, that's
        -- the bias and then the name.  This requires that no node in
        -- the storage system starts with a number.  Then in read,
        -- support that.

	if size < items_in_cell_count + item_count then
	  local space = size - items_in_cell_count
	  item_string[2] = tostring(space)
	  table.insert(cell_items,table.concat(item_string," "))
	  items_in_cell_count = items_in_cell_count + space

	  own_inv:set_stack("main", cell_idx, write_to_cell(cells[cell_idx],cell_items,items_in_cell_count))
	  cell_idx = next(cells, cell_idx)
	  if cell_idx == nil then
	    --there may be other drives within the network
	    me.log("too many items to store in drive","info")
	    break
	  end
	  size = microexpansion.get_cell_size(cells[cell_idx]:get_name())
	  items_in_cell_count = 0
	  cell_items = {}
	  item_count = item_count - space
	else
	  items_in_cell_count = items_in_cell_count + item_count
	  item_string[2] = tostring(item_count)
	  table.insert(cell_items,table.concat(item_string," "))
	  item_count = 0
	end
      end
    end
    if cell_idx == nil then
      break
    end
  end
  while cell_idx ~= nil do
    own_inv:set_stack("main", cell_idx, write_to_cell(cells[cell_idx],cell_items,items_in_cell_count))
    items_in_cell_count = 0
    cell_items = {}
    cell_idx = next(cells, cell_idx)
  end

  return true
end

local function take_all(pos,net)
  -- me.log("take_all", "error")
  local meta = minetest.get_meta(pos)
  local own_inv = meta:get_inventory()
  local ctrl_inv = net:get_inventory()
  local items = {}
  for i = 1, own_inv:get_size("main") do
    local stack = own_inv:get_stack("main", i)
    local name = stack:get_name()
    if name ~= "" then
      local its = minetest.deserialize(stack:get_meta():get_string("items"))
      for _,s in pairs(its) do
	table.insert(items,s)
      end
    end
  end
  for _,ostack in pairs(items) do
    --this returns 99 (max count) even if it removes more
    --ctrl_inv:remove_item("main", ostack)
    local postack = ItemStack(ostack)
    -- me.log("drive take_all remove_item "..minetest.serialize(ostack), "error")
    me.log("DRIVE: take_all remove_item "..tostring(postack:get_count()).." "..postack:get_name(), "error")
    me.remove_item(net, ctrl_inv, "main", postack)
  end

  net:update()
  me.send_event(pos, "items")
end

local function add_all(pos,net)
  -- me.log("add_all", "error")
  local meta = minetest.get_meta(pos)
  local own_inv = meta:get_inventory()
  local ctrl_inv = net:get_inventory()
  local items = {}
  for i = 1, own_inv:get_size("main") do
    local stack = own_inv:get_stack("main", i)
    local name = stack:get_name()
    if name ~= "" then
      local its = minetest.deserialize(stack:get_meta():get_string("items"))
      if its then
	for _,s in pairs(its) do
	  table.insert(items,s)
	end
      end
    end
  end
  for _,ostack in pairs(items) do
    me.insert_item(ostack, net, ctrl_inv, "main")
  end

  net:update()
  me.send_event(pos, "items", {net = net})
end

function me.disconnect_drive(pos,ncpos)
  me.log("disconnecting drive at "..minetest.pos_to_string(pos),"action")
  local fc,i = get_drive_controller(pos)
  if not fc.cpos then
    return
  end
  local fnet = me.get_network(fc.cpos)
  write_drive_cells(pos,fnet)
  if ncpos then
    set_drive_controller(pos,false,ncpos,i)
  else
    set_drive_controller(pos,false,false,i)
  end
  if fnet then
    take_all(pos,fnet)
  else
    me.log("drive couldn't take items from its former network","warning")
  end
end

local function update_drive(pos,_,ev)
  if ev.type~="connect" and ev.type~="disconnect" then
    return
  end
  local fc,i = get_drive_controller(pos)
  local cnet = ev.net or me.get_connected_network(pos)
  if cnet then
    if not fc then
      me.log("connecting drive at "..minetest.pos_to_string(pos), "action")
      set_drive_controller(pos,true,cnet.controller_pos,i)
      add_all(pos,cnet)
    elseif not fc.cpos then
      me.log("connecting drive at "..minetest.pos_to_string(pos), "action")
      set_drive_controller(pos,false,cnet.controller_pos,i)
      add_all(pos,cnet)
    elseif not vector.equals(fc.cpos,cnet.controller_pos) then
      me.log("reconnecting drive at "..minetest.pos_to_string(pos), "action")
      write_drive_cells(pos,me.get_network(fc.cpos))
      set_drive_controller(pos,false,cnet.controller_pos,i)
      add_all(pos,cnet)
      me.disconnect_drive(pos,cnet.controller_pos)
    else
      if ev.origin.name == "microexpansion:ctrl" then
	me.disconnect_drive(pos,false)
      end
    end
  elseif fc then
    if fc.cpos then
      me.disconnect_drive(pos,false)
    end
  end
end

if minetest.get_modpath("mcl_core") then
  drive_recipe = {
    { 1, {
    {"mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot"},
    {"mcl_core:iron_ingot", "microexpansion:machine_casing", "mcl_core:iron_ingot"},
    {"mcl_core:iron_ingot", "mcl_chests:chest", "mcl_core:iron_ingot"},
},
}}

else
  drive_recipe = {
    { 1, {
	{"default:steel_ingot", "default:chest",                 "default:steel_ingot" },
	{"default:steel_ingot", "microexpansion:machine_casing", "default:steel_ingot" },
	{"default:steel_ingot", "default:chest",                 "default:steel_ingot" },
      },
    }
  }
end

-- [me chest] Register node
microexpansion.register_node("drive", {
  description = "ME Drive",
  usedfor = "Stores items into ME storage cells",
  tiles = {
    "chest_top",
    "chest_top",
    "chest_side",
    "chest_side",
    "chest_side",
    "drive_full",
  },
  recipe = drive_recipe,
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update_drive,
  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("formspec",
      "size[9,9.5]"..
      microexpansion.gui_bg ..
      microexpansion.gui_slots ..
    [[
      label[0,-0.23;ME Drive]
      list[context;main;0,0.3;8,4]
      list[current_player;main;0,5.5;8,1;]
      list[current_player;main;0,6.73;8,3;8]
      listring[current_name;main]
      listring[current_player;main]
      field_close_on_enter[filter;false]
    ]])
    local inv = meta:get_inventory()
    inv:set_size("main", 10)
    me.send_event(pos, "connect")
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
    if net:get_access_level(name) < access_level.modify then
      return false
    end
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    return inv:is_empty("main")
  end,
  after_destruct = function(pos)
   me.send_event(pos, "disconnect")
  end,
  allow_metadata_inventory_put = function(pos, _, _, stack, player)
    local name = player:get_player_name()
    local network = me.get_connected_network(pos)
    if network then
      if network:get_access_level(player) < access_level.interact then
        return 0
      end
    elseif minetest.is_protected(pos, name) then
      minetest.record_protection_violation(pos, name)
      return 0
    end
    if minetest.get_item_group(stack:get_name(), "microexpansion_cell") == 0 then
      return 0
    else
      return 1
    end
  end,
  on_metadata_inventory_put = function(pos, _, _, stack)
    me.send_event(pos, "item_cap")
    local network = me.get_connected_network(pos)
    if network == nil then
      return
    end
    local ctrl_inv = network:get_inventory()
    local items = minetest.deserialize(stack:get_meta():get_string("items"))
    if items == nil then
      print("no items")
      me.send_event(pos, "items", {net=network})
      return
    end
    -- TODO: adjust for correct space
    -- network:set_storage_space(#items)
    for _,stack in pairs(items) do
      -- TODO: do not change storage space in a loop
      network:set_storage_space(true)
      me.insert_item(stack, network, ctrl_inv, "main")
    end
    network:set_storage_space(true)
    me.send_event(pos, "items", {net=network})
  end,
  allow_metadata_inventory_take = function(pos,_,_,stack, player) --args: pos, listname, index, stack, player
    local name = player:get_player_name()
    local network = me.get_connected_network(pos)
    if network then
      write_drive_cells(pos,network)
      if network:get_access_level(player) < access_level.interact then
        return 0
      end
    elseif minetest.is_protected(pos, name) then
      minetest.record_protection_violation(pos, name)
      return 0
    end
    local network = me.get_connected_network(pos)
    -- should the drives really be written every take action? (performance)
    write_drive_cells(pos,network)
    return stack:get_count()
  end,
  on_metadata_inventory_take = function(pos, _, _, stack)
    local network = me.get_connected_network(pos)
    if network == nil then
      return
    end
    me.send_event(pos, "item_cap", {net=network})
    local ctrl_inv = network:get_inventory()
    local items = minetest.deserialize(stack:get_meta():get_string("items"))
    if items == nil then
      network:update()
      return
    end
    for _,ostack in pairs(items) do
      local postack = ItemStack(ostack)
      -- me.log("drive meta_inv_take remove_item "..tostring(postack:get_count()).." "..postack:get_name(), "error")
      -- This is the main item removal on cell removal from drive
      me.remove_item(network, ctrl_inv, "main", postack)
      --this returns 99 (max count) even if it removes more
      --ctrl_inv:remove_item("main", ostack)
    end
    --print(stack:to_string())

    network:update()
    me.send_event(pos, "items", {net=network})
  end,
})

if me.uinv_category_enabled then
  unified_inventory.add_category_item("storage", "microexpansion:drive")
end
