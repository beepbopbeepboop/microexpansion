--- Microexpansion network
-- @type network
-- @field #table controller_pos the position of the controller
-- @field #table access a table of players and their respective access levels
-- @field #number default_access_level the access level of unlisted players
-- @field #number power_load the power currently provided to the network
-- @field #number power_storage the power that can be stored for the next tick
local network = {
  default_access_level = microexpansion.constants.security.access_levels.view,
  power_load = 0,
  power_storage = 0
}
local me = microexpansion
me.network = network

local access_level = microexpansion.constants.security.access_levels

--- construct a new network
-- @function [parent=#network] new
-- @param #table or the object to become a network or nil
-- @return #table the new network object
function network.new(o)
  return setmetatable(o or {}, {__index = network})
end

--- check if a node can be connected
-- @function [parent=#network] can_connect
-- @param #table np the position of the node to be checked
--   the node itself or the name of the node
-- @return #boolean whether this node has the group me_connect
function network.can_connect(np)
  local nn
  if type(np)=="string" then
    nn = np
  else
    if np.name then
      nn = np.name
    else
      local node = me.get_node(np)
      nn = node.name
    end
  end
  return minetest.get_item_group(nn, "me_connect") > 0
end

--- get all adjacent connected nodes
-- @function [parent=#network] adjacent_connected_nodes
-- @param #table pos the position of the base node
-- @param #boolean include_ctrl whether to check for the controller
-- @return #table all nodes that have the group me_connect
function network.adjacent_connected_nodes(pos, include_ctrl)
  local adjacent = {
    {x=pos.x+1, y=pos.y,   z=pos.z},
    {x=pos.x-1, y=pos.y,   z=pos.z},
    {x=pos.x,   y=pos.y+1, z=pos.z},
    {x=pos.x,   y=pos.y-1, z=pos.z},
    {x=pos.x,   y=pos.y,   z=pos.z+1},
    {x=pos.x,   y=pos.y,   z=pos.z-1},
  }

  local nodes = {}

  for _,apos in pairs(adjacent) do
    local napos = me.get_node(apos)
    local nn = napos.name
    if network.can_connect(nn) then
      if include_ctrl == false then
        if nn ~= "microexpansion:ctrl" then
          table.insert(nodes,{pos = apos, name = nn})
        end
      else
        table.insert(nodes,{pos = apos, name = nn})
      end
    end
  end
  -- Additionally, linked quantum link nodes are adjacent.
  if me.get_node(pos).name == "microexpansion:quantum_link" then
    local source = minetest.get_meta(pos):get_string("source")
    if source ~= "" then
      local apos = vector.from_string(source)
      local nn = me.get_node(apos).name
      table.insert(nodes,{pos = apos, name = nn})
    end
  end

  return nodes
end

function network:get_access_level(player)
  local name
  local has_bypass = minetest.check_player_privs(player, "protection_bypass")
  if not player then
    return self.default_access_level
  elseif has_bypass then
    return me.constants.security.access_levels.full
  elseif type(player) == "string" then
    name = player
  else
    name = player:get_player_name()
  end
  if not self.access and not has_bypass then
    return self.default_access_level
  end
  return self.access[name] or self.default_access_level
end

function network:set_access_level(player, level)
  local name
  if not player then
    self.default_access_level = level
  elseif type(player) == "string" then
    name = player
  else
    name = player:get_player_name()
  end
  if not self.access then
    self.access = {}
  end
  self.access[name] = level
  self:fallback_access()
  -- autosave network data
  me.autosave()
end

function network:fallback_access()
  local full_access = access_level.full
  if not self.access then
    --something must have gone badly wrong
    me.log("no network access table in fallback method","error")
    self.access = {}
  end
  for _,l in pairs(self.access) do
    if l == full_access then
      return
    end
  end
  local meta = minetest.get_meta(self.controller_pos)
  local owner = meta:get_string("owner")
  if owner == "" then
    me.log("ME Network Controller without owner at: " .. vector.to_string(self.controller_pos), "warning")
  else
    self.access[owner] = full_access
  end
end

function network:list_access()
  if not self.access then
    self.access = {}
  end
  return self.access
end

--- provide power to the network
-- @function [parent=#network] provide
-- @param #number power the amount of power provided
function network:provide(power)
  self.power_load = self.power_load + power
end

--- demand power from the network
-- @function [parent=#network] demand
-- @param #number power the amount of power demanded
-- @return #boolean whether the power was provided
function network:demand(power)
  if self.power_load - power < 0 then
    return false
  end
  self.power_load = self.power_load - power
  return true
end

--- add power capacity to the network
-- @function [parent=#network] add_power_capacity
-- @param #number power the amount of power that can be stored
function network:add_power_capacity(power)
  self.power_storage = self.power_storage + power
end

--- add power capacity to the network
-- @function [parent=#network] add_power_capacity
-- @param #number power the amount of power that can't be stored anymore
function network:remove_power_capacity(power)
  self.power_storage = self.power_storage - power
  if self.power_storage < 0 then
    me.log("power storage of network "..self.." dropped below zero","warning")
  end
end

--- remove overload
-- to be called by the controller every turn
-- @function [parent=#network] remove_overload
function network:remove_overload()
  self.power_load = math.min(self.power_load, self.power_storage)
end

--- get a drives item capacity
-- @function get_drive_capacity
-- @param #table pos the position of the drive
-- @return #number the number of items that can be stored in the drive
local function get_drive_capacity(pos)
  local cap = 0
  local meta = minetest.get_meta(pos)
  local inv = meta:get_inventory()
  for i = 1, inv:get_size("main") do
    cap = cap + me.get_cell_size(inv:get_stack("main", i):get_name())
  end
  return cap
end

--- get the item capacity of a network
-- @function [parent=#network] get_item_capacity
-- @return #number the total number of items that can be stored in the network
function network:get_item_capacity()
  local cap = 0
  for npos in me.connected_nodes(self.controller_pos) do
    if me.get_node(npos).name == "microexpansion:drive" then
      cap = cap + get_drive_capacity(npos)
    end
  end
  self.capacity_cache = cap
  return cap
end

function network:remove_slots(inv,ln,target,csize)
  for i = target, csize do
    local s = inv:get_stack(ln,i)
    if not s:is_empty() then
      inv:set_stack(ln, i, "")
      me.insert_item(s, self, inv, ln)
    end
  end
  --perhaps allow list removal
  if target < 0 then
    target = 1
  end
  inv:set_size(ln, target)
end

function network:set_storage_space(count,listname)
  local c = count or 1
  local ln = listname or "main"
  local inv = self:get_inventory()
  local csize = inv:get_size(ln)
  local space = 0
  local inside = 0
  local contents = inv:get_list(ln) or {}
  for _,s in pairs(contents) do
    if s:is_empty() then
      space = space + 1
    else
      inside = inside + s:get_count()
    end
  end
  local cap = self:get_item_capacity()
  --the capacity is allocated outside of the condition because it updates the cached capacity
  if count == true then
    if inside < cap then
      c = 1
    else
      c = 0
    end
  end
  local needed = c - space
  if needed > 0 then
    needed = needed + csize
    inv:set_size(ln, needed)
  elseif needed < 0 then
    needed = needed + csize
    self:remove_slots(inv,ln,needed,csize)
  end
  -- autosave network data
  me.autosave()
end

function network:update()
  self:set_storage_space(true)
  self:update_demand()
end

function network:get_inventory_name()
  local cp = self.controller_pos
  assert(cp, "trying to get inventory name of a network without controller")
  return "microexpansion_storage_"..cp.x.."_"..cp.y.."_"..cp.z
end

function me.leftovers(pos, leftovers)
  -- Ick, no room, just drop on the floor.
  -- todo: play sound
  minetest.add_item({x=pos.x, y=pos.y-2, z=pos.z}, leftovers)
end

function network:get_inventory_space(inv, list)
  local inv = inv or self:get_inventory()
  local listname = list or "main"
  local max_slots = inv:get_size(listname)
  local max_items = self.capacity_cache

  local slots, items = 0, 0
  -- Get amount of items in drive
  for i = 1, max_slots do
    local dstack = inv:get_stack(listname, i)
    if dstack:get_name() ~= "" then
      slots = slots + 1
      local num = dstack:get_count()
      if num == 0 then num = 1 end
      items = items + num
    end
  end
  return math.max(max_items-items,0)
end

local function create_inventory(net)
  local invname = net:get_inventory_name()
  net.inv = minetest.create_detached_inventory(invname, {
    allow_put = function(inv, listname, index, stack, player)
      if net:get_access_level(player) < access_level.interact then
        return 0
      end
      local inside_stack = inv:get_stack(listname, index)
      local stack_name = stack:get_name()
      if minetest.get_item_group(stack_name, "microexpansion_cell") > 0 and
        stack:get_meta():get_string("items") ~= "" and
        stack:get_meta():get_string("items") ~= "return {}" then
	return 0
      end
      -- improve performance by skipping unnessecary calls
      if inside_stack:get_name() ~= stack_name or inside_stack:get_count() >= inside_stack:get_stack_max() then
        if inv:get_stack(listname, index+1):get_name() ~= "" then
          return stack:get_count()
        end
      end
      local max_slots = inv:get_size(listname)
      local max_items = net.capacity_cache

      local slots, items = 0, 0
      -- Get amount of items in drive
      for i = 1, max_slots do
        local dstack = inv:get_stack(listname, i)
        if dstack:get_name() ~= "" then
          slots = slots + 1
          local num = dstack:get_count()
          if num == 0 then num = 1 end
          items = items + num
        end
      end
      return math.max(math.min(stack:get_count(),max_items-items),0)
    end,
    on_put = function(inv, listname, _, stack)
      inv:remove_item(listname, stack)
      local leftovers = me.insert_item(stack, net, inv, listname)
      if not leftovers:is_empty() then
        me.leftovers(net.controller_pos, leftovers)
      end
      net:set_storage_space(true)
    end,
    allow_take = function(_, _, _, stack, player)
      if net:get_access_level(player) < access_level.interact then
        return 0
      end
      return math.min(stack:get_count(),stack:get_stack_max())
    end,
    on_take = function()
      --update the inventory size in the next step as it is not allowed in on_take
      minetest.after(0, function() net:set_storage_space(true) end)
    end
  })
end

function network:get_inventory()
  if not self.inv then
    create_inventory(self)
    assert(self.inv,"no inventory created")
  end
  return self.inv
end

function network:load_inventory(lists)
  local inv = self:get_inventory()
  for listname,c in pairs(lists) do
    inv:set_size(listname, #c)
    for i,s in pairs(c) do
      inv:set_stack(listname,i,s)
    end
  end
end

function network:save_inventory()
  local contents = {}
  local lists = self.inv:get_lists()
  for listname,c in pairs(lists or {}) do
    local ct = {}
    contents[listname] = ct
    for i,stack in pairs(c) do
      ct[i] = stack:to_string()
    end
  end
  return contents
end

function network:load()
  if self.strinv then
    self:load_inventory(self.strinv)
  end
end

-- Helper to check to see if the controller is on and powered.
function network:powered(name)
  if not name and minetest.localplayer then
    -- this works for the client side only
    name = minetest.localplayer:get_name()
    -- todo: on the server side, how do we get the player name?
  end
  local net = self
  local meta = minetest.get_meta(net.controller_pos)
  local run = meta:get_int("enabled") == 1
  if not run then
    if name then minetest.chat_send_player(name, "Please enable by turning controller switch.") end
    return false
  end
  --me.log("NETWORK: powered power level input is "..meta:get_int("HV_EU_input").." and demand is "..meta:get_int("HV_EU_demand"), "error")
  run = not technic or (meta:get_int("HV_EU_input") >= meta:get_int("HV_EU_demand") and meta:get_int("HV_EU_input") > 0)
  if not run then
    if name then minetest.chat_send_player(name, "Please provide HV power to ME controller.") end
    return false
  end
  return true
end

function network:update_demand()
  local pos = self.controller_pos
  local meta = minetest.get_meta(pos)
  local net = self
  if meta:get_int("enabled") == 0 then
    if meta:get_int("HV_EU_demand") ~= 0 then
      meta:set_int("HV_EU_demand", 0)
      meta:set_string("infotext", "Disabled")
      me.send_event(pos, "power")
    end
    return
  end
  local demand = 120  -- controller is 120
  for ipos in me.connected_nodes(pos) do
    local name = me.get_node(ipos).name
    if name == "microexpansion:cable" then
      demand = demand + 1 -- cables are 1
    elseif name == "microexpansion:interface" then
      local meta = minetest.get_meta(ipos)
      local inventories = minetest.deserialize(meta:get_string("connected"))
      demand = demand + #inventories * 20 + 40 -- interfaces are 40 and 20 for each machine or inventory
    elseif name == "microexpansion:quantum_ring" then
      demand = demand + 50 -- quantum requires a ton of power even in standby
    elseif name == "microexpansion:quantum_link" then
      demand = demand + 100 -- quantum requires a ton of power even in standby
      local source = minetest.get_meta(pos):get_string("source")
      if source ~= "" then
	local apos = vector.from_string(source)
	-- for a pair, 25 to 1062 eu, rich people pay for distance.
	local distance = vector.distance(net.controller_pos, user:get_pos())
	local charge_to_take = math.pow(math.log(distance),2) * 10
	-- When running it take even more
        demand = demand + 500 + charge_to_take/2
      end
    else
      demand = demand + 20 -- everything else is 20
    end
  end
  if meta:get_int("HV_EU_demand") ~= demand then
    local name = meta:get_string("owner")
    meta:set_string("infotext", "Network Controller (owned by "..name..")")
    me.log("NET: demand changed to "..demand, "error")
    meta:set_int("HV_EU_demand", demand)
    me.send_event(pos, "power")
  end
end

-- We don't save this data, rather we rewalk upon first use. If 1% of
-- the people play per reboot, then this saves 99% of the work.
-- Also, we don't actually read or write any of this data normally,
-- only for active users, using 1% of the memory.
-- TODO: I think all the storage for me should be handled the same way.
-- As it is, we needlessly read and write all the networks for all the users and
-- writing isn't crash friendly, whereas rewalking is crash friendly.
-- We don't reload the loans, that is saved and restored already.
function network:reload_network()
  self.autocrafters = {}
  self.autocrafters_by_pos = {}
  self.process = {}
  for ipos in me.connected_nodes(self.controller_pos) do
    local name = me.get_node(ipos).name
    if name == "microexpansion:interface" then
      me.reload_interface(self, ipos, nil)
    end
  end
  self:update_demand()
end

function network:serialize()
  local sert = {}
  for i,v in pairs(self) do
    if i == "inv" then
      sert.strinv = self:save_inventory()
    elseif i == "strinv" then
      if not sert.strinv then
        sert[i] = v
      end
    else
      sert[i] = v
    end
  end
    return sert
end

function network:destruct()
  minetest.remove_detached_inventory(self:get_inventory_name())
  self.controller_pos = nil
  self.inv = nil
end

function network:update_counts()
end
