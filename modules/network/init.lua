local me       = microexpansion
me.networks    = {}
local networks = me.networks
local path     = me.get_module_path("network")

--deprecated: use ItemStack(x) instead
--[[
local function split_stack_values(stack)
  if type(stack) == "string" then
    local split_string = stack:split(" ")
    if (#split_string < 1) then
      return "",0,0,nil
    end
    local stack_name = split_string[1]
    if (#split_string < 2) then
      return stack_name,1,0,nil
    end
    local stack_count = tonumber(split_string[2])
    if (#split_string < 3) then
      return stack_name,stack_count,0,nil
    end
    local stack_wear = tonumber(split_string[3])
    if (#split_string < 4) then
      return stack_name,stack_count,stack_wear,nil
    end
    return stack_name,stack_count,stack_wear,true
  else
    return stack:get_name(), stack:get_count(), stack:get_wear(), stack:get_meta()
  end
end
--]]

local annotate_large_stack = function(stack, count)
  local description = minetest.registered_items[stack:get_name()]
  if description then
    -- steel is an alias and won't be found in here, skip it
    description = description.description
    --stack:set_count(1)
    --This screw up everything, autocrafting, item removal and more
    --stack:get_meta():set_string("description", description.." "..count)
    stack:get_meta():set_string("description", "")
  end
end

function me.insert_item(stack, net, inv, listname, bias)
  if stack == nil then
    foobar()
    return ItemStack(), 0
  end
  stack = type(stack) == "userdata" and stack or ItemStack(stack)
  if stack:get_name() == "" then
    -- foobar()  -- TODO: can trip, ignore for now
    return ItemStack(), 0
  end
  local slot
  assert(net, not stack:is_empty())
  local found = false
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
  local meta = stack:get_meta()
  -- slot = net.byname[listname][stack:get_name()][stack:get_wear()][meta]
  -- assert(net, minetest.serialize(meta))
  ::was_empty::
  slot = net.byname[listname][stack:get_name()][stack:get_wear()]
  -- me.log("checking "..listname.." slot "..tostring(slot).." has "..stack:get_name().." in it", "error")
  if not slot then
    local ret = inv:add_item(listname, stack) -- TODO: fix to use set_stack, careful capacity
    slot = inv:get_size(listname)
    -- me.log(listname.." slot "..tostring(slot).." should now have "..stack:get_name().." in it", "error")
    -- me.log(listname.." slot "..tostring(slot).." has "..inv:get_stack(listname, slot):get_name().." in it", "error")
    if inv:get_stack(listname, slot):get_name() ~= stack:get_name() then
      return ret, 0
      --net:sync_main(inv)
      -- TODO: infinite loop on full?
      --goto was_empty
    end
    -- net.byname[listname][stack:get_name()][stack:get_wear()][meta] = slot
    net.byname[listname][stack:get_name()][stack:get_wear()] = slot
    -- me.log("byname is "..minetest.serialize(net.byname), "error")
    if bias then
      if not net.bias then
	net.bias = {}
      end
      if not net.bias[listname] then
	net.bias[listname] = {}
      end
      if not net.bias[listname][stack:get_name()] then
	net.bias[listname][stack:get_name()] = 0
      end
      net.bias[listname][stack:get_name()] = net.bias[listname][stack:get_name()] + bias
      me.log("LARGE: init insert_item bias "..bias.." for "..stack:get_name(), "error")
      local mstack = inv:get_stack(listname, slot)
      annotate_large_stack(mstack, mstack:get_count()+net.bias[listname][stack:get_name()])
      inv:set_stack(listname, slot, mstack)
    end
    return ret, slot
  end
  local mstack = inv:get_stack(listname, slot)
  -- me.log(listname.." slot "..tostring(slot).." has "..mstack:get_name().." in it", "error")
  if mstack:is_empty() then
    -- me.log("adding items to stack in microexpansion network was going to fail, fixing", "error")
    net.byname[listname][stack:get_name()][stack:get_wear()] = nil
    goto was_empty
  end
  -- me.log("init insert_item "..stack:get_name(), "error")
  -- me.log("init insert_item "..mstack:get_name(), "error")
  if mstack:get_name() ~= stack:get_name() then
    -- me.log("adding items to stack in microexpansion network was going to fail, wrong item, fixing", "error")
    net.byname[listname][stack:get_name()][stack:get_wear()] = nil
    goto was_empty
  end
  local mbias = (net.bias and net.bias[listname] and net.bias[listname][stack:get_name()]) or 0
  local total_count = mstack:get_count() + mbias + stack:get_count() + (bias or 0)
  -- me.log("insert_item "..mstack:get_name().." "..tostring(total_count), "error")
  -- bigger item count is not possible, we only have unsigned 16 bit
  if total_count > math.pow(2,15) then
    -- We handle overflows by storing the excess stores into a bias number for the slot.
    -- This give us lua max int (2^48 or so) for the actual count.
    if not net.bias then
      net.bias = {}
    end
    if not net.bias[listname] then
      net.bias[listname] = {}
    end
    if not net.bias[listname][stack:get_name()] then
      net.bias[listname][stack:get_name()] = 0
    end
    net.bias[listname][stack:get_name()] = total_count - math.pow(2,15)
    me.log("LARGE: overflow bias "..stack:get_count().." for "..stack:get_name(), "error")
    total_count = math.pow(2,15)
  end  
  local addition_real_loaned = total_count - mstack:get_count()
  mstack:set_count(total_count)
  inv:set_stack(listname, slot, mstack)
  -- if there is one or more loans for the item, add stack:get_count()
  -- + (bias or 0) to them and update those inventories, if they have room
  local remaining = stack:get_count() + (bias or 0)
  local loan_slot = net:find_loan(inv, stack)
  if loan_slot then
    me.loan.bump_loan(net, inv, loan_slot, remaining, addition_real_loaned)
  end
  return ItemStack(), slot
end

function me.add_capacity(ipos, count)
  local int_meta = minetest.get_meta(ipos)
  local prev = int_meta:get_int("capacity") or 0
  int_meta:set_int("capacity", prev + count)
end

function me.remove_item(net, inv, listname, stack)
  if not stack then return ItemStack() end
  if stack == "" then return ItemStack() end
  if type(stack) == string then
    me.log("REMOVE: converting "..stack, "error")
    stack = ItemStack(stack)
  end
  -- stack = ItemStack(stack):set_count(stack:get_count())
  -- this can dump...
  me.log("type is "..type(stack), "error")
  -- me.log("serial is "..minetest.serialize(stack), "error")
  if stack:get_count() == 0 then return ItemStack() end
  me.log("me.remove_item "..listname, "error")
  me.log("me.remove_item "..listname.." "..stack:get_count().." "..stack:get_name(), "error")
  -- me.log("me.remove_item "..listname.." "..stack:get_wear(), "error")
  if listname ~= "main" then
    foobar()
    return inv:remove_item(listname, stack)
  end
  if not net.byname[listname] or not net.byname[listname][stack:get_name()] then
    return ItemStack()
  end
  local slot = net.byname[listname][stack:get_name()][stack:get_wear()]
  if not slot then
    me.log("wanted to remove "..stack:get_name().." from "..listname..", but didn't find anything", "error")
    return ItemStack()
  end
  local mstack = inv:get_stack(listname, slot)
  me.log("init remove item "..tostring(stack:get_count()).." "..stack:get_name(), "error")
  if stack:get_name() ~= mstack:get_name()
    or stack:get_wear() ~= mstack:get_wear()
    or not stack:get_meta():equals(mstack:get_meta()) then
    me.log("wanted to remove "..stack:get_name().." from "..listname..", but had "..mstack:get_name().." in slot "..slot, "error")
    -- foobar()
    net.byname[listname][stack:get_name()][stack:get_wear()] = nil
    return ItemStack()
  end
  local mbias = 0
  if net.bias and net.bias[listname] then
    mbias = net.bias[listname][stack:get_name()] or 0
  end
  local on_loan = net.counts[stack:get_name()]
  local remaining = mstack:get_count() + mbias - stack:get_count()
  me.log("init me.remove_item has "..(on_loan or 0).." on loan and "..remaining.." remaining", "error")
  if on_loan and remaining < on_loan then
    me.log("init me.remove_item has "..on_loan.." on loan and "..remaining.." remaining", "error")
    local loan_slot = net:find_loan(inv, stack)
    -- find_loan can update main, refetch
    mstack = inv:get_stack(listname, slot)
    if not loan_slot then
      -- someone updated the real inventories, there are no more of these
      return ItemStack()
    end
    local lstack = me.loan.get_stack(net, inv, loan_slot)
    if lstack:is_empty() then
      return ItemStack()
    end
    local ref = me.network.get_ref(lstack)
    local real_count = nil
    if ref.drawer then
      local c = drawers.drawer_get_content(ref.pos, ref.slot)
      c.count = math.max(c.count-1,0) -- Poor man's locking
      local count = math.min(stack:get_count(), c.count)
      me.log("init removing "..count.." items from drawer", "error")
      stack:set_count(count)
      local take = stack
      drawers.drawer_take_large_item(ref.pos, take)
      c.count = c.count - count
      real_count = c.count
      if real_count > math.pow(2,15) then
	real_count = math.pow(2,15)
      end
      -- me.log("CAPACITY: drawer "..-count, "error")
      -- me.add_capacity(ref.ipos, -count)
    else
      local rinv = minetest.get_meta(ref.pos):get_inventory()
      local real_stack = rinv:get_stack(ref.invname, ref.slot)
      local count = math.min(stack:get_count(), real_stack:get_count())
      me.log("init removing "..count.." items from chest", "error")
      stack:set_count(count)
      real_count = real_stack:get_count()-count
      real_stack:set_count(real_count)
      rinv:set_stack(ref.invname, ref.slot, real_stack)
      -- me.log("CAPACITY: chest "..-count, "error")
      -- me.add_capacity(ref.ipos, -count)
    end
    me.log("init now down to "..real_count.." items", "error")
    local lcount = lstack:get_count()   -- it was mc 1 excess 0 lcount 1 rc 1
    local excess = real_count - lcount  -- it was mc 1 excess -1 lcount 2 rc 1
    me.log("it was "..mstack:get_count().." "..excess.." "..lcount.." "..real_count, "error") -- fails with: 1 -1
    if real_count == 0 then
      me.log("init me.remove_item before remove_loan chest", "error")
      net:remove_loan(ref.pos, inv, lstack, loan_slot, ref)
    elseif excess ~= 0 then
      -- update loan and main with new excess
      lstack:set_count(lcount + excess)
      me.log("LOAN: me.remove_item loan to "..lstack:get_count(), "error")
      me.loan.set_stack(net, inv, loan_slot, lstack)
      mstack:set_count(mstack:get_count() + excess)
      inv:set_stack(listname, slot, mstack)
      if mstack:is_empty() then
        me.maybemove(net, inv, listname, slot, stack)
      end
      -- TODO: Think this is wrong, only adjust by excess no stack:get_count()
      --net.counts[lstack:get_name()] = net.counts[lstack:get_name()] - stack:get_count()
      --me.add_capacity(ref.ipos, -stack:get_count())
      me.log("CAPACITY: is "..excess, "error")
      net.counts[lstack:get_name()] = net.counts[lstack:get_name()] + excess
      me.add_capacity(ref.ipos, excess)
    end
    return stack
  end
  if remaining > 0 then
    if remaining > math.pow(2,15) then
      if not net.bias then
	net.bias = {}
      end
      if not net.bias[listname] then
	net.bias[listname] = {}
      end
      me.log("LARGE: total count "..remaining.." for "..stack:get_name(), "error")
      annotate_large_stack(mstack, remaining)
      net.bias[listname][stack:get_name()] = remaining - math.pow(2,15)
      remaining = math.pow(2,15)
    end
    mstack:set_count(remaining)
    inv:set_stack(listname, slot, mstack)
    return stack
  end
  if remaining < 0 then
    me.log("init wow, missing "..tostring(-remaining).." "..stack:get_name().." during removal, taking less", "error")
    -- take fewer
    stack:set_count(mstack:get_count() + mbias)
    remaining = 0
  end
  mstack:set_count(remaining)
  inv:set_stack(listname, slot, mstack)
  me.log("init me.remove_item bottom before", "error")
  me.maybemove(net, inv, listname, slot, stack)
  me.log("init me.remove_item bottom after", "error")
  return stack
end

function me.maybemove(net, inv, listname, slot, stack)
  if stack == nil then
    -- me.log("init nil stack", "error")
    return
  end
  if net == nil then
    -- me.log("init nil net", "error")
    return
  end
  if inv == nil then
    -- me.log("init nil inv", "error")
    return
  end
  -- me.log("init maybemove "..stack:get_name(), "error")
  if not net.byname or not net.byname[listname] or not net.byname[listname][stack:get_name()] then
    me.log("byname on "..listname.." is already nil", "error")
  else
    -- slot has been completely removed, deindex it
    net.byname[listname][stack:get_name()][stack:get_wear()] = nil
  end
  if net.bias and net.bias[listname] then
    net.bias[listname][stack:get_name()] = nil
  end
  -- Move the last or the second to the last if the last is empty,
  -- back to the hole left by the removed items
  local main_size = inv:get_size(listname)
  -- me.log("CALC main_size"..main_size.." slot "..slot, "error")
  if slot < main_size and main_size > 1 then
    local orig_slot = main_size
    local mstack = inv:get_stack(listname, orig_slot)
    -- me.log("CALC count "..mstack:get_count().." orig_slot-1 "..orig_slot-1, "error")
    if mstack:is_empty() and slot < orig_slot-1 and orig_slot-1 > 1 then
      orig_slot = orig_slot-1
      mstack = inv:get_stack(listname, orig_slot)
    end
    if not mstack:is_empty() then
      inv:set_stack(listname, orig_slot, ItemStack())
      inv:set_stack(listname, slot, mstack)
      -- [meta]
      -- me.log("CALC not empty, old "..stack:get_name().." new "..mstack:get_name(), "error")
      if net.byname and net.byname[listname] and net.byname[listname][stack:get_name()] then
	net.byname[listname][stack:get_name()][stack:get_wear()] = nil
      end
      net.byname[listname][mstack:get_name()][mstack:get_wear()] = slot
    else
      inv:set_stack(listname, slot, mstack)
      -- me.log("CALC empty, old "..stack:get_name(), "error")
      if net.byname and net.byname[listname] and net.byname[listname][stack:get_name()] then
	net.byname[listname][stack:get_name()][stack:get_wear()] = nil
      end
    end
  end
  inv:set_size(listname, main_size-1)
end

dofile(path.."/loan.lua") -- Loan Management
dofile(path.."/network.lua") -- Network Management
dofile(path.."/autocraft.lua") -- Autocrafting

-- generate iterator to find all connected nodes
function me.connected_nodes(start_pos,include_ctrl)
  -- nodes to be checked
  local open_list = {{pos = start_pos}}
  -- nodes that were checked
  local closed_set = {}
  -- local connected nodes function to reduce table lookups
  local adjacent_connected_nodes = me.network.adjacent_connected_nodes
  -- return the generated iterator
  return function ()
    -- start looking for next pos
    local open = false
    -- pos to be checked
    local current
    -- find next unclosed
    while not open do
      -- get unchecked pos
      current = table.remove(open_list)
      -- none are left
      if current == nil then return end
      -- assume it's open
      open = true
      -- check the closed positions
      for _,closed in pairs(closed_set) do
	-- if current is unclosed
	if vector.equals(closed,current.pos) then
	  --found one was closed
	  open = false
	end
      end
    end
    -- get all connected nodes
    local nodes = adjacent_connected_nodes(current.pos,include_ctrl)
    -- iterate through them
    for _,n in pairs(nodes) do
      -- mark position to be checked
      table.insert(open_list,n)
    end
    -- add this one to the closed set
    table.insert(closed_set,current.pos)
    -- return the one to be checked
    return current.pos,current.name
  end
end

-- get network connected to position
function me.get_connected_network(start_pos)
  for npos,nn in me.connected_nodes(start_pos,true) do
    if nn == "microexpansion:ctrl" then
      local net = me.get_network(npos)
      if net then
	return net,npos
      end
    end
  end
end

function me.update_connected_machines(start_pos,event,include_start)
  me.log("updating connected machines", "action")
  local ev = event or {type = "n/a"}
  local sn = me.get_node(start_pos)
  local sd = minetest.registered_nodes[sn.name]
  local sm = sd.machine or {}
  ev.origin = {
    pos = start_pos,
    name = sn.name,
    type = sm.type
  }
  --print(dump2(ev,"event"))
  for npos in me.connected_nodes(start_pos) do
    if include_start or not vector.equals(npos,start_pos) then
      me.update_node(npos,ev)
    end
  end
end

function me.send_event(spos,type,data)
  local d = data or {}
  local event = {
    type = type,
    net = d.net,
    payload = d.payload
  }
  me.update_connected_machines(spos,event,false)
end

function me.get_network(pos)
  for i,net in pairs(networks) do
    if net.controller_pos then
      if vector.equals(pos, net.controller_pos) then
	return net,i
      end
    end
  end
end

dofile(path.."/ctrl.lua") -- Controller/wires

-- load networks
function me.load()
  local f = io.open(me.worldpath.."/microexpansion_networks", "r")
  if f then
    local res = minetest.deserialize(f:read("*all"))
    f:close()
    if type(res) == "table" then
      for _,n in pairs(res) do
	local net = me.network.new(n)
	net:load()
	table.insert(me.networks,net)
      end
    end
  end
end

-- load now
me.load()

-- save networks
function me.save()
  local data = {}
  for _,net in pairs(me.networks) do
    -- We rebuild this data by walking as they contain non-serializable content.
    -- All other data is serialized and survives.
    net.autocrafters = nil
    net.autocrafters_by_pos = nil
    net.process = nil
    table.insert(data,net:serialize())
  end
  local f = io.open(me.worldpath.."/microexpansion_networks", "w")
  f:write(minetest.serialize(data))
  f:close()
end

-- save on server shutdown
minetest.register_on_shutdown(me.save)
