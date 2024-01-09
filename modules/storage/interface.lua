-- interface
-- microexpansion/interface.lua

local me = microexpansion
local pipeworks_enabled = minetest.get_modpath("pipeworks") and true or false

-- Interfaces work by walking all connected blocks. We walk machines and inventories.
-- This explains which nodes are connected.
-- Missing from technic_plus, the generators, might be nice to be able
-- to feed them wood when the power is low.
-- Odd machines like the reactor or the force field aren't supported.
-- We'd have to figure out what we'd want to do with them.
local function can_connect(name)
  if me.registered_inventory[name] then
    return true
  end
  return false
end

function me.walk_connected(pos)
  local nodes = {}
  local visited = {}
  visited[pos.x] = {}
  visited[pos.x][pos.y] = {}
  visited[pos.x][pos.y][pos.z] = true
  local to_visit = {pos}
  while #to_visit > 0 do
    local pos = table.remove(to_visit)
    local adjacent = {
      {x=pos.x+1, y=pos.y,   z=pos.z},
      {x=pos.x-1, y=pos.y,   z=pos.z},
      {x=pos.x,   y=pos.y+1, z=pos.z},
      {x=pos.x,   y=pos.y-1, z=pos.z},
      {x=pos.x,   y=pos.y,   z=pos.z+1},
      {x=pos.x,   y=pos.y,   z=pos.z-1},
    }
    for _,apos in pairs(adjacent) do
      if not visited[apos.x] then
	 visited[apos.x] = {}
      end
      if not visited[apos.x][apos.y] then
	 visited[apos.x][apos.y] = {}
      end
      if visited[apos.x][apos.y][apos.z] ~= true then
	visited[apos.x][apos.y][apos.z] = true
	local napos = minetest.get_node(apos)
	local nn = napos.name
	if can_connect(nn) then
	  table.insert(nodes, {pos=apos, name=nn})
	  table.insert(to_visit, apos)
	end
      end
    end
  end

  return nodes
end

local function update(pos,_,ev)
  if ev.type == "connect" then
    -- net.update_counts()
  elseif ev.type == "disconnect" then
    --
  end
end

function me.reload_inventory(name, net, ctrl_inv, int_meta, n, pos, doinventories)
  local func = me.registered_inventory and me.registered_inventory[name]
  if func then
    func(net, ctrl_inv, int_meta, n, pos, doinventories)
  end
end

function me.chest_reload(net, ctrl_inv, int_meta, n, pos, doinventories)
  if not doinventories then return end
  local meta = minetest.get_meta(n.pos)
  local inv = meta:get_inventory()
  for i = 1, inv:get_size("main") do
    local stack = inv:get_stack("main", i)
    if not stack:is_empty() then
      net:create_loan(stack, {pos=n.pos, invname="main", slot=i, ipos=pos}, ctrl_inv, int_meta)
    end
  end
end


me.register_inventory("default:chest", me.chest_reload)

-- This never rewalks connected machines. To do that add a gui
-- rewalk and/or remove, replace.
function me.reload_interface(net, pos, doinventories)
  if not net then return end
  local ctrl_inv = net:get_inventory()
  local int_meta = minetest.get_meta(pos)
  local inv = int_meta:get_inventory()
  local inventories = minetest.deserialize(int_meta:get_string("connected"))
  -- not appropriate
  -- me.send_event(pos,"connect")
  int_meta:set_string("infotext", "chests: "..#inventories)
  if not net.counts then
    net.counts = {}
  end
  if not net.autocrafters then
    net.autocrafters = {}
  end
  if not net.autocrafters_by_pos then
    net.autocrafters_by_pos = {}
  end
  if not net.process then
    net.process = {}
  end
  for _, n in pairs(inventories) do
    local node = minetest.get_node(n.pos)
    local name = node.name
    -- me.log("INT: found a "..name, "error")
    local outputs = me.output_by_typename[me.block_to_typename_map[name]]
    if outputs then
      for _, name in pairs(outputs) do
	if not net.process[name] then
	  net.process[name] = {}
	end
	-- me.log("INT: registering "..name.." for the "..node.name, "error")
	net.process[name][n.pos] = pos
      end
    else
      me.reload_inventory(name, net, ctrl_inv, int_meta, n, pos, doinventories)
    end
  end
  -- me.send_event(pos,...
end

-- [me chest] Register node
me.register_node("interface", {
  description = "ME Interface",
  usedfor = "Interface for ME system",
  tiles = {
    "chest_top",
    "chest_top",
    "chest_side",
    "chest_side",
    "chest_side",
    "chest_side", -- TODO: Maybe customize it?
  },
  recipe = {
    { 1, {
	{"default:steel_ingot", "microexpansion:machine_casing", "default:steel_ingot" },
	{"default:steel_ingot", "microexpansion:machine_casing", "default:steel_ingot" },
	{"default:steel_ingot",        "default:chest",          "default:steel_ingot" },
      },
    }
  },
  is_ground_content = false,
  groups = { cracky = 1, me_connect = 1, tubedevice = 1, tubedevice_receiver = 1 },
  paramtype = "light",
  paramtype2 = "facedir",
  me_update = update,
  on_construct = function(pos)
    local int_meta = minetest.get_meta(pos)
    int_meta:set_string("formspec",
      "size[9,7.5]"..
      microexpansion.gui_bg ..
      microexpansion.gui_slots ..
    [[
      label[0,-0.23;ME Interface]
      list[context;import;0,0.3;9,1]
      list[context;export;0,0.3;9,1]
      list[current_player;main;0,3.5;8,1;]
      list[current_player;main;0,4.73;8,3;8]
      listring[current_name;import]
      listring[current_player;main]
      field_close_on_enter[filter;false]
    ]])
    local inv = int_meta:get_inventory()
    inv:set_size("export", 3)
    inv:set_size("import", 3)
    local inventories = me.walk_connected(pos)
    int_meta:set_string("connected", minetest.serialize(inventories))

    local net = me.get_connected_network(pos)
    if net == nil then
      int_meta:set_string("infotext", "No Network")
      return
    end
    me.reload_interface(net, pos, true)
  end,
  can_dig = function(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    return inv:is_empty("import")
  end,
  on_destruct = function(pos)
    local net = me.get_connected_network(pos)
    if net == nil then return end
    local inv = net:get_inventory()

    local int_meta = minetest.get_meta(pos)
    local inventories = minetest.deserialize(int_meta:get_string("connected"))
    int_meta:set_string("infotext", "")

    local to_remove = {}
    for _, n in pairs(inventories) do
      local pos = n.pos
      if not to_remove[pos.x] then
        to_remove[pos.x] = {}
      end
      if not to_remove[pos.x][pos.y] then
        to_remove[pos.x][pos.y] = {}
      end
      if not to_remove[pos.x][pos.y][pos.z] then
        to_remove[pos.x][pos.y][pos.z] = true
      end
    end

    net:update_counts()
    local loan_slot = me.loan.get_size(net, inv)
    local ref
    while loan_slot > 0 do
      local lstack = me.loan.get_stack(net, inv, loan_slot)
      if lstack:is_empty() then
	-- TODO: Don't think this can happen now, update_counts
        -- me.log("interface empty loan at "..loan_slot, "error")
	goto continue
        foobar()
      end
      -- me.log("interface removing loan at "..loan_slot, "error")
      ref = me.network.get_ref(lstack)
      if ref and to_remove[ref.pos.x] and to_remove[ref.pos.x][ref.pos.y] and to_remove[ref.pos.x][ref.pos.y][ref.pos.z] then
        net:remove_loan(ref.pos, inv, lstack, loan_slot, ref)
      end
      ::continue::
      loan_slot = loan_slot - 1
    end
    net:update_counts()

    -- pos is a table and does not have value semantics.
    if net.autocrafters_by_pos then
      for k, v in pairs(net.autocrafters_by_pos) do
        if k.x == pos.x and k.y == pos.y and k.z == pos.z then
          pos = k
	  break
        end
      end
      if net.autocrafters_by_pos[pos] then
        for name, apos in pairs(net.autocrafters_by_pos[pos]) do
          -- deindex these upon removal of the interface controlling them
          net.autocrafters_by_pos[pos][name] = nil
	  net.autocrafters[name][apos] = nil
        end
      end
    end
    if net.process then
      -- todo: This is a little slow, speed it up? Interface removal is infrequent.
      for _, v in pairs(net.process) do
        for k, ipos in pairs(v) do
          if ipos.x == pos.x and ipos.y == pos.y and ipos.z == pos.z then
            pos = ipos
	    break
          end
        end
      end
      for name, v in pairs(net.process) do
        for apos, ipos in pairs(v) do
          if ipos == pos then
	    me.log("INTERFACE: killing a mchine for "..name, "error")
	    net.process[name][apos] = nil
          end
        end
      end
    end
  end,
  after_destruct = function(pos)
    me.send_event(pos,"disconnect")
  end,
  allow_metadata_inventory_put = function(pos, listname, index, stack)
    return stack:get_count()
  end,
  on_metadata_inventory_put = function(pos, _, _, stack)
    local net = me.get_connected_network(pos)
    if net == nil then
      return
    end
    local ctrl_inv = net:get_inventory()
  end,
  allow_metadata_inventory_take = function(pos,_,_,stack) --args: pos, listname, index, stack, player
    local net = me.get_connected_network(pos)
    return stack:get_count()
  end,
  on_metadata_inventory_take = function(pos, _, _, stack)
    local net = me.get_connected_network(pos)
    if net == nil then
      return
    end
    local ctrl_inv = net:get_inventory()
  end,
  -- tube connection
  tube = {
    can_insert = function(pos, _, stack) --pos, node, stack, direction
      local net = me.get_connected_network(pos)
      local inv = net:get_inventory()

      local max_slots = inv:get_size("main")
      local max_items = net.capacity_cache

      local slots, items = 0, 0
      -- Get amount of items in drive
      for i = 1, max_slots do
	local mstack = inv:get_stack("main", i)
	if mstack:get_name() ~= "" then
	  slots = slots + 1
	  local num = mstack:get_count()
	  if num == 0 then num = 1 end
	  items = items + num
	end
      end
      items = items + stack:get_count()
      return max_items > items
    end,
    insert_object = function(pos, _, stack)
      local net = me.get_connected_network(pos)
      local leftovers = stack
      if net then
        local inv = net:get_inventory()
        leftovers = me.insert_item(stack, net, inv, "main")
        net:set_storage_space(true)
      end
      return leftovers
    end,
    connect_sides = {left=1, right=1, front=1, back=1, top=1, bottom=1},
  },
  after_place_node = pipeworks_enabled and pipeworks.after_place,
  after_dig_node = pipeworks_enabled and pipeworks.after_dig,
})
