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
  local ret = setmetatable(o or {}, {__index = network})
  ret.counts = {}
  return ret
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

function network.get_ref(lstack)
  local tref = lstack:get_meta():get_string("me_store_reference")
  if tref == "" then
    -- me.log("REF: we tried, "..lstack:get_name(), "error")
    -- me.log("REF: fallback", "error")
    local location = lstack:get_location()
    if location.type == "undefined" then
      me.log("REF: we tried", "error")
    end
    local foo = minetest.get_inventory(location)
    local ref = nil
    -- TODO: Do we need this?
    return nil
  end
  local ref = minetest.deserialize(tref)
  return ref
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

local function get_interface_capacity(pos)
  local cap = 0
  local meta = minetest.get_meta(pos)
  return meta:get_int("capacity") or 0
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
    if me.get_node(npos).name == "microexpansion:interface" then
      cap = cap + get_interface_capacity(npos)
    end
  end
  self.capacity_cache = cap
  me.log("total capacity is "..cap, "error")
  return cap
end

function network:remove_slots(inv, listname, target, csize)
  -- me.log("removing slots on "..listname..", target is "..target.." and csize is "..csize, "error")
  for i = target+1, csize do
    local stack = inv:get_stack(listname, i)
    -- me.log("network remove_slot "..listname..":"..i.." "..stack:get_name(), "error")
    if not stack:is_empty() then
      -- me.log("BROKEN: after remove_slot, still "..stack:get_count().." "..stack:get_name().." left", "error")
      if true then return end
      foobar() -- This can't happen, we can only remove empty slots, and only 1 at that, at the end
      --inv:set_stack(listname, i, "")
      --me.insert_item(stack, self, inv, listname)
      me.remove_item(self, inv, listname, stack)
      if inv:get_stack("main", i):get_count() ~= 0 then
	-- me.log("BROKEN: after remove_slot, still "..inv:get_stack("main", i):get_count().." left", "error")
      end
    end
  end
  --perhaps allow list removal
  if target < 0 then
    -- TODO: audit, this sould be made impossible if it is, or removed.
    target = 1
  end
  inv:set_size(listname, target)
end

function network:set_storage_space(count, listname)
  local c = count or 1
  listname = listname or "main"
  local inv = self:get_inventory()
  local csize = inv:get_size(listname)
  local space = 0
  local inside = 0
  local contents = inv:get_list(listname) or {}
  for i,stack in pairs(contents) do
    if stack:is_empty() then
      space = space + 1
      -- me.log("STORAGE: found space at "..i.." now "..space, "error")
    else
      inside = inside + stack:get_count()
    end
  end
  local cap = self:get_item_capacity()
  --the capacity is allocated outside of the condition because it updates the cached capacity
  if count == true then
    me.log("STORAGE: current: "..inside.." capacity: "..cap, "error")
    if inside < cap then
      c = 1
    else
      c = 0
    end
  end
  local needed = c - space
  -- me.log("STORAGE: needed: "..needed, "error")
  if needed > 0 then
    needed = needed + csize
    inv:set_size(listname, needed)
  elseif needed < 0 then
    needed = needed + csize
    self:remove_slots(inv, listname, needed, csize)
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

function network:find_loan(inv, stack)
  if not self.byname["loan"] then
    self.byname["loan"] = {}
  end
  if not self.byname["loan"][stack:get_name()] then
    self.byname["loan"][stack:get_name()] = {}
  end
  local loan_slot = self.byname["loan"][stack:get_name()][stack:get_wear()]
  if loan_slot then
    -- me.log("init me.remove_item before update_loan", "error")
    self:update_loan(inv, loan_slot)
    -- me.log("init me.remove_item after update_loan", "error")
  end
  loan_slot = self.byname["loan"][stack:get_name()][stack:get_wear()]
  if loan_slot then
    local lstack = me.loan.get_stack(self, inv, loan_slot)
    if lstack:get_name() == stack:get_name() and lstack:get_wear() == stack:get_wear() then
      return loan_slot
    end
    self.byname["loan"][stack:get_name()][stack:get_wear()] = nil
  end
  -- me.log("init network find_loan searching all loans", "error")
  for loan_slot = 1, me.loan.get_size(self, inv) do
    local lstack = me.loan.get_stack(self, inv, loan_slot)
    if lstack:get_name() == stack:get_name() and lstack:get_wear() == stack:get_wear() then
      -- TODO: Same meta_data...
      self.byname["loan"][stack:get_name()][stack:get_wear()] = loan_slot
      return loan_slot
    end
  end
  return nil
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
      me.insert_item(stack, net, inv, listname)
      net:set_storage_space(true)
    end,
    allow_take = function(inv, listname, slot, stack, player)
      if net:get_access_level(player) < access_level.interact then
        return 0
      end
      -- This is not remove_item, we only remove the loan. This real
      -- item will be removed.
      me.log("REMOVE: network allow taking of "..stack:get_name().." from "..listname, "error")
      --me.log("COUNTS: allow_take "..minetest.serialize(net.counts), "error")
      --print(dump2(inv:get_list("loan")))
      -- me.log("LOANS: allow_take "..minetest.serialize(inv:get_list("loan")), "error")
      -- net:dump_loans(inv)
      local count = math.min(stack:get_count(),stack:get_stack_max())
      local orig_count = count
      if listname ~= "main" then
	return count
      end
      local on_loan = net.counts[stack:get_name()]
      local main_slot = nil
      local main_count = 0
      if on_loan then
	local found = false
	local mstack = inv:get_stack("main", slot)
	main_slot = slot
	local mbias = 0
	if net.bias and net.bias["main"] and net.bias["main"][stack:get_name()] then
	  mbias = net.bias["main"][stack:get_name()]
	end
	main_count = mstack:get_count() + mbias
	if main_count - on_loan >= 1 then
	  return math.min(mstack:get_count() + mbias - on_loan, count)
	end
	local update = false
        --me.log("COUNTS: allow_take2 "..minetest.serialize(net.counts), "error")
        --print(dump2(inv:get_list("loan")))
        -- net:dump_loans(inv)
	local loan_slot = net:find_loan(inv, stack)
	if loan_slot then
	  -- me.log("found loan", "error")
	  local lstack = me.loan.get_stack(net, inv, loan_slot)
	  local loan_count = lstack:get_count()
	  local ref = network.get_ref(lstack)
	  local rinv = minetest.get_meta(ref.pos):get_inventory()
	  local real_stack = nil
	  if ref.drawer then
	    local c = drawers.drawer_get_content(ref.pos, ref.slot)
	    real_stack = ItemStack(c.name)
	    real_stack:set_count(math.max(c.count-1,0))
	  else
	    real_stack = rinv:get_stack(ref.invname, ref.slot)
	  end
	  local same_name = real_stack:get_name() == stack:get_name()
	  local same_wear = real_stack:get_wear() == stack:get_wear()
	  -- TODO: Same meta_data...
	  if same_name and same_wear and real_stack:get_count() >= 1 then
	    found = true
	    count = math.min(real_stack:get_count(), count)
	    if real_stack:get_count() ~= loan_count then
	      update = true
	      -- The partial update won't be able to update the count of
	      -- this slot as we are taking the whole thing, updating now
	      -- before the contents are removed, so the loan remains
	      if count == main_count then
		local mstack = inv:get_stack("main", main_slot)
		-- adding 1 is enough to keep it from disappearing
		mstack:set_count(main_count + 1)
		inv:set_stack("main", main_slot, mstack)
		loan_count = loan_count + 1
		lstack:set_count(loan_count)
                me.log("LOAN: allow_take to "..lstack:get_count(), "error")
		me.loan.set_stack(net, inv, loan_slot, lstack)
	      end
	    end
	    if ref.drawer then
	      local take = real_stack
	      take:set_count(count)
	      local c = drawers.drawer_get_content(ref.pos, "")
	      drawers.drawer_take_item(ref.pos, take) -- TODO: unify with me.remove_item loan refilling code
	      local c = drawers.drawer_get_content(ref.pos, "")
	    else
	      real_stack:set_count(real_stack:get_count() - count)
	      rinv:set_stack(ref.invname, ref.slot, real_stack)
	    end
	    if loan_count - count == 0 then
	      net:maybemoveloan(inv, loan_slot)
	      -- me.log("LOAN: removed "..minetest.serialize(net.counts), "error")
	    else
	      lstack:set_count(loan_count - count)
      	      me.log("LOAN: allow_take loan to "..lstack:get_count(), "error")
	      me.loan.set_stack(net, inv, loan_slot, lstack)
	    end
	    net.counts[stack:get_name()] = net.counts[stack:get_name()] - count
	    me.add_capacity(ref.ipos, -count)
	  else
	    update = true
	  end
	  if not found then
	    update = true
	    -- me.log("Ouch, lost track, someone almost got free shit from us: "..stack:get_name().." "..tostring(count), "error")
	    count = 0
	  end
	  if update then
	    -- a little weighty, but someone touched the count and it
	    -- wasn't us, make em pay for it.
	    net:update_counts()
	  end
	end
      end
      return count
    end,
    on_take = function(inv, listname, index, stack, player)
      me.log("REMOVE: net taking of "..stack:get_count().." "..stack:get_name().." from "..listname, "error")
      local func = function()
	if inv:get_stack(listname, index):get_count() == 0 then
	  me.maybemove(net, inv, listname, index, stack)
	end
	net:set_storage_space(true) -- TODO: remove, should not be necessary anymore, maybemove should do it
      end
      --update the inventory size in the next step as it is not allowed in on_take
      minetest.after(0, func)
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
    local empties = 0
    inv:set_size(listname, #c)
    for i,stack in pairs(c) do
      stack = ItemStack(stack) -- and now we try it here
      inv:set_stack(listname, i-empties, stack)
      -- me.log("LOAD META0: "..stack:get_count().." "..stack:get_name(), "error")

      if listname == "loan" then
	-- local tref = stack:get_meta():get_string("me_store_reference")
	-- me.log("LOAD META1: tref was "..tref, "error")

	-- inv:get_stack(listname, i-empties):get_meta():set_string("me_store_reference", tref)

	-- local inv_stack = inv:get_stack(listname, i-empties)
	-- local inv_meta = inv_stack:get_meta()
	-- inv_meta:set_string("me_store_reference", tref)
	-- inv:set_stack(listname, i-empties, inv_stack)
	-- inv_stack = inv:get_stack(listname, i-empties)

	-- me.log("LOAD META1.1: tref was "..inv_meta:get_string("me_store_reference"), "error")
	-- me.log("LOAD META1.2: tref was "..inv_stack:get_meta():get_string("me_store_reference"), "error")
	-- me.log("LOAD META1.3: tref was "..inv:get_stack(listname, i-empties):get_meta():get_string("me_store_reference"), "error")
	-- inv:set_stack(listname, i-empties, ItemStack(inv_stack))
	--me.log("LOAD META1.4: tref was "..inv:get_stack(listname, i-empties):get_meta():get_string("me_store_reference"), "error")
	--me.log("LOAD META1.5: tref was "..inv_stack:get_meta():get_string("me_store_reference"), "error")

	--local meta = inv:get_stack(listname, i-empties)
	--meta = meta:get_meta():get_string("me_store_reference")
	--me.log("LOAD META2: ref was "..minetest.serialize(meta), "error")
	--stack:get_meta():set_string("me_store_reference", tref)
	--meta = inv:get_stack(listname, i-empties)
	--meta = meta:get_meta():get_string("me_store_reference")
	--me.log("LOAD META3: ref was "..minetest.serialize(meta), "error")
	--me.log("loading network1: "..minetest.serialize(stack:get_meta():get_string("me_store_reference")), "error")
	-- stack = ItemStack(stack) -- tried moving this, was here
	-- me.log("loading network2: "..minetest.serialize(stack), "error")
      end
      -- me.log("loading network: "..minetest.serialize(stack), "error")
      if stack and not stack:is_empty() then
	-- me.log("loading network "..listname.." "..stack:get_name().." slot "..i, "error")
	-- TODO: missing bias
	-- does this load loans?  Yes.
	if not self.byname then
	  self.byname = {}
	end
	if not self.byname[listname] then
	  self.byname[listname] = {}
	end
	if not self.byname[listname][stack:get_name()] then
	  self.byname[listname][stack:get_name()] = {}
	end
	self.byname[listname][stack:get_name()][stack:get_wear()] = i-empties
      else
	empties = empties + 1
      end
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
    -- me.log("LOADING: "..minetest.serialize(self.strinv), "error")
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
  me.log("NETWORK: powered power level input is "..meta:get_int("HV_EU_input").." and demand is "..meta:get_int("HV_EU_demand"), "error")
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

-- This ensure main_slot is right, and if not, update it
function network:find_main(inv, ref, stack)
  local main_slot = ref.main_slot
  local mstack = inv:get_stack("main", ref.main_slot)
  if mstack:get_name() == stack:get_name() and mstack:get_wear() == stack:get_wear() then
    return mstack
  end
  for i = 1, inv:get_size("main") do
    mstack = inv:get_stack("main", i)
    if mstack:get_name() == stack:get_name() and mstack:get_wear() == stack:get_wear() then
      ref.main_slot = i
      return mstack
    end
  end
end

-- we can't update a loan with a bias, cause we don't know the old bias for this specific loan,
-- therefore we have no clue about changes to the item count, therefore we can't update the
-- item count.
function network:update_loan(inv, loan_slot)
  me.log("LOAN: updating some 4", "error")
  local lstack = me.loan.get_stack(self, inv, loan_slot)
  local tref = lstack:get_meta():get_string("me_store_reference")
  me.log("LOAN: update_loan "..lstack:get_count().." "..lstack:get_name().." with ref "..tref, "error")
  local rinv = nil
  local real_stack = nil
  local same_name = nil
  local same_wear = nil
  local excess = nil
  if tref == nil then me.log("LOAN: bad tref in loan", "error") end
  -- if tref == nil then return end
  local ref = minetest.deserialize(tref)
  if ref == nil then me.log("LOAN: bad ref in loan", "error") end
  if ref == nil then return end
  rinv = minetest.get_meta(ref.pos):get_inventory()
  local rbias = 0
  local lbias = (self.bias and self.bias["loan"] and self.bias["loan"][loan_slot]) or 0
  if ref.drawer then
    local c = drawers.drawer_get_content(ref.pos, ref.slot)
    if c.name ~= lstack:get_name() then me.log("LOAN: bad drawer item in loan "..c.name.." "..lstack:get_name(), "error") end
    c.count = math.max(c.count-1,0) -- Poor man's locking
    real_stack = ItemStack(c.name)
    if c.count > math.pow(2,15) then
      rbias = rbias + c.count - math.pow(2,15)
      c.count = math.pow(2,15)
    end
    real_stack:set_count(c.count)
  else
    real_stack = rinv:get_stack(ref.invname, ref.slot)
    if real_stack:get_name() ~= lstack:get_name() then me.log("LOAN: bad chest item in loan "..real_stack:get_name().." "..lstack:get_name(), "error") end
  end
  -- local excess = (real_stack:get_count() + rbias) - (lstack:get_count() + lbias)
  -- TODO: This assumes meta is the same save "me_store_reference".
  same_name = real_stack:get_name() == lstack:get_name()
  same_wear = real_stack:get_wear() == lstack:get_wear()
  -- If someone updates the chest, update loan and counts
  if not same_name or not same_wear then
    me.log("inventory out of sync", "error")
    -- Not at all the same, remove the loan entirely
    if not inv:contains_item("main", lstack) then
      -- TODO: Update anything that can remove to have allow_metadata check
      -- remote inventories first so this cannot happen
      me.log("missing items on loan #1", "error")
    end
    me.remove_item(self, inv, "main", lstack) -- FIXME remove_loan or change_loan? lstack, remove tref and remove that from main.
    lstack:set_count(0)
    if not real_stack:is_empty() then
      local llstack = ItemStack(real_stack)
      llstack:get_meta():set_string("me_store_reference", tref)
      me.log("LOAN: update_loan to "..llstack:get_count()..llstack:get_name(), "error")
      me.loan.set_stack(self, inv, loan_slot, llstack) -- FIXME change loan?
      if rbias > 0 then
	if not self.bias then
	  self.bias = {}
	end
	if not self.bias["loan"] then
	  self.bias["loan"] = {}
	end
	self.bias["loan"][loan_slot] = rbias -- FIXME, lstack or llstack?  was lstack, wrong
      end
    end
    return
  end    
  excess = real_stack:get_count() - lstack:get_count()
  me.log("update_loan exess is "..excess..", lc is "..lstack:get_count()..", rc is "..real_stack:get_count(), "error")
  local prev = self.counts[lstack:get_name()] or 0
  self.counts[lstack:get_name()] = prev + excess
  me.log("COUNT: update_loan loan now to "..self.counts[lstack:get_name()].." "..lstack:get_name()..", "..excess.." more", "error")
  if not real_stack:is_empty() then
    me.log("LOAN: updating some", "error")
    real_stack:get_meta():set_string("me_store_reference", tref)
    local llstack = ItemStack(real_stack)
    me.log("LOAN: update_loan to "..llstack:get_count().." "..llstack:get_name(), "error")
    me.loan.set_stack(self, inv, loan_slot, llstack)
  else
    me.log("LOAN: updating some 2", "error")
    remove_loan(ref.pos, inv, lstack, loan_slot, ref)
  end
  if excess > 0 then
    local extra = lstack
    extra:set_count(excess)
    extra:get_meta():set_string("me_store_reference", "")
    me.log("update_loan adding "..excess.." "..lstack:get_name().." to main", "error")
    local mstack = self:find_main(inv, ref, extra)
    if mstack and not mstack:is_empty() then
      mstack:set_count(mstack:get_count()+excess)
    else
      me.log("INV: went missing, readding", "error")
      me.insert_item(extra, self, inv, "main")
    end
    inv:set_stack("main", ref.main_slot, mstack)
    me.add_capacity(ref.ipos, excess)
  elseif excess < 0 then
    local deficit = lstack
    deficit:set_count(-excess)
    me.log("update_loan removing "..-excess.." "..lstack:get_name().." from main", "error")
    -- We should fix this so that this cannot happen.  See above.
    -- For now, let's see if we can fix it up.
    if not inv:contains_item("main", deficit) then
      me.log("network no extra items to meet deficit, free items", "error")
    end
    -- TODO: This isn't a copy of the original meta, it is the original meta, and screws other loans, maybe?
    deficit:get_meta():set_string("me_store_reference", "")
    -- was: local mstack = inv:get_stack("main", ref.main_slot)
    local mstack = self:find_main(inv, ref, deficit)
    if mstack then
      mstack:set_count(mstack:get_count()+excess)
      inv:set_stack("main", ref.main_slot, mstack)
      if false and mstack:get_count() == 0 then -- should be impossible, we have an outstanding loan still?
        foobar()
      end
      me.add_capacity(ref.ipos, excess)
    end
  end
end

function network:update_loan_count(inv, loan_slot)
  me.log("COUNT: loan_slot "..loan_slot, "error")
  local lstack = me.loan.get_stack(self, inv, loan_slot)
  local lbias = (self.bias and self.bias["loan"] and self.bias["loan"][loan_slot]) or 0
  local prev = self.counts[lstack:get_name()] or 0
  self.counts[lstack:get_name()] = prev + lstack:get_count() + lbias
  me.log("COUNT: update_loan_count loan now to "..self.counts[lstack:get_name()].." "..lstack:get_name()..", "..(lstack:get_count() + lbias).." more, bias is "..lbias, "error")
end

-- Check everything on loan.  This is the cheapest possible version.
-- We don't rewalk, we don't pick up new slots that now have contents.
-- We don't even verify the type of node is the same type of node.
function network:update_counts()
  local inv = self:get_inventory()
  for loan_slot = 1, me.loan.get_size(self, inv) do
    self:update_loan(inv, loan_slot)
  end
  -- Since we are rescanning 100%, we start with no old counts and we
  -- rebuild the counts
  self.counts = {}
  -- no, update_loan_count doesn't read from the inventory, if this is done, it has to be done
  -- by a inventory reader that will re-create it.
  --if self.bias and self.bias["loan"] then
  --  self.bias["loan"] = nil
  --end
  for loan_slot = 1, me.loan.get_size(self, inv) do
    self:update_loan_count(inv, loan_slot)
  end
end

function network:sync_main(inv)
  local listname = "main"
  for i = 1, inv:get_size(listname) do
    local mstack = inv:get_stack(listname, i)
    if mstack:is_empty() and i < inv:get_size("main") then
      me.log("network sync_main, empty stack at pos "..i, "error")
      me.maybemove(self, inv, "main", i, mstack)
    else
      if not net.byname then
	net.byname = {}
      end
      if not net.byname[listname] then
	net.byname[listname] = {}
      end
      if not net.byname[listname][stack:get_name()] then
	net.byname[listname][stack:get_name()] = {}
      end
      --if not net.byname[listname][stack:get_name()][stack:get_wear()] then
      --  net.byname[listname][stack:get_name()][stack:get_wear()] = {}
      --end
      local slot = self.byname[listname][mstack:get_name()][mstack:get_wear()]
      if not slot then
	me.log("network sync_main, missing "..mstack:get_name().." at pos "..i, "error")
      	self.byname[listname][mstack:get_name()][mstack:get_wear()] = i
      elseif slot ~= i then
	me.log("network sync_main, wrong pos for "..mstack:get_name().." at pos "..i", found "..slot, "error")
	self.byname[listname][mstack:get_name()][mstack:get_wear()] = i
      end
    end
  end
end

function network:remove_real(ref, inv, stack, count)
  if ref.drawer then
    while count > math.pow(2,16)-1 do
      stack:set_count(math.pow(2,16)-1)
      drawers.drawer_take_large_item(ref.pos, stack)
      count = count - math.pow(2,16)-1
    end
    stack:set_count(count)
    drawers.drawer_take_large_item(ref.pos, stack)
  else
    local rinv = minetest.get_meta(ref.pos):get_inventory()
    stack:set_count(count)
    local rstack = rinv:get_stack(ref.invname, ref.slot)
    rstack:take_item(count)
    rinv:set_stack(ref.invname, ref.slot, rstack)
  end
end

-- Callers have to ensure net.counts exists before calling.
-- Loans with bias only work for no wear and no metadata items.  Only
-- drawers can create bias loans and they don't support wear or
-- metadata items. One should add chests first, then drawers, this will top off
-- items in the drawers. If one wants to empty the chests, do the chests after the
-- drawer.
function network:create_loan(stack, ref, inv, int_meta, bias)
  local listname = "loan"
  local on_loan = self.counts[stack:get_name()] or 0
  local lbias = bias or 0
  inv = inv or get_inventory()
  local mstack = ItemStack(stack)
  local prev = int_meta:get_int("capacity") or 0
  local count = stack:get_count() + (bias or 0)
  int_meta:set_int("capacity", prev + count)
  -- me.log("total loaned items: "..tostring(prev + count))
  self:set_storage_space(true)
  local _, main_slot = me.insert_item(mstack, self, inv, "main", bias)
  local now_on_loan = self.counts[stack:get_name()] or 0
  local items_taken = now_on_loan - on_loan
  if items_taken > 0 then
    local loan_slot = self:find_loan(inv, stack)
    self:remove_real(ref, inv, stack, items_taken)
    prev = int_meta:get_int("capacity") or 0
    int_meta:set_int("capacity", prev - items_taken)
    count = count - items_taken
    if count == 0 then
      -- no actual loan in this case.
      return
    end
    if count > math.pow(2,15) then
      bias = count - math.pow(2,15)
      lbias = bias
      count = math.pow(2,15)
    else
      bias = nil
      lbias = 0
      stack:set_count(count)
    end
  end
  if main_slot == 1 then
    me.log("LARGE: creating loan for "..mstack:get_name()..", mc "..mstack:get_count()..", lc "..stack:get_count()..", lbias "..(bias or 0), "error")
  end
  self:set_storage_space(true)
  ref.main_slot = main_slot
  stack:get_meta():set_string("me_store_reference", minetest.serialize(ref))
  local loan_slot = me.loan.get_size(self, inv)+1
  me.loan.set_size(self, inv, loan_slot)
  -- me.log("loan size is now "..me.loan.get_size(self, inv))
  me.log("LOAN: create_loan to "..stack:get_count().." "..stack:get_name(), "error")
  me.loan.set_stack(self, inv, loan_slot, stack)
  me.log("INV: slot "..loan_slot.." now has "..stack:get_count().." "..stack:get_name().." in it", "error")
  if bias then
    if not self.bias then
      self.bias = {}
    end
    if not self.bias[listname] then
      self.bias[listname] = {}
    end
    self.bias[listname][loan_slot] = bias
    me.log("LARGE: "..self.bias[listname][loan_slot].." "..stack:get_name()..", added "..bias, "error")
  end
  prev = self.counts[stack:get_name()] or 0 -- TODO: Contemplate wear and meta for counts. Add wear, meta; no limit large counts to no wear, no meta
  self.counts[stack:get_name()] = prev + count
  me.log("COUNT: create_loan loan now to "..self.counts[stack:get_name()].." "..stack:get_name()..", "..count.." more", "error")
end

-- This removes the entire loan slot, always
function network:remove_loan(pos, inv, lstack, loan_slot, ref)
  me.log("LOAN: updating some 3", "error")
  lstack:get_meta():set_string("me_store_reference", "")
  local mstack = self:find_main(inv, ref, lstack)
  local main_slot = ref.main_slot
if mstack == nil then mstack = ItemStack() end
  local omstack = ItemStack(mstack)
  me.log("network remove_loan of "..omstack:get_name()..", at "..main_slot, "error")
  local lbias = (self.bias and self.bias["loan"] and self.bias["loan"][loan_slot]) or 0
  local excess = 0
  local mbias = (self.bias and self.bias["main"] and self.bias["main"][mstack:get_name()]) or 0
  excess = (mstack:get_count() + mbias) - (lstack:get_count() + lbias)
  me.log("LOAN: remove_loan "..(mstack:get_count() + mbias).." "..mstack:get_name().." "..(lstack:get_count() + lbias).." on loan, lbias is "..lbias, "error")
  if lstack:get_name() == "default:steel_ingot" then
    me.log("LARGE: remove_loan excess "..excess.." for "..(lstack:get_name())..", mc "..mstack:get_count()..", mbias "..mbias..", lc "..lstack:get_count()..", lbias "..lbias..", slot "..loan_slot, "error")
  end
  if excess < 0 then
    me.log("network missing "..tostring(-excess).." "..lstack:get_name().." from loan, free items", "error")
    mstack:set_count(0)
    mbias = 0
    if self.bias and self.bias["main"] then
      self.bias["main"][mstack:get_name()] = nil
    end
    lbias = 0
    if self.bias and self.bias["loan"] then
      self.bias["loan"][loan_slot] = nil
    end
    excess = 0
  end
  if excess > math.pow(2,15) then
    me.log("LARGE: remove_loan remaining "..excess.." for "..lstack:get_name(), "error")
    mstack:set_count(math.pow(2,15))
    self.bias["main"][mstack:get_name()] = excess - math.pow(2,15)
    if self.bias and self.bias["loan"] then
      lbias = 0
      self.bias["loan"][loan_slot] = nil
    end
  else
    mstack:set_count(excess)
    if self.bias and self.bias["main"] then
      self.bias["main"][omstack:get_name()] = nil
    end
    if self.bias and self.bias["loan"] then
      lbias = 0
      self.bias["loan"][loan_slot] = nil
    end
  end
  inv:set_stack("main", main_slot, mstack)
  if mstack:get_count() == 0 then
    me.log("network cleaning up empty main slot now", "error")
    me.maybemove(self, inv, "main", main_slot, omstack)
    me.log("network cleaning up empty main slot now, done", "error")
  end
  -- me.loan.set_stack(self, inv, loan_slot, ItemStack())
  if self.bias and self.bias["loan"] then
    self.bias["loan"][loan_slot] = nil
  end
  local on_loan = self.counts[lstack:get_name()]
  if on_loan and on_loan >= lstack:get_count() + lbias then
    self.counts[lstack:get_name()] = on_loan - lstack:get_count() - lbias
    me.log("LOAN: remove_loan down to count "..self.counts[lstack:get_name()], "error")
  else
    me.log("wow, free items, network remove_loan fails to find previous loan counts, "..self.counts[lstack:get_name()].." "..lstack:get_name(), "error")
    self.counts[lstack:get_name()] = 0
  end

  self:maybemoveloan(inv, loan_slot)
end

-- like me.maybemove
function network:maybemoveloan(inv, loan_slot)
  local loan_size = me.loan.get_size(self, inv)
  local stack = me.loan.get_stack(self, inv, loan_size)
  if stack:is_empty() then
    me.loan.set_size(self, inv, loan_size-1)
    return self:maybemoveloan(inv, loan_slot)
  end
  local do_update = false
  if loan_size > 1 and loan_slot < loan_size then
    local stack = me.loan.get_stack(self, inv, loan_size)
    if stack:is_empty() then -- should not be necessary
      me.log("network BAD loan", "error")
      -- This trips with interface place remove on main drawers
      foobar()
    end
    local prev = me.loan.get_stack(self, inv, loan_slot)
    if prev:get_count() ~= 0 then
      -- TODO: Should not be necessary, find real problem, full remove, refile check, replace interface
      if self.byname["loan"][prev:get_name()] then
        self.byname["loan"][prev:get_name()][prev:get_wear()] = nil
      end
    else
      -- don't remove the loan before, we need the name
      foobar()
    end
    me.log("LOAN: maybemoveloan to "..stack:get_count(), "error")
    me.loan.set_stack(self, inv, loan_slot, stack)
    -- me.log("maybemoveloan "..stack:get_name(), "error")
    -- me.log("maybemoveloan "..stack:get_count(), "error")
    -- me.log("maybemoveloan "..stack:get_wear(), "error")
    -- me.log("maybemoveloan "..loan_slot, "error")
    -- me.log("maybemoveloan "..minetest.serialize(self.byname), "error")
    -- me.log("maybemoveloan "..minetest.serialize(self.byname["loan"]), "error")
    -- TODO: Should not be necessary, find real problem, full remove, refile check, replace interface
    if self.byname["loan"][stack:get_name()] then
      self.byname["loan"][stack:get_name()][stack:get_wear()] = loan_slot
    end
    do_update = true
  else
    local stack = me.loan.get_stack(self, inv, loan_size)
    if stack:get_count() ~= 0 then
      -- me.log("maybemoveloan "..stack:get_name(), "error")
      -- me.log("maybemoveloan "..stack:get_count(), "error")
      -- me.log("maybemoveloan "..stack:get_wear(), "error")
      -- me.log("maybemoveloan "..loan_slot, "error")
      -- me.log("maybemoveloan "..minetest.serialize(self.byname), "error")
      -- me.log("maybemoveloan "..minetest.serialize(self.byname["loan"]), "error")
      -- TODO: Should not be necessary, find real problem, full remove, refile check, replace interface
      if self.byname["loan"] and self.byname["loan"][stack:get_name()] then
        self.byname["loan"][stack:get_name()][stack:get_wear()] = nil
      end
    else
      -- don't remove the loan before, we need the name
      foobar()
    end
  end
  me.loan.set_size(self, inv, loan_size-1)
  -- me.log("loan size is now "..me.loan.get_size(self, inv))
  if do_update then
    -- update_loan calls us and needs this updated by the time we return
    self:update_loan(inv, loan_slot)
  end
end

function network:dump_loans(inv)
  me.log("COUNTS: dump_loans "..minetest.serialize(self.counts), "error")  
  for i, j in pairs(inv:get_list("loan") or {}) do
    print(" slot "..dump(i).." "..j:to_string().." "..j:get_meta():get_string("me_store_reference"))
  end
end
